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
			// Determine if facility needs refresh
			let needsRefresh =
				!facility.vacancy.isCacheValid
				|| (forced && facility.refreshTier == .watched)

			guard needsRefresh else { continue }

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

		// Build priority-ordered list: watched first, then unwatched (recently visited first)
		let toLoad = watched + unwatched

		Logger.facilityRefresh
			.debug(
				"Loading \(toLoad.count) facilities (\(watched.count) watched, \(unwatched.count) unwatched)"
			)

		loadProgress = .loading(0, toLoad.count)

		// Load watched facilities first, individually and sequentially
		var processedCount = 0

		if !watched.isEmpty {
			Logger.facilityRefresh.notice(
				"⭐️ Loading \(watched.count) watched facilities first..."
			)
			for facility in watched {
				await loadFacility(facility)
				processedCount += 1

				loadProgress = .loading(processedCount, toLoad.count)

			}
		}

		// Load unwatched facilities concurrently in batches
		let remainingFacilities = unwatched
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

		// Save the working context (could be different from stored context in background operations)
		await saveContext(workingContext!)

		Logger.facilityRefresh.notice(
			"✅ \( processedCount ) facilities updated"
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

			// Update widget data in shared storage (but don't reload yet - batched later)
			// Widget updates are coordinated to prevent concurrent writes
			await WidgetUpdateCoordinator.shared.updateIfNeeded(facility)

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
// MARK: - Widget Update Coordinator

/// Coordinates widget data updates to prevent concurrent writes and excessive updates
actor WidgetUpdateCoordinator {
	static let shared = WidgetUpdateCoordinator()
	
	private var lastUpdate: Date?
	private var updateInProgress = false
	
	private init() {}
	
	/// Update widget data if enough time has passed since last update
	/// Prevents concurrent updates and excessive writes
	func updateIfNeeded(_ facility: ParkingFacility) async {
		// Prevent concurrent updates
		guard !updateInProgress else {
			Logger.widget.debug("Widget update already in progress, skipping")
			return
		}
		
		// Rate limit updates (minimum 1 second between updates)
		if let last = lastUpdate,
		   Date().timeIntervalSince(last) < 1.0 {
			Logger.widget.debug("Widget updated too recently, skipping")
			return
		}
		
		updateInProgress = true
		defer { updateInProgress = false }
		
		// Perform the actual update
		SharedDataManager.shared.cacheWidgetDataIfSelected(facility)
		lastUpdate = Date()
	}
}

