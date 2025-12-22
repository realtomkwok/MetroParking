//
//  AppStateManager.swift
//  MetroParking
//
//  Created by Tom Kwok on 31/8/2025.
//

import Foundation
import MapKit
import OSLog
import SwiftUI

@Observable
class AppStateManager {

	static let shared = AppStateManager()

	// MARK: - App Lifecycle State
	var appState: AppState = .active

	private let facilityManager = FacilityManager.shared

	private init() {
		setupLifecycleObservers()
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}
}


// MARK: - App Lifecycle Management
extension AppStateManager {

	private func setupLifecycleObservers() {
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(appDidBecomeActive),
			name: UIApplication.didBecomeActiveNotification,
			object: nil
		)

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(appWillResignActive),
			name: UIApplication.willResignActiveNotification,
			object: nil
		)

		Logger.app.notice("👀 App lifecycle observers registered")
	}

	@objc private func appDidBecomeActive() {
		Logger.app.notice("📱 App became active")
		appState = .active

		// Trigger data refresh when returning to foreground
		Task {
			await facilityManager.performLoad()
		}
	}

	@objc private func appWillResignActive() {
		Logger.app.notice("🌙 App entering background")
		appState = .background

		// Stop auto-refresh to conserve resources
		facilityManager.stopAutoRefresh()

		// Update widget with latest data before backgrounding
		Task {
			await facilityManager.updateWidgetBeforeBackground()
		}

		// Schedule background refresh task
		BackgroundTaskManager.shared.scheduleAppRefresh()
	}
}

