//
//  FacilityManager.swift
//  MetroParking
//
//  Created by Tom Kwok on 31/8/2025.
//

import Foundation
import OSLog
import SwiftData
import SwiftUI

@MainActor
class FacilityManager: ObservableObject {

	static let shared = FacilityManager()

	// MARK: - Live data
	@Published var isRefreshing = false
	@Published var lastRefreshTime: Date?
	@Published var loadProgress: LoadProgress = .notStarted

	// MARK: - Static data
	@Published var isLoadingStaticData = false
	@Published var staticDataLoadTime: Date?

	private var modelContext: ModelContext?
	private var currentAppState: AppState = .active
	private var refreshTimer: Timer?
	private weak var timeForCleanup: Timer?

	private init() {
		setupAppStateObservers()
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
		timeForCleanup?.invalidate()
	}

	func setModelContext(_ context: ModelContext) {
		self.modelContext = context
		Logger.facilityData.notice("📊 Connected to SwiftData")
	}
}

// MARK: - Static data management
extension FacilityManager {

	/// Load static facility metadata into SwiftData (one-time setup)
	func loadStaticFacilitiesIfNeeded() async {
		guard let context = modelContext else {
			Logger.facilityData.warning("No ModelContext available")
			return
		}

		if await hasExistingFacilities() {
			Logger.facilityData.info("Facilities already loaded")
			return
		}

		guard !isLoadingStaticData else {
			Logger.facilityData.warning(
				"⏩ Static data loading already in progress"
			)
			return
		}

		Logger.facilityData.notice("📦 Loading static facility data...")
		isLoadingStaticData = true

		let staticFacilities = ParkingFacility.getAllStaticFacilities()

		Logger.facilityData.notice(
			"📦 Inserting \(staticFacilities.count) facilities into SwiftData..."
		)

		for facility in staticFacilities {
			context.insert(facility)
		}

		await saveContext()

		staticDataLoadTime = Date()
		isLoadingStaticData = false
		Logger.facilityData.notice("✅ Static facility loading complete!")
	}

	func reloadStaticFacilities() async {
		await clearAllFacilities()
		await loadStaticFacilitiesIfNeeded()
	}

	func hasExistingFacilities() async -> Bool {
		guard let context = modelContext else {
			return false
		}

		let descriptor = FetchDescriptor<ParkingFacility>()

		do {
			let facilities = try context.fetch(descriptor)
			return !facilities.isEmpty
		} catch {
			Logger.facilityData.error(
				"❌ Failed to check existing facilities: \(error)"
			)
			return false
		}
	}

	func clearAllFacilities() async {
		guard let context = modelContext else {
			return
		}

		let descriptor = FetchDescriptor<ParkingFacility>()

		withAnimation(.snappy) {
			do {
				let facilities = try context.fetch(descriptor)
				for facility in facilities {
					context.delete(facility)
				}
				try context.save()
				Logger.facilityData.notice("🗑️ Cleared all facilities")
			} catch {
				Logger.facilityData.error(
					"❌ Failed to clear facilities: \(error)"
				)
			}
		}

	}
}

// MARK: - Live data management
extension FacilityManager {

	/// When the app is opened for the first time, awakened from the background, or it is requested by the user, run this function to load the data immediately
	func performLoad(forced: Bool = false) async {
		guard !isRefreshing else {
			Logger.facilityRefresh
				.warning("Refresh has already started, not refreshing")
			return
		}

		guard modelContext != nil else {
			Logger.facilityRefresh
				.error("Model Context not found, not refreshing")
			return
		}

		Logger.facilityRefresh.info("Starting loading data")
		isRefreshing = true
		loadProgress = .loading(0, 0)

		let allFacilities = getAllFacilities()

		// Separate by tier and cache validity
		let critical = allFacilities.filter {
			$0.refreshTier == .critical && !$0.isOccupancyCacheValid
		}
		let standard = allFacilities.filter {
			$0.refreshTier == .standard && !$0.isOccupancyCacheValid
		}
		let background = allFacilities.filter {
			$0.refreshTier == .background && !$0.isOccupancyCacheValid
		}

		let smartLoadBatches = (critical + standard + background)

		// Load in priority order, respecting API limits
		let toLoad = forced ? smartLoadBatches : allFacilities

		var processedCount = 0

		await MainActor.run {
			loadProgress = .loading(0, toLoad.count)
		}

		for facility in toLoad {
			await loadFacility(facility)
			processedCount += 1

			await MainActor.run {
				loadProgress = .loading(processedCount, toLoad.count)
			}
		}

		isRefreshing = false
		loadProgress = .completed
		lastRefreshTime = Date()

		await saveContext()

		Logger.facilityRefresh.notice("✅ \( processedCount ) facilities updated")
	}

	func loadFacility(_ facility: ParkingFacility) async {
		guard !facility.isOccupancyCacheValid else {
			Logger.facilityRefresh
				.info("Cache still valid for \(facility.displayName)")
			return
		}

		guard APIUsageMonitor.canMakeCall else {
			Logger.facilityRefresh.warning("⚠️ API limit reached")
			return
		}

		do {
			let response = try await ParkingAPIService.shared.fetchFacility(
				id: facility.facilityId
			)

			await MainActor.run {
				withAnimation(.snappy(duration: 0.2, extraBounce: 0.5)) {
					facility.updateFromAPI(response)
				}
			}

			Logger.facilityRefresh.info("✅ Updated \(facility.displayName)")
		} catch {
			Logger.facilityRefresh.error(
				"❌ Failed to fetch \(facility.displayName): \(error)"
			)
		}
	}

	func startAutoRefresh() {
		guard refreshTimer == nil else {
			Logger.facilityRefresh.warning("⏩ Auto-refresh already running")
			return
		}

		Logger.facilityRefresh.notice("🔄 Starting auto-refresh cycle...")

		let interval = currentAppState.refreshInterval

		refreshTimer =
			Timer
			.scheduledTimer(withTimeInterval: interval, repeats: false) {
				[weak self] _ in
				Task { @MainActor in
					await self?.performLoad()
				}
			}

		timeForCleanup = refreshTimer
		Logger.facilityRefresh.notice(
			"⏰ Auto refresh started"
		)
	}

	func stopAutoRefresh() {
		refreshTimer?.invalidate()
		refreshTimer = nil
		Logger.facilityRefresh.notice("⏹️ Auto refresh stopped")
	}
}

// MARK: - Helper Methods
extension FacilityManager {

	/// Get all facilities from SwiftData
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

	/// Save SwiftData context
	private func saveContext() async {
		guard let context = modelContext else { return }

		do {
			try context.save()
		} catch {
			Logger.facilityRefresh.error("❌ Failed to save context: \(error)")
		}
	}

	/// Get user location (convenience method)
	func getUserLocation() -> (lat: Double, lon: Double) {
		let userLoc = LocationManager.shared.userLocation
		return (lat: userLoc.latitude, lon: userLoc.longitude)
	}
}

// MARK: - App lifecycle management
extension FacilityManager {

	private func setupAppStateObservers() {
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(appDidBecomeActive),
			name: UIApplication.didBecomeActiveNotification,
			object: nil
		)

		NotificationCenter.default
			.addObserver(
				self,
				selector: #selector(appWillResignActive),
				name: UIApplication.willResignActiveNotification,
				object: nil
			)
	}

	@objc private func appDidBecomeActive() {
		Logger.facilityRefresh.notice("📱 App became active")
		currentAppState = .active
		Task {
			await performLoad()
		}
	}

	@objc private func appWillResignActive() {
		Logger.facilityRefresh.notice("🌙 App entered background")
		currentAppState = .background
		stopAutoRefresh()
	}
}

// MARK: - Supporting types
enum AppState {
	case active
	case background

	var refreshInterval: TimeInterval {
		switch self {
		case .active: return 15.0
		case .background: return 300.0
		}
	}
}

enum LoadProgress {
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
