//
//  DeepLinkManager.swift
//  MetroParking
//
//  Created by Tom Kwok on 31/12/2025.
//

import Foundation
import SwiftUI
import OSLog

/// Manages deep linking and navigation within the app
@MainActor
@Observable
class DeepLinkManager {
	private let logger = Logger.deeplink

	/// Shared instance
	static let shared = DeepLinkManager()

	/// The facility ID to navigate to (nil means no pending navigation)
	var selectedFacilityId: String?

	private init() {}

	/// Handle an incoming URL and extract navigation information
	/// - Parameter url: The deep link URL to handle
	/// - Returns: true if the URL was handled, false otherwise
	func handleURL(_ url: URL) -> Bool {
		logger.info("📱 Deep link received: \(url.absoluteString)")

		// Expected format: metroparking://facility/{facilityId}
		guard url.scheme == "metroparking",
			url.host == "facility"
		else {
			logger.error("⚠️ Invalid deep link format")
			return false
		}

		// Extract facility ID from path
		let pathComponents = url.pathComponents
		guard pathComponents.count >= 2,
			pathComponents[0] == "/"
		else {
			logger.error("⚠️ Invalid facility ID in deep link")
			return false
		}

		let facilityId = pathComponents[1]
		logger.info("✅ Extracted facility ID: \(facilityId)")

		// Set the facility ID to trigger navigation
		self.selectedFacilityId = facilityId

		return true
	}

	/// Clear the current navigation
	func clearSelection() {
		selectedFacilityId = nil
	}
}
