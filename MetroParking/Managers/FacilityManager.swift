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
	private var refreshTask: Task<Void, Never>?
	
	// MARK: - Concurrency Control
	private var currentOperationId: UUID?
	private var lastScheduleTime: Date?

	private init() {}

	/// Note: `deinit` will never be called for a singleton, but included
	/// for safety if architecture changes to non-singleton pattern
	deinit {
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
	/// - Parameters:
	///   - forced: Force refresh critical facilities even if cache is valid
	///   - context: Optional ModelContext to use (for background operations). If nil, uses stored context
	///   - shouldScheduleNext: Whether to schedule the next auto-refresh cycle (default: true)
	@MainActor
	func performLoad(forced: Bool = false, context: ModelContext? = nil, shouldScheduleNext: Bool = true) async {
		// Prevent concurrent refresh operations
		let operationId = UUID()
		if let currentOp = self.currentOperationId {
			Logger.facilityRefresh
				.warning("⏩ Refresh operation \(currentOp) already in progress, skipping new operation")
			return
		}

		self.currentOperationId = operationId
		defer {
			if self.currentOperationId == operationId {
				self.currentOperationId = nil
			}
		}

		// Use provided context or fall back to stored context
		let workingContext = context ?? self.modelContext
		guard workingContext != nil else {
			Logger.facilityRefresh
				.error("Model Context not found, not refreshing")
			return
		}

		Logger.facilityRefresh.info("🔄 Starting refresh operation \(operationId)")
		isRefreshing = true
		loadProgress = .loading(0, 0)

		// Fetch facilities using the working context
		let allFacilities: [ParkingFacility] = await getFacilities(from: workingContext!)

		// Single-pass filtering and categorisation (2-tier system)
		var watched: [ParkingFacility] = []
		var unwatched: [ParkingFacility] = []

		for facility in allFacilities {
			// Check if facility needs refresh (uses foreground cache validity)
			guard facility.shouldRefresh(appState: .active, forced: forced) else { continue }

			// Categorise by tier in one pass
			switch facility.refreshTier {
			case .watched:
				watched.append(facility)
			case .unwatched:
				// Prioritise recently visited facilities
				if facility.isRecentlyVisited {
					unwatched.insert(facility, at: 0)
				} else {
					unwatched.append(facility)
				}
			}
		}

		// Build priority-ordered list: watched first, then unwatched
		// Sort each group according to user's preferred sort option for visual consistency
		let sortOption = UserPreferences.shared.preferredSortOption
		let sortedWatched = sortOption.apply(to: watched)
		let sortedUnwatched = sortOption.apply(to: unwatched)
		let toLoad = sortedWatched + sortedUnwatched

		Logger.facilityRefresh
			.debug(
				"Loading \(toLoad.count) facilities (\(watched.count) watched, \(unwatched.count) unwatched) sorted by \(sortOption.display.title)"
			)

		loadProgress = .loading(0, toLoad.count)

		// Process facilities sequentially with rate-limited API calls
		// This ensures UI updates happen immediately after each successful fetch
		var processedCount = 0

		for facility in toLoad {
			// Rate limit before each API call
			await APIDispatcher.shared.requestSlot()

			guard facility.shouldRefresh(appState: .active, forced: forced) else {
				continue
			}

			guard APIUsageMonitor.canMakeCall else {
				break
			}

			do {
				let response = try await ParkingAPIService.shared.fetchFacility(
					id: facility.facilityId
				)

				// Update UI immediately with animation (cascade effect)
				if processedCount > 0 {
					try? await Task.sleep(nanoseconds: UInt64(RefreshConfiguration.API.uiStaggerDelay * 1_000_000_000))
				}

				withAnimation(.snappy) {
					facility.updateFromAPI(response)
				}
				SharedDataManager.shared.cacheWidgetDataIfSelected(facility)

				processedCount += 1
				loadProgress = .loading(processedCount, toLoad.count)
			} catch {
				Logger.facilityRefresh.error(
					"❌ Failed to fetch \(facility.displayName.title): \(error.localizedDescription)"
				)
			}
		}

		isRefreshing = false
		loadProgress = .completed
		lastRefreshTime = Date()

		// Save the working context (could be different from stored context in background operations)
		await saveContext(workingContext!)

		Logger.facilityRefresh.notice(
			"✅ \(processedCount) facilities updated"
		)

		// Trigger widget reload if any data changed (budget-aware)
		if processedCount > 0 {
			WidgetBudgetTracker.shared.requestReload()
		}

		// Schedule next refresh only if requested and app is active
		if shouldScheduleNext && AppStateManager.shared.appState == .active {
			scheduleNextRefresh()
		}
	}

	/// Fetch a single facility's data from the API.
	/// Note: This method does NOT apply rate limiting - caller should use APIDispatcher.
	/// - Returns: The API response if successful, nil otherwise.
	@MainActor
	func loadFacility(_ facility: ParkingFacility) async -> ParkingAPIResponse? {
		guard facility.shouldRefresh(appState: .active) else {
			Logger.facilityRefresh
				.info("⏭️ Cache still valid for \(facility.displayName.title)")
			return nil
		}

		guard APIUsageMonitor.canMakeCall else {
			Logger.facilityRefresh.warning("⚠️ API limit reached")
			return nil
		}

		do {
			return try await ParkingAPIService.shared.fetchFacility(id: facility.facilityId)
		} catch {
			Logger.facilityRefresh.error(
				"❌ Failed to fetch \(facility.displayName.title): \(error.localizedDescription)"
			)
			return nil
		}
	}

	/// Schedule the next refresh using modern async/await pattern
	private func scheduleNextRefresh() {
		// Don't schedule if already scheduled recently (debounce)
		if let lastSchedule = lastScheduleTime,
		   Date().timeIntervalSince(lastSchedule) < 5.0 {
			Logger.facilityRefresh.debug("⏭️ Skipping refresh schedule (too soon since last schedule)")
			return
		}
		
		stopAutoRefresh()

		let interval = AppStateManager.shared.appState.refreshInterval
		Logger.facilityRefresh.notice(
			"⏰ Scheduling next refresh in \(interval)s"
		)
		
		lastScheduleTime = Date()

		refreshTask = Task { @MainActor in
			try? await Task.sleep(for: .seconds(interval))

			// Check if task was cancelled
			guard !Task.isCancelled else {
				Logger.facilityRefresh.debug("Refresh task was cancelled")
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

	/// Fetch all facilities from a given context
	private func getFacilities(from context: ModelContext) async -> [ParkingFacility] {
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

	/// Fetch all facilities from the stored context (for convenience)
	func getContext() async -> [ParkingFacility] {
		guard let context = modelContext else { return [] }
		return await getFacilities(from: context)
	}

	/// Save SwiftData context with error handling
	private func saveContext(_ context: ModelContext? = nil) async {
		let contextToSave = context ?? modelContext
		guard let contextToSave = contextToSave else { return }

		do {
			if contextToSave.hasChanges {
				try contextToSave.save()
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

	/// Update widget with the most recent data before app goes to background
	/// Called by AppStateManager when app is backgrounding
	@MainActor
	func updateWidgetBeforeBackground() async {

		// Get all widget facility IDs
		let widgetFacilityIds = SharedDataManager.shared.getWidgetFacilityIDs()

		guard !widgetFacilityIds.isEmpty else {
			Logger.widget.debug("No widget facilities registered")
			return
		}

		let allFacilities = await getContext()
		var updatedCount = 0

		// Update all widget facilities with latest data
		for facilityId in widgetFacilityIds {
			if let facility = allFacilities.first(where: {
				$0.facilityId == facilityId
			}) {
				SharedDataManager.shared.updateWidget(
					with: facility,
					triggerReload: false  // Don't trigger reload for each facility
				)
				updatedCount += 1
			}
		}

		// Trigger a single widget reload after all updates
		if updatedCount > 0 {
			WidgetBudgetTracker.shared.requestReload()
			Logger.widget.notice(
				"📤 Updated \(updatedCount) widget facilities before background transition"
			)
		}
	}
}

// AppState is defined in RefreshConfiguration.swift

// MARK: - Supporting types
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
// MARK: - Widget Update Coordination
// Note: Widget updates are now handled directly via SharedDataManager.cacheWidgetDataIfSelected()
// Widget reload throttling is managed by WidgetBudgetTracker (15s minimum, 60/day budget)
// The previous WidgetUpdateCoordinator actor has been removed as SharedDataManager is already thread-safe

