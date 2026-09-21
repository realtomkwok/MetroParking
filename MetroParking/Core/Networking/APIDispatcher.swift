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

	/// Request permission to make an API call. Suspends until this caller's slot.
	///
	/// The slot is reserved before suspending: actors are reentrant, so reading
	/// `lastDispatchTime`, sleeping, then writing it would let concurrent callers
	/// all wait the same amount and fire together.
	func requestSlot() async {
		let now = Date()
		let slot = max(now, lastDispatchTime.addingTimeInterval(minInterval))
		lastDispatchTime = slot

		let wait = slot.timeIntervalSince(now)
		if wait > 0 {
			Logger.api.debug("Rate limit: waiting \(wait, format: .fixed(precision: 2))s")
			try? await Task.sleep(for: .seconds(wait))
		}
	}

	/// Reset the dispatcher state (useful for testing)
	func reset() {
		lastDispatchTime = .distantPast
	}
}
