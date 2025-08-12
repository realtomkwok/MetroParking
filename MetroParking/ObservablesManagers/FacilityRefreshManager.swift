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

	/// Batch processing
	private var batchTimers: [RefreshTier: Timer] = [:]

	/// Rate limiting
	private var lastAPICall: Date = .distantPast
	private let minimumAPIInterval: TimeInterval = 0.5

	private init() {
		setupAppStateObservers()
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
		let timer = timerForCleanup
		timer?.invalidate()
	}
}

/// Main flow
extension FacilityRefreshManager {

	func setModelContext(_ context: ModelContext) {
		self.modelContext = context
		print("🏭 Refresh manager connected to SwiftData")
	}

	/// Perform initial occupancy loading with priority system
	func performInitialOccupancyLoad() async {
		guard !isRefreshing else {
			print("⏩ Initial load already in progress")
			return
		}

		guard modelContext != nil else {
			print("❌ No ModelContext available for initial load")
			return
		}

		print("🚀 Starting initial occupancy load...")
		isRefreshing = true
		initialLoadProgress = .loadingFavourites(0, 0)

		/// Priority #1: Favourites
		await loadFavourites()

		/// Priority #2: Nearest 5 facilities
		await loadNearest()

		/// Priority #3: Remaining facilities
		await loadRemaining()

		/// Complete initial load
		isRefreshing = false
		initialLoadProgress = .completed
		lastRefreshTime = Date()

		print("🎉 Initial occupancy load complete!")
		print(
			"📊 Stats: \(refreshStats.successCount) success, \(refreshStats.failureCount) failed"
		)
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

/// Call APIs and load data according to the priority
extension FacilityRefreshManager {

	private func loadFavourites() async {
		let favourites = getFavouriteFacilities()

		if favourites.isEmpty {
			print("⭐ No favourite facilities to load")
			return
		}

		print(
			"⭐ Loading occupancy for \(favourites.count) favourite facilities..."
		)
		initialLoadProgress = .loadingFavourites(0, favourites.count)

		for (index, facility) in favourites.enumerated() {
			await loadOccupancyForFacility(facility, context: "favourite")
			initialLoadProgress = .loadingFavourites(
				index + 1,
				favourites.count
			)
		}
	}

	private func loadNearest() async {
		let userLoc = LocationManager.shared.userLocation
		let userLocation = (
			latitude: userLoc.latitude, longitude: userLoc.longitude
		)
		let nearest5 = getNearestFacilities(to: userLocation, limit: 5)
			.filter { !$0.isFavourite }

		if nearest5.isEmpty {
			print("📍 No nearest facilities to load (all are favourites")
			return
		}

		print("📍 Loading occupancy for \(nearest5.count) nearest facilities...")
		initialLoadProgress = .loadingNearest(0, nearest5.count)

		for (index, facility) in nearest5.enumerated() {
			await loadOccupancyForFacility(facility, context: "nearest")
			initialLoadProgress = .loadingNearest(index + 1, nearest5.count)
		}
	}

	private func loadRemaining() async {
		let favourites = Set(getFavouriteFacilities().map { $0.facilityId })
		let userLoc = LocationManager.shared.userLocation
		let userLocation = (
			latitude: userLoc.latitude, longitude: userLoc.longitude
		)
		let nearest5Ids = Set(
			getNearestFacilities(to: userLocation, limit: 5).map {
				$0.facilityId
			}
		)

		let remaining = getAllFacilities()
			.filter {
				!favourites.contains($0.facilityId)
					&& !nearest5Ids.contains($0.facilityId)
			}

		if remaining.isEmpty {
			print("🔄 No remaining facilities to load")
			return
		}

		print(
			"🔄 Loading occupancy for \(remaining.count) remaining facilities..."
		)
		initialLoadProgress = .loadingRemaining(0, remaining.count)

		/// Load remaining facilities with longer delays to avoid rate limits
		for (index, facility) in remaining.enumerated() {
			await loadOccupancyForFacility(
				facility,
				context: "remaining",
				withDelay: 1.0
			)
			initialLoadProgress = .loadingRemaining(index + 1, remaining.count)
		}
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
			let semaphore = AsyncSemaphore(value: 4)
			
			for facility in facilitiesToRefresh {
				group.addTask {
					await semaphore.wait()
					await self.loadOccupancyForFacility(facility, context: "refresh")
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

/// Core API
extension FacilityRefreshManager {

	func loadOccupancyForFacility(
		_ facility: ParkingFacility,
		context: String,
		withDelay delay: Double = 0.5
	) async {
		await rateLimitedDelay()

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

		// Additional delay to avoid rate limiting
//		if delay > 0.5 {
//			try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
//		}
	}

	func rateLimitedDelay() async {
		let timeSinceLastCall = Date().timeIntervalSince(lastAPICall)
		if timeSinceLastCall < minimumAPIInterval {
			let waitTime = minimumAPIInterval - timeSinceLastCall
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

	private func getFavouriteFacilities() -> [ParkingFacility] {
		guard let context = modelContext else {
			print("❌ No Favourites available")
			return []
		}

		let predicate = #Predicate<ParkingFacility> { facility in
			facility.isFavourite == true
		}

		let descriptor = FetchDescriptor<ParkingFacility>(predicate: predicate)

		do {
			return try context.fetch(descriptor)
		} catch {
			print("❌ Failed to fetch favourites: \(error)")
			return []
		}
	}

	private func getNearestFacilities(
		to userLocation: (latitude: Double, longitude: Double),
		limit: Int
	) -> [ParkingFacility] {
		let allFacilities = getAllFacilities()
		let sorted = LocationManager.shared.sortFacilitiesByDistance(
			allFacilities
		)
		return Array(sorted.prefix(limit))
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

/// Supporting types

enum AppState {
	case active
	case background

	var refreshInterval: TimeInterval {
		switch self {
		case .active:
			return 30.0  // 30 seconds when app is active
		case .background:
			return 300.0  // 5 minutes when app is in background
		}
	}
}

enum InitialLoadProgress {
	typealias Current = Int
	typealias Total = Int

	case notStarted
	case loadingFavourites(Current, Total)
	case loadingNearest(Current, Total)
	case loadingRemaining(Current, Total)
	case completed

	var description: String {
		switch self {
		case .notStarted:
			return "Ready to load"
		case .loadingFavourites(let current, let total):
			return "Loading favorites (\(current)/\(total))"
		case .loadingNearest(let current, let total):
			return "Loading nearest (\(current)/\(total))"
		case .loadingRemaining(let current, let total):
			return "Loading remaining (\(current)/\(total))"
		case .completed:
			return "All data loaded"
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
		case .loadingFavourites(let current, let total):
			return total > 0 ? Double(current) / Double(total) * 0.3 : 0.3
		case .loadingNearest(let current, let total):
			return 0.3
				+ (total > 0 ? Double(current) / Double(total) * 0.3 : 0.3)
		case .loadingRemaining(let current, let total):
			return 0.6
				+ (total > 0 ? Double(current) / Double(total) * 0.4 : 0.4)
		case .completed:
			return 1.0
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

struct RefreshBatch {
	let facilities: [ParkingFacility]
	let tier: RefreshTier
	let maxConcurrency: Int

	var refreshInterval: TimeInterval {
		switch tier {
		case .realTime: return 15
		case .standard: return 600  // 10 min
		case .background: return 1800  // 30 min
		case .onDemand: return .infinity
		}
	}
}
