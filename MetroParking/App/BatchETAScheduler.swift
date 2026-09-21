//
//  BatchETAScheduler.swift
//  MetroParking
//
//  Created by Tom Kwok on 21/9/2026.
//

import CoreLocation
import SwiftData
import SwiftUI

/// Keeps every facility's ETA current as the user moves, without the map view
/// having to know when that happens.
///
/// Three things can make the ETAs stale — the store being seeded, location
/// arriving, and the user driving somewhere — and each one funnels through the
/// same cancel-then-reschedule so only the newest calculation survives.
struct BatchETAScheduler: ViewModifier {
	@Environment(\.modelContext) private var modelContext
	@Environment(ETAManager.self) private var etaMgr
	@Environment(FacilityManager.self) private var facilityDataMgr
	@Environment(LocationManager.self) private var locationMgr

	@State private var task: Task<Void, Never>?

	/// Larger distance threshold for ETA recalculation (500m).
	///
	/// At driving speed the 100m location filter fires every ~5s, which
	/// overwhelms MKDirections' 50 requests a minute. ETAs to distant parking
	/// lots don't change meaningfully over 500m anyway.
	private static let distanceThreshold: CLLocationDistance = 500

	func body(content: Content) -> some View {
		content
			.task {
				// Later launches: location is already on hand when the view appears.
				await calculate(from: locationMgr.currentLocation)
			}
			.onChange(of: facilityDataMgr.staticDataLoadTime) {
				// First launch: facilities are seeded after the view appears, so
				// the initial pass above found nothing to calculate.
				schedule(from: locationMgr.currentLocation)
			}
			.onChange(of: locationMgr.isLocationAvailable) {
				schedule(from: locationMgr.currentLocation)
			}
			.onChange(of: locationMgr.currentLocation) { previous, current in
				guard hasMovedFar(from: previous, to: current) else { return }
				schedule(from: current)
			}
	}

	/// Replaces any calculation still in flight.
	private func schedule(from location: CLLocation?) {
		guard let location else { return }

		task?.cancel()
		task = Task {
			await calculate(from: location)
		}
	}

	private func calculate(from location: CLLocation?) async {
		guard let location else { return }

		let facilities = modelContext.allFacilities()
		guard !facilities.isEmpty else { return }

		await etaMgr.calculateBatchETA(
			from: location.coordinate,
			for: facilities
		)
	}

	/// The first fix always counts; after that, only a real move does.
	private func hasMovedFar(from previous: CLLocation?, to current: CLLocation?)
		-> Bool
	{
		guard let current else { return false }
		guard let previous else { return true }
		return current.distance(from: previous) > Self.distanceThreshold
	}
}

extension View {
	/// Recalculates every facility's ETA whenever the user's location moves far
	/// enough to matter.
	func schedulesBatchETA() -> some View {
		modifier(BatchETAScheduler())
	}
}
