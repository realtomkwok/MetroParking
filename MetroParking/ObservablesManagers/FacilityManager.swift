///
//  FacilityManager.swift
//  MetroParking
//
//  Created by Tom Kwok on 31/8/2025.
//

/// This component serves as a middle layer between the view and model and manages the following functions:
/// - Loading data from API ( plus bulk actions)
/// - Saving to SwiftData
/// - Auto-refresh logic
/// - NO sorting and filtering logics as they're presentation logic

import Foundation
import OSLog
import SwiftData
import SwiftUI

@Observable
class FacilityManager {

	static let shared = FacilityManager()

	// MARK: - Live data
	var isRefreshing = false
	var lastRefreshTime: Date?
	var loadProgress: LoadProgress = .notStarted

	// MARK: - Static data
	var isLoadingStaticData = false
	var staticDataLoadTime: Date?

	private var modelContext: ModelContext?
	private var currentAppState: AppState = .active
	private var refreshTask: Task<Void, Never>?

	private init() {
		setupAppStateObservers()
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
		refreshTask?.cancel()
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
				"❌ Failed to check existing facilities: \(error.localizedDescription)"
			)
			return false
		}
	}

	func clearAllFacilities() async {
		guard let context = modelContext else {
			return
		}

		let descriptor = FetchDescriptor<ParkingFacility>()

		do {
			let facilities = try context.fetch(descriptor)
			for facility in facilities {
				context.delete(facility)
			}
			try context.save()
			Logger.facilityData.notice("🗑️ Cleared all facilities")
		} catch {
			Logger.facilityData.error(
				"❌ Failed to clear facilities: \(error.localizedDescription)"
			)
		}

	}
}

// MARK: - Live data management
extension FacilityManager {

	/// When the app is opened for the first time, awakened from the background, or it is requested by the user, run this function to load the data immediately
	@MainActor
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

		// Fetch facilities asynchronously to avoid blocking
		let allFacilities: [ParkingFacility] = await getAllFacilities()

		// Single-pass filtering and categorisation
		var critical: [ParkingFacility] = []
		var standard: [ParkingFacility] = []
		var background: [ParkingFacility] = []
		
		for facility in allFacilities {
			// Determine if facility needs refresh
			let needsRefresh = !facility.vacancy.isCacheValid 
				|| (forced && facility.refreshTier == .critical)
			
			guard needsRefresh else { continue }
			
			// Categorise by tier in one pass
			switch facility.refreshTier {
			case .critical:
				critical.append(facility)
			case .standard:
				standard.append(facility)
			case .background:
				background.append(facility)
			}
		}

		// Build priority-ordered list: critical first, then standard, then background
		let toLoad = critical + standard + background

		Logger.facilityRefresh
			.debug(
				"Loading \(toLoad.count) facilities (\(critical.count) critical, \(standard.count) standard, \(background.count) background)"
			)

		loadProgress = .loading(0, toLoad.count)

		// Load critical facilities first, individually and sequentially
		var processedCount = 0

		if !critical.isEmpty {
			Logger.facilityRefresh.notice(
				"⭐️ Loading \(critical.count) critical facilities first..."
			)
			for facility in critical {
				await loadFacility(facility)
				processedCount += 1

				loadProgress = .loading(processedCount, toLoad.count)

			}
		}

		// Load standard and background facilities concurrently in batches
		let remainingFacilities = standard + background
		if !remainingFacilities.isEmpty {
			let batchSize = 3  // Load 3 facilities at once

			for i in stride(
				from: 0,
				to: remainingFacilities.count,
				by: batchSize
			) {
				let endIndex = min(i + batchSize, remainingFacilities.count)
				let batch = Array(remainingFacilities[i..<endIndex])

				// Load batch concurrently
				await withTaskGroup(of: Void.self) { group in
					for facility in batch {
						group.addTask {
							await self.loadFacility(facility)
						}
					}
				}

				processedCount += batch.count

				await MainActor.run {
					loadProgress = .loading(processedCount, toLoad.count)
				}
			}
		}

		isRefreshing = false
		loadProgress = .completed
		lastRefreshTime = Date()

		await saveContext()

		Logger.facilityRefresh.notice(
			"✅ \( processedCount ) facilities updated"
		)

		// Schedule next refresh if app is active
		if currentAppState == .active {
			scheduleNextRefresh()
		}
	}

	@MainActor
	func loadFacility(_ facility: ParkingFacility) async {
		guard !facility.vacancy.isCacheValid else {
			Logger.facilityRefresh
				.info(
					"Cache still valid for \(facility.displayName.title) - \(facility.displayName.subtitle)"
				)
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

			// Wrap the update in an animation to trigger content transitions
			await MainActor.run {
				withAnimation(.snappy) {
					facility.updateFromAPI(response)
				}
			}

			Logger.facilityRefresh
				.info(
					"✅ Updated \(facility.displayName.title) - \(facility.displayName.subtitle)"
				)
		} catch {
			Logger.facilityRefresh.error(
				"❌ Failed to fetch \(facility.displayName.title) - \(facility.displayName.subtitle): \(error.localizedDescription)"
			)
		}
	}

	/// Schedule the next refresh using modern async/await pattern
	private func scheduleNextRefresh() {
		stopAutoRefresh()

		let interval = currentAppState.refreshInterval
		Logger.facilityRefresh.notice(
			"⏰ Scheduling next refresh in \(interval)s"
		)

		refreshTask = Task { @MainActor in
			try? await Task.sleep(for: .seconds(interval))

			// Check if task was cancelled
			guard !Task.isCancelled else {
				Logger.facilityRefresh.debug("Refresh task was cancelled")
				return
			}

			// Only refresh if still active
			guard self.currentAppState == .active else {
				return
			}

			await self.performLoad()
		}
	}

	func startAutoRefresh() {
		guard refreshTask == nil || refreshTask?.isCancelled == true else {
			Logger.facilityRefresh.warning("⏩ Auto-refresh already running")
			return
		}

		Logger.facilityRefresh.notice("🔄 Starting auto-refresh cycle...")

		Task {
			await performLoad()
		}
	}

	func stopAutoRefresh() {
		refreshTask?.cancel()
		refreshTask = nil
		Logger.facilityRefresh.notice("⏹️ Auto refresh stopped")
	}
}

// MARK: - Helper Methods
extension FacilityManager {

	func getAllFacilities() async -> [ParkingFacility] {
		guard let context = modelContext else { return [] }

		let descriptor = FetchDescriptor<ParkingFacility>()
		do {
			return try context.fetch(descriptor)
		} catch {
			Logger.facilityRefresh.error(
				"❌ Failed to fetch all facilities: \(error.localizedDescription)"
			)
			return []
		}
	}

	/// Save SwiftData context with error handling
	private func saveContext() async {
		guard let context = modelContext else { return }

		do {
			if context.hasChanges {
				try context.save()
				Logger.facilityRefresh.debug("💾 Context saved successfully")
			}
		} catch {
			Logger.facilityRefresh
				.error(
					"❌ Failed to save context: \(error.localizedDescription)"
				)
		}
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
