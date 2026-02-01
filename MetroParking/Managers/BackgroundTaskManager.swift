//
//  BackgroundTaskManager.swift
//  MetroParking
//
//  Created by Tom Kwok on 18/12/2025.
//

/// Manages background refresh tasks for facility data updates.
/// Coordinates with RefreshConfiguration for timing and WidgetBudgetTracker for widget reloads.
///
/// Reference: https://developer.apple.com/documentation/UIKit/using-background-tasks-to-update-your-app

import BackgroundTasks
import Foundation
import OSLog
import SwiftData

final class BackgroundTaskManager {

	static let shared = BackgroundTaskManager()

	static let appRefreshTaskID = "com.tomkwok.MetroParking.refresh"
	static let processingTaskID = "com.tomkwok.MetroParking.process"

	// Track last scheduling time to prevent duplicate scheduling
	private var lastAppRefreshScheduleTime: Date?
	private var lastProcessingTaskScheduleTime: Date?
	
	// Minimum time between scheduling attempts (prevent rapid re-scheduling)
	private let minScheduleInterval: TimeInterval = 5.0 // 5 seconds

	private init() {}

	// MARK: - Registration (call from App init)
	func registerBackgroundTasks() {
		Logger.facilityRefresh.notice("🔄 Registering background tasks...")

		let appRefreshSuccess = BGTaskScheduler.shared
			.register(
				forTaskWithIdentifier: Self.appRefreshTaskID,
				using: nil
			) { task in
				Task {
					await self.handleAppRefresh(task: task as! BGAppRefreshTask)
				}
			}

		let bgProcessingSuccess = BGTaskScheduler.shared
			.register(
				forTaskWithIdentifier: Self.processingTaskID,
				using: nil
			) { task in
				Task {
					await self.handleProcessingTask(
						task: task as! BGProcessingTask
					)
				}
			}

		if appRefreshSuccess && bgProcessingSuccess {
			Logger.facilityRefresh.notice(
				"✅ Successfully registered background tasks"
			)
		} else {
			Logger.facilityRefresh.error(
				"❌ Failed to register background tasks - appRefresh: \(appRefreshSuccess), processing: \(bgProcessingSuccess)"
			)
			Logger.facilityRefresh.error(
				"⚠️ Check Info.plist for BGTaskSchedulerPermittedIdentifiers"
			)
		}
	}
}

// MARK: - Schedule
extension BackgroundTaskManager {

	/// Schedule an app refresh task using RefreshConfiguration timing
	func scheduleAppRefresh() {
		// Prevent rapid re-scheduling
		if let lastSchedule = lastAppRefreshScheduleTime,
		   Date().timeIntervalSince(lastSchedule) < minScheduleInterval {
			Logger.facilityRefresh.debug("⏭️ Skipping app refresh schedule (too soon)")
			return
		}
		
		// Cancel any existing pending requests first to avoid "too many pending" error
		BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.appRefreshTaskID)
		
		let request = BGAppRefreshTaskRequest(identifier: Self.appRefreshTaskID)

		// Use centralised configuration for interval
		let interval = RefreshConfiguration.BackgroundTaskInterval.current()
		request.earliestBeginDate = Date(timeIntervalSinceNow: interval)

		do {
			try BGTaskScheduler.shared.submit(request)
			lastAppRefreshScheduleTime = Date()
			Logger.facilityRefresh.info(
				"✅ Scheduled app refresh in \(Int(interval / 60)) minutes"
			)
		} catch {
			logSchedulingError(error, taskType: "app refresh")
		}
	}

	/// Schedule a processing task for full data sync
	func scheduleProcessingTask(requiresCharging: Bool = false) {
		// Prevent rapid re-scheduling
		if let lastSchedule = lastProcessingTaskScheduleTime,
		   Date().timeIntervalSince(lastSchedule) < minScheduleInterval {
			Logger.facilityRefresh.debug("⏭️ Skipping processing task schedule (too soon)")
			return
		}
		
		// Cancel any existing pending requests first to avoid "too many pending" error
		BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.processingTaskID)
		
		let request = BGProcessingTaskRequest(identifier: Self.processingTaskID)

		request.requiresNetworkConnectivity = true
		request.requiresExternalPower = requiresCharging
		request.earliestBeginDate = Date(
			timeIntervalSinceNow: RefreshConfiguration.BackgroundTaskInterval.processingTask
		)

		do {
			try BGTaskScheduler.shared.submit(request)
			lastProcessingTaskScheduleTime = Date()
			Logger.facilityRefresh.info(
				"📅 Scheduled processing task in \(Int(RefreshConfiguration.BackgroundTaskInterval.processingTask / 3600)) hours"
			)
		} catch {
			logSchedulingError(error, taskType: "processing task")
		}
	}

	/// Schedule a processing task only if none is currently pending.
	/// Used at app launch to ensure the task chain is always started.
	func scheduleProcessingTaskIfNeeded() {
		BGTaskScheduler.shared.getPendingTaskRequests { [weak self] requests in
			guard let self = self else { return }

			let hasProcessingTask = requests.contains {
				$0.identifier == Self.processingTaskID
			}

			if !hasProcessingTask {
				Logger.facilityRefresh.info("📅 No processing task pending, scheduling initial task")
				self.scheduleProcessingTask()
			} else {
				Logger.facilityRefresh.debug("⏭️ Processing task already pending, skipping schedule")
			}
		}
	}

	private func logSchedulingError(_ error: Error, taskType: String) {
		Logger.facilityRefresh.error(
			"❌ Failed to schedule \(taskType): \(error.localizedDescription)"
		)

		if let bgError = error as? BGTaskScheduler.Error {
			switch bgError.code {
			case .unavailable:
				Logger.facilityRefresh.error("⚠️ Background tasks unavailable (check device settings or simulator)")
			case .tooManyPendingTaskRequests:
				Logger.facilityRefresh.error("⚠️ Too many pending task requests (this shouldn't happen with cancellation)")
			case .notPermitted:
				Logger.facilityRefresh.error("⚠️ Task not permitted - REQUIRED ACTION:")
				Logger.facilityRefresh.error("   1. Add BGTaskSchedulerPermittedIdentifiers to Info.plist")
				Logger.facilityRefresh.error("   2. Add UIBackgroundModes to Info.plist")
				case .immediateRunIneligible:
					Logger.facilityRefresh.error("Immediate run is i")
				@unknown default:
				Logger.facilityRefresh.error("⚠️ Unknown BGTaskScheduler error: \(bgError.code.rawValue)")
			}
		}
	}
}

// MARK: - Handler
extension BackgroundTaskManager {

	func handleAppRefresh(task: BGAppRefreshTask) async {
		Logger.facilityRefresh.notice("🔄 Starting app refresh task")

		// Track execution time for debugging
		UserDefaults.standard.set(Date(), forKey: "lastAppRefresh")

		// Note: Next scheduling is handled by AppStateManager.appWillResignActive()
		// when the app next enters background. No need to schedule here.

		let workTask = Task {
			await performQuickRefresh()
		}

		task.expirationHandler = {
			Logger.facilityRefresh.warning("⏰ App refresh time limit reached")
			workTask.cancel()
		}

		await workTask.value
		task.setTaskCompleted(success: !workTask.isCancelled)

		Logger.facilityRefresh.notice("✅ App refresh task completed (success: \(!workTask.isCancelled))")
	}

	func handleProcessingTask(task: BGProcessingTask) async {
		Logger.facilityRefresh.notice("🔄 Starting processing task")

		// Track execution time for debugging
		UserDefaults.standard.set(Date(), forKey: "lastProcessingTask")

		// Note: Schedule next task AFTER completion, not before
		// This prevents wasted scheduling if the task is cancelled/expires

		let workTask = Task {
			await performFullRefresh()
		}

		task.expirationHandler = {
			Logger.facilityRefresh.warning("⏰ Processing task time limit")
			workTask.cancel()
		}

		await workTask.value

		let success = !workTask.isCancelled
		task.setTaskCompleted(success: success)

		// Schedule next processing task after completion
		// This ensures the task chain continues even if this task was cancelled
		scheduleProcessingTask()

		Logger.facilityRefresh.notice("✅ Processing task completed (success: \(success)), next task scheduled")
	}
}

// MARK: - Refresh Operations
extension BackgroundTaskManager {

	/// Quick refresh for watched facilities only (favourites + widgets)
	/// Used by BGAppRefreshTask with ~30 second time limit
	@MainActor
	func performQuickRefresh() async {
		let startTime = Date()

		let container = SharedDataManager.sharedContainer
		let context = ModelContext(container)

		// Fetch only watched facilities (favourites + widgets)
		let descriptor = FetchDescriptor<ParkingFacility>(
			sortBy: [SortDescriptor(\.name)]
		)

		do {
			let allFacilities: [ParkingFacility] = try context.fetch(descriptor)
			let watchedFacilities = allFacilities.filter {
				$0.refreshTier == .watched
			}

			guard !watchedFacilities.isEmpty else {
				Logger.facilityRefresh.info("No watched facilities to refresh")
				return
			}

			var dataChanged = false
			let maxFacilities = min(
				watchedFacilities.count,
				RefreshConfiguration.API.quickRefreshLimit
			)

			// Get all widget facility IDs for checking updates
			let widgetFacilityIds = Set(SharedDataManager.shared.getWidgetFacilityIDs())

			for facility in watchedFacilities.prefix(maxFacilities) {
				guard !Task.isCancelled else { break }

				// Rate limit at dispatch level
				await APIDispatcher.shared.requestSlot()

				guard APIUsageMonitor.canMakeCall else { break }

				// Check timeout
				if Date().timeIntervalSince(startTime)
					> RefreshConfiguration.API.quickRefreshTimeout
				{
					break
				}

				// Skip if cache still valid for background operations
				guard facility.shouldRefresh(appState: .background) else {
					Logger.facilityRefresh.debug(
						"⏭️ \(facility.displayName.title) - cache valid"
					)
					continue
				}

				let spacesBefore = facility.vacancy.available

				do {
					let response = try await ParkingAPIService.shared.fetchFacility(
						id: facility.facilityId
					)

					facility
						.updateOccupancy(
							occupied: Int(response.occupancy.total ?? "0") ?? 0,
							totalSpaces: Int(
								response.spots
							) ?? facility.totalSpaces
						)

					// Update widget cache if this facility is displayed in a widget
					// Note: Widget reload happens once at end via WidgetBudgetTracker
					if widgetFacilityIds.contains(facility.facilityId) {
						SharedDataManager.shared.cacheWidgetDataIfSelected(facility)
					}

					// Check if change is significant enough for widget update
					let change = abs(spacesBefore - facility.vacancy.available)
					if change >= RefreshConfiguration.Widget.backgroundChangeThreshold {
						dataChanged = true
					}
				} catch {
					facility.markRefreshFailed()
					Logger.facilityRefresh.error("❌ Failed: \(facility.facilityId)")
				}
			}

			if context.hasChanges {
				try context.save()
			}

			// Use centralised widget reload
			if dataChanged {
				WidgetBudgetTracker.shared.requestReload()
			}

			Logger.facilityRefresh.notice(
				"✅ Quick refresh completed in \(String(format: "%.1f", Date().timeIntervalSince(startTime)))s"
			)
		} catch {
			Logger.facilityRefresh.error("❌ Quick refresh failed: \(error)")
		}
	}

	/// Full refresh for all facilities
	/// Used by BGProcessingTask with ~10 minute time limit
	@MainActor
	func performFullRefresh() async {
		let startTime = Date()

		let container = SharedDataManager.sharedContainer
		let context = ModelContext(container)

		// Fetch all facilities, prioritising favourites
		let descriptor = FetchDescriptor<ParkingFacility>(
			sortBy: [
				SortDescriptor(\.name),
			]
		)

		do {
			let facilities: [ParkingFacility] = try context.fetch(descriptor)
			var successCount = 0
			var dataChanged = false

			// Get all widget facility IDs for checking updates
			let widgetFacilityIds = Set(SharedDataManager.shared.getWidgetFacilityIDs())

			for facility in facilities {
				guard !Task.isCancelled else { break }

				// Rate limit at dispatch level
				await APIDispatcher.shared.requestSlot()

				guard APIUsageMonitor.canMakeCall else { break }

				// Check timeout
				if Date().timeIntervalSince(startTime)
					> RefreshConfiguration.API.fullRefreshTimeout
				{
					break
				}

				// Skip if cache still valid for background operations
				guard facility.shouldRefresh(appState: .background) else { continue }

				let spacesBefore = facility.vacancy.available

				do {
					let response = try await ParkingAPIService.shared.fetchFacility(
						id: facility.facilityId
					)

					facility
						.updateOccupancy(
							occupied: Int(response.occupancy.total ?? "0") ?? 0,
							totalSpaces: Int(
								response.spots
							) ?? facility.totalSpaces
						)

					successCount += 1

					// Update widget cache if this facility is displayed in a widget
					// Note: Widget reload happens once at end via WidgetBudgetTracker
					if widgetFacilityIds.contains(facility.facilityId) {
						SharedDataManager.shared.cacheWidgetDataIfSelected(facility)
					}

					// More lenient threshold for background
					let change = abs(spacesBefore - facility.vacancy.available)
					if change >= RefreshConfiguration.Widget.backgroundChangeThreshold {
						dataChanged = true
					}
				} catch {
					facility.markRefreshFailed()
					Logger.facilityRefresh.error("❌ Failed: \(facility.facilityId)")
				}
			}

			if context.hasChanges {
				try context.save()
			}

			// Use centralised widget reload
			if dataChanged {
				WidgetBudgetTracker.shared.requestReload()
			}

			Logger.facilityRefresh.notice(
				"✅ Full refresh: \(successCount) facilities in \(String(format: "%.1f", Date().timeIntervalSince(startTime)))s"
			)
		} catch {
			Logger.facilityData.error(
				"❌ Failed to perform full refresh: \(error)"
			)
		}
	}
}
// MARK: - Debug Helpers
extension BackgroundTaskManager {
	
	#if DEBUG
	/// Print all currently scheduled background tasks (debug only)
	func printScheduledTasks() {
		BGTaskScheduler.shared.getPendingTaskRequests { requests in
			if requests.isEmpty {
				Logger.facilityRefresh.notice("📋 No scheduled background tasks")
			} else {
				Logger.facilityRefresh.notice("📋 Scheduled background tasks: \(requests.count)")
				for request in requests {
					let identifier = request.identifier
					let earliest = request.earliestBeginDate?.formatted() ?? "ASAP"
					Logger.facilityRefresh.notice("   • \(identifier) - earliest: \(earliest)")
				}
			}
		}
	}
	
	/// Cancel all pending tasks (debug only)
	func cancelAllTasks() {
		BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.appRefreshTaskID)
		BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.processingTaskID)
		Logger.facilityRefresh.notice("🗑️ Cancelled all background tasks")
	}
	#endif
}

