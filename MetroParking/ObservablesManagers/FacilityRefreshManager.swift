//
//  FacilityRefreshManager.swift
//  MetroParking
//
//	Handle ALL occupancy updates (initial + ongoing)
//
//  Created by Tom Kwok on 21/6/2025.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
class FacilityRefreshManager: ObservableObject {
	static let shared = FacilityRefreshManager()

	/// Published properties for UI updates
	@Published var isRefreshing = false
	@Published var lastRefreshTime: Date?
	@Published var refreshStats = RefreshStats()
	@Published var initialLoadProgress: InitialLoadProgress = .notStarted

	/// App state
	private var currentAppState: AppState = .active
	private var refreshTimer: Timer?
	private weak var timerForCleanup: Timer?
	private var modelContext: ModelContext?

	/// Rate limiting
	private var lastAPICall: Date = .distantPast

	private var currentMinInterval: TimeInterval {
		RefreshConfiguration.globalMinInterval
	}

	private var currentMaxConcurrency: Int {
		RefreshConfiguration.globalMaxConcurrency
	}

	private init() {
		setupAppStateObservers()
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
		let timer = timerForCleanup
		timer?.invalidate()
	}
}

/// Core API
extension FacilityRefreshManager {

	func loadOccupancyForFacility(
		_ facility: ParkingFacility,
		context: String
	) async {

		await rateLimitedDelay(for: facility)

		do {
			let response = try await ParkingAPIService.shared.fetchFacility(
				id: facility.facilityId
			)

			// Update facility with API response
			await MainActor.run {
				withAnimation {
					facility.updateFromAPI(response)
				}
			}
			facility.scheduleNextRefresh(appState: currentAppState)

			// Update stats
			refreshStats.successCount += 1
			refreshStats.lastSuccessTime = Date()

			print(
				"✅ [\(context)] \(facility.name): \(facility.currentAvailableSpots)/\(facility.totalSpaces)"
			)
		} catch {
			facility.markRefreshFailed()
			refreshStats.failureCount += 1
			refreshStats.lastFailureTime = Date()

			print(
				"❌ [\(context)] Failed to load \(facility.name): \(error.localizedDescription)"
			)
		}

	}

	private func rateLimitedDelay(for facility: ParkingFacility) async {
		let settings = RefreshConfiguration.getSettings(
			for: facility.refreshTier
		)
		let interval = max(currentMinInterval, settings.baseDelay)

		let timeSinceLastCall = Date().timeIntervalSince(lastAPICall)
		let waitTime = max(0, interval - timeSinceLastCall)

		if waitTime > 0 {
			try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
		}
		lastAPICall = Date()
	}
}

/// SwiftData Queries
extension FacilityRefreshManager {

	private func getAllFacilities() -> [ParkingFacility] {
		guard let context = modelContext else { return [] }

		let descriptor = FetchDescriptor<ParkingFacility>()

		do {
			return try context.fetch(descriptor)
		} catch {
			print("❌ Failed to fetch all facilities: \(error)")
			return []
		}
	}

	private func saveContext() {
		guard let context = modelContext else { return }

		withAnimation(.bouncy) {
			do {
				try context.save()
			} catch {
				print("❌ Failed to save context: \(error)")
			}
		}
	}
}

/// App lifecycle management
extension FacilityRefreshManager {

	private func setupAppStateObservers() {
		// ?
		NotificationCenter.default.addObserver(
			forName: UIApplication.didBecomeActiveNotification,
			object: nil,
			queue: .main
		) { [weak self] _ in
			Task { @MainActor in
				print("📱 App became active")
				self?.currentAppState = .active
			}
		}

		NotificationCenter.default.addObserver(
			forName: UIApplication.didEnterBackgroundNotification,
			object: nil,
			queue: .main
		) { [weak self] _ in
			Task { @MainActor in
				print("🌙 App entered background")
				self?.currentAppState = .background
			}
		}
	}
}

/// Main flow
extension FacilityRefreshManager {

	func setModelContext(_ context: ModelContext) {
		self.modelContext = context
		print("🏭 Refresh manager connected to SwiftData")
	}

	/// When the app is opened for the first time, awaked from the background, or the user requests, run this function to load the data immediately
	func performLoad() async {
		guard !isRefreshing, modelContext != nil else { return }

		print("🚀 Starting immediate load...")
		isRefreshing = true
		initialLoadProgress = .notStarted
		var processedCount = 0

		let facilities = getAllFacilities().filter {
			$0.refreshTier != .onDemand
		}

		let favourites = facilities.filter { $0.isFavourite }
		let recents = facilities
			.filter { $0.lastVisited != nil }
			.sorted { $0.lastVisited! > $1.lastVisited! }
			.suffix(10)

		/// Create ID sets for efficient exclusion
		let favouriteIDs = Set(favourites.map(\.facilityId))
		let recentIDs = Set(recents.map(\.facilityId))

		let remaining = facilities.filter { facility in
			!favouriteIDs.contains(facility.facilityId)
				&& !recentIDs.contains(facility.facilityId)
		}

		if !favourites.isEmpty {
			for (index, favourite) in favourites.enumerated() {
				await loadOccupancyForFacility(
					favourite,
					context: "favourite"
				)

				initialLoadProgress = .loading(index + 1, facilities.count)
				processedCount += 1

				saveContext()
			}
		}
		
		if !recents.isEmpty {
			for (index, recent) in recents.enumerated() {
				await loadOccupancyForFacility(recent, context: "recents")
				
				initialLoadProgress = .loading(processedCount + index + 1, facilities.count)
				
				saveContext()
			}
		}

		for (index, facility) in remaining.enumerated() {
			await loadOccupancyForFacility(
				facility,
				context: "remaining facilities"
			)

			initialLoadProgress = .loading(
				processedCount + index + 1,
				facilities.count
			)
			processedCount += 1

			saveContext()
		}

		isRefreshing = false
		initialLoadProgress = .completed
		lastRefreshTime = Date()

		print("✅ Immediate load complete: \(facilities.count) facilities")

	}

	func startAutoRefresh() {
		guard refreshTimer == nil else {
			print("⏩ Auto-refresh already running")
			return
		}

		print("🔄 Starting auto-refresh cycle...")
		scheduleNextRefresh()
	}

	func stopAutoRefresh() {
		print("⏹️ Stopping auto-refresh cycle")
		refreshTimer?.invalidate()
		refreshTimer = nil
		timerForCleanup = nil
	}
}

/// Manually refresh one facility
extension FacilityRefreshManager {

	/// Refresh a single facility if data is stale
	func refreshFacilityIfNeeded(_ facility: ParkingFacility) async {
		let timeSinceLastRefresh = facility.timeSinceLastRefresh
		let shouldRefresh =
			timeSinceLastRefresh > 30.0 || !facility.isOccupancyCacheValid

		if shouldRefresh {
			print(
				"🔄 Refreshing \(facility.name) in detail view (age: \(Int(timeSinceLastRefresh))s)"
			)
			await refreshSingleFacility(facility)
		}
	}

	/// Force refresh a single facility (for manual refresh button)
	func refreshSingleFacility(_ facility: ParkingFacility) async {
		guard !isRefreshing else { return }

		print("🔄 Force refreshing \(facility.name)")
		isRefreshing = true

		// Reuse existing loadOccupancyForFacility function
		await loadOccupancyForFacility(facility, context: "detail-view")

		// Reuse existing saveContext function
		saveContext()

		isRefreshing = false
		lastRefreshTime = Date()
	}
}

/// Ongoing refresh cycle
extension FacilityRefreshManager {

	private func scheduleNextRefresh() {
		let interval = currentAppState.refreshInterval

		refreshTimer = Timer.scheduledTimer(
			withTimeInterval: interval,
			repeats: false
		) {
			[weak self] _ in
			Task { @MainActor in
				await self?.performRefreshCycle()
				self?.scheduleNextRefresh()
			}
		}

		timerForCleanup = refreshTimer
	}

	private func performRefreshCycle() async {
		guard !isRefreshing else {
			print("⏩ Refresh cycle skipped - already refreshing")
			return
		}

		let facilitiesToRefresh = selectFacilitiesToRefresh()

		if facilitiesToRefresh.isEmpty {
			print("✅ No facilities due for refresh")
			return
		}

		print(
			"🔄 Refresh cycle: updating \(facilitiesToRefresh.count) facilities"
		)
		isRefreshing = true

		await withTaskGroup(of: Void.self) { group in
			let semaphore = AsyncSemaphore(value: currentMaxConcurrency)

			for facility in facilitiesToRefresh {
				group.addTask {
					await semaphore.wait()
					await self.loadOccupancyForFacility(
						facility,
						context: "refresh"
					)
					await semaphore.signal()
				}
			}
		}

		saveContext()
		isRefreshing = false
		lastRefreshTime = Date()

		print("✅ Refresh cycle complete")
	}

	private func selectFacilitiesToRefresh() -> [ParkingFacility] {
		return getAllFacilities()
			.filter(\.isDueForRefresh)
			.sorted { facility1, facility2 in
				// User engagement first, then by staleness
				if facility1.isFavourite != facility2.isFavourite {
					return facility1.isFavourite
				}
				return facility1.timeSinceLastRefresh
					> facility2.timeSinceLastRefresh
			}
			.prefix(8)
			.map { $0 }
	}
}

/// Supporting types
enum AppState {
	case active
	case background

	var refreshInterval: TimeInterval {
		switch self {
		case .active: return 30.0
		case .background: return 300.0
		}
	}
}

enum InitialLoadProgress {
	typealias Current = Int
	typealias Total = Int

	case notStarted
	case completed
	case loading(Int, Int)

	var description: String {
		switch self {
		case .notStarted:
			return "Ready to load"
		case .completed:
			return "All data loaded"
		case .loading(let current, let total):
			return "Loading (\(current)/\(total))"
		}
	}

	var isLoading: Bool {
		switch self {
		case .notStarted, .completed:
			return false
		default:
			return true
		}
	}

	var progressFraction: Double {
		switch self {
		case .notStarted:
			return 0.0
		case .completed:
			return 1.0
		case .loading(let current, let total):
			return total > 0 ? Double(current) / Double(total) : 0.99
		}
	}
}

struct RefreshStats {
	var successCount: Int = 0
	var failureCount: Int = 0
	var lastSuccessTime: Date?
	var lastFailureTime: Date?

	var successRate: Double {
		let total = successCount + failureCount
		return total > 0 ? Double(successCount) / Double(total) : 0.0
	}

	var description: String {
		return "✅ \(successCount) success, ❌ \(failureCount) failed"
	}
}
