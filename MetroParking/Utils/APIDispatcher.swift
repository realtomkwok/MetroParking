//
//  APIDispatcher.swift
//  MetroParking
//
//  Created by Tom Kwok on 9/1/2026.
//

import Foundation
import OSLog

/// Actor-based API call dispatcher that controls when API calls can start.
///
/// This replaces per-call rate limiting with orchestration-level dispatch control.
/// All API calls should request a slot from this dispatcher before making network requests.
///
/// ## Usage
/// ```swift
/// await APIDispatcher.shared.requestSlot()
/// let response = try await apiService.fetchData()
/// ```
actor APIDispatcher {
	static let shared = APIDispatcher()

	private var lastDispatchTime: Date = .distantPast
	private let minInterval: TimeInterval

	init(minInterval: TimeInterval = RefreshConfiguration.API.minCallInterval) {
		self.minInterval = minInterval
	}

	/// Request permission to make an API call. Blocks until rate limit allows.
	/// Call this before making any API request to ensure proper rate limiting.
	func requestSlot() async {
		let now = Date()
		let elapsed = now.timeIntervalSince(lastDispatchTime)

		if elapsed < minInterval {
			let waitTime = minInterval - elapsed
			Logger.api.debug("Rate limit: waiting \(String(format: "%.2f", waitTime))s")
			try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
		}

		lastDispatchTime = Date()
	}

	/// Reset the dispatcher state (useful for testing)
	func reset() {
		lastDispatchTime = .distantPast
	}
}
