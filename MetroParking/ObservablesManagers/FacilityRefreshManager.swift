//
//  FacilityRefreshManager.swift
//  MetroParking
//
//	Handle ALL occupancy updates (initial + ongoing)
//
//  Created by Tom Kwok on 21/6/2025.
//

import Foundation
import OSLog
import SwiftData
import SwiftUI

@MainActor
class FacilityRefreshManager: ObservableObject {

	static let shared = FacilityRefreshManager()

	/// Published properties for UI updates
	@Published var isRefreshing = false
	@Published var lastRefreshTime: Date?
	@Published var initialLoadProgress: InitialLoadProgress = .notStarted

	/// App state
	private var currentAppState: AppState = .active
	private var refreshTimer: Timer?
	private weak var timerForCleanup: Timer?
	private var modelContext: ModelContext?

	private init() {
		setupAppStateObservers()
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
		let timer = timerForCleanup
		timer?.invalidate()
	}
}

// MARK: - Core API
extension FacilityRefreshManager {

	func loadFacility(
		_ facility: ParkingFacility,
	) async {

		do {
			let response = try await ParkingAPIService.shared.fetchFacility(
				id: facility.facilityId
			)

			// Update facility with API response
			await MainActor.run {
				withAnimation(.snappy(duration: 0.2, extraBounce: 0.5)) {
					facility.updateFromAPI(response)
				}
				// TODO: ProgressCallBack()
			}
			facility.scheduleNextRefresh(appState: currentAppState)
		} catch {
			facility.markRefreshFailed()
			// TODO: ProgressCallBack()
		}

	}
}

// MARK: - SwiftData Queries
extension FacilityRefreshManager {

	private func getAllFacilities() -> [ParkingFacility] {
		guard let context = modelContext else { return [] }

		let descriptor = FetchDescriptor<ParkingFacility>()

		do {
			return try context.fetch(descriptor)
		} catch {
			Logger.facilityRefresh.error(
				"❌ Failed to fetch all facilities: \(error)"
			)
			return []
		}
	}

	private func saveContext() {
		guard let context = modelContext else { return }

		do {
			try context.save()
		} catch {
			Logger.facilityRefresh.error("❌ Failed to save context: \( error )")
		}

	}
}

// MARK: - App lifecycle management
extension FacilityRefreshManager {

	private func setupAppStateObservers() {
		// ?
		NotificationCenter.default.addObserver(
			forName: UIApplication.didBecomeActiveNotification,
			object: nil,
			queue: .main
		) { [weak self] _ in
			Task { @MainActor in
				Logger.facilityRefresh.notice("📱 App became active")
				self?.currentAppState = .active
			}
		}

		NotificationCenter.default.addObserver(
			forName: UIApplication.didEnterBackgroundNotification,
			object: nil,
			queue: .main
		) { [weak self] _ in
			Task { @MainActor in
				Logger.facilityRefresh.notice("🌙 App entered background")
				self?.currentAppState = .background
			}
		}
	}
}

// MARK: - Main flow
extension FacilityRefreshManager {

	func setModelContext(_ context: ModelContext) {
		self.modelContext = context
		Logger.facilityRefresh
			.notice("🏭 Refresh manager connected to SwiftData")
	}

	/// When the app is opened for the first time, awaked from the background, or the user requests, run this function to load the data immediately
	func performLoad() async {
		guard !isRefreshing, modelContext != nil else { return }

		Logger.facilityRefresh.info("Starting loading data")
		isRefreshing = true
		initialLoadProgress = .loading(0, 0)

		let facilities = getAllFacilities().filter {
			$0.refreshTier != .onDemand
		}
		let totalCount = facilities.count
		await MainActor.run {
			initialLoadProgress = .loading(0, totalCount)
		}

		let prioritisedFacilities = prioritiseFacilities(facilities)

		for facility in prioritisedFacilities {
			await loadFacility(facility)
		}

		isRefreshing = false
		initialLoadProgress = .completed
		lastRefreshTime = Date()
		saveContext()

		Logger.facilityRefresh.notice("✅ \( totalCount ) facilities loaded")
	}

	func startAutoRefresh() {
		guard refreshTimer == nil else {
			Logger.facilityRefresh.warning("⏩ Auto-refresh already running")
			return
		}

		Logger.facilityRefresh.notice("🔄 Starting auto-refresh cycle...")
		scheduleNextRefresh()
	}

	func stopAutoRefresh() {
		Logger.facilityRefresh.notice("⏹️ Stopping auto-refresh cycle")
		refreshTimer?.invalidate()
		refreshTimer = nil
		timerForCleanup = nil
	}
}

// MARK: - Loading facilities
/// Using Rolling Window approach — fire 5 concurrent requests at all times to respect the API throttling limits
extension FacilityRefreshManager {

	private func prioritiseFacilities(_ facilities: [ParkingFacility])
		-> [ParkingFacility]
	{
		var prioritised: [ParkingFacility] = []
		var remaining = facilities
		// MARK: - Step 1: Load favourites
		let favourites = remaining.filter { $0.isFavourite }
		prioritised.append(contentsOf: favourites)
		remaining.removeAll { $0.isFavourite }

		// MARK: - Step 2: Load recently-visited ones
		let recents =
			remaining
			.filter { $0.lastVisited != nil }
			.sorted { $0.lastVisited! > $1.lastVisited! }

		prioritised.append(contentsOf: recents)
		remaining.removeAll { $0.lastVisited != nil }

		// MARK: - Step 3: Load the most stale data
		let stalest = remaining.sorted {
			$0.timeSinceLastRefresh > $1.timeSinceLastRefresh
		}
		prioritised.append(contentsOf: stalest)

		return prioritised
	}
}

// MARK: - Manually refresh one facility
extension FacilityRefreshManager {

	/// Refresh a single facility if data is stale
	func refreshFacilityIfNeeded(_ facility: ParkingFacility) async {
		let timeSinceLastRefresh = facility.timeSinceLastRefresh
		let shouldRefresh =
			timeSinceLastRefresh > 30.0 || !facility.isOccupancyCacheValid

		if shouldRefresh {
			Logger.facilityRefresh.info(
				"🔄 Refreshing \(facility.name) in detail view (age: \(Int(timeSinceLastRefresh))s)"
			)
			await refreshSingleFacility(facility)
		}
	}

	/// Force refresh a single facility (for manual refresh button)
	func refreshSingleFacility(_ facility: ParkingFacility) async {
		guard !isRefreshing else { return }

		Logger.facilityRefresh.info("🔄 Force refreshing \( facility.name )")
		isRefreshing = true

		// Reuse existing `loadOccupancyForFacility` function
		await loadFacility(facility)

		// Reuse existing saveContext function
		saveContext()

		isRefreshing = false
		lastRefreshTime = Date()
	}
}

// MARK: - Ongoing refresh cycle
extension FacilityRefreshManager {

	private func scheduleNextRefresh() {
		let interval = currentAppState.refreshInterval

		refreshTimer = Timer.scheduledTimer(
			withTimeInterval: interval,
			repeats: false
		) {
			[weak self] _ in
			Task { @MainActor in
				await self?.performLoad()
				self?.scheduleNextRefresh()
			}
		}

		timerForCleanup = refreshTimer
	}
}

// MARK: - Supporting types
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
