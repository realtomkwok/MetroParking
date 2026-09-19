//
//  ETAManager.swift
//  MetroParking
//
//  Created by Tom Kwok on 5/7/2025.
//

import Foundation
import MapKit
import OSLog
import SwiftUI

@MainActor
@Observable
final class ETAManager {

	// MARK: - Static Formatters

	/// Cached distance formatter - creating formatters is expensive
	static let distanceFormatter: MKDistanceFormatter = {
		let formatter = MKDistanceFormatter()
		formatter.unitStyle = .abbreviated
		return formatter
	}()

	// MARK: - Observable State

	/// Travel time of the most recent ETA calculation for `currentFacilityID`
	var currentETA: TimeInterval?

	var isCalculatingETA: Bool = false
	var isCalculatingBatchETA: Bool = false
	var etaError: String?

	// Track which facility we're calculating for
	private(set) var currentFacilityID: String?

	// MARK: - Private State

	private var currentETARequest: MKDirections.Request?
	private var activeTasks: [String: Task<Void, Never>] = [:]
	private var batchETATask: Task<Void, Never>?
	private var lastBatchETATimestamp: Date = .distantPast

	/// Minimum interval between batch ETA runs to avoid MKDirections rate limiting (50 req/60s)
	private let batchETACooldown: TimeInterval = 60

	/// Cache of facility-to-facility driving distances
	private var facilityToFacilityCache: [String: (distance: CLLocationDistance, travelTime: TimeInterval)] = [:]

	static let shared = ETAManager()

	private init() {}

	/// Calculate ETA from user location to facility (lightweight, ETA only)
	/// Automatically caches result in facility model if calculation succeeds
	func calculateETA(
		from userLocation: CLLocationCoordinate2D,
		to facility: ParkingFacility,
		transportType: MKDirectionsTransportType = .automobile,
		forceRefresh: Bool = false
	) async {
		Logger.eta.debug("🚗 calculateETA called")
		Logger.eta.debug(
			"  → To: '\(facility.displayName.title)' (\(facility.facilityId))"
		)
		Logger.eta.debug(
			"  → From: \(userLocation.latitude, format: .fixed(precision: 6)), \(userLocation.longitude, format: .fixed(precision: 6))"
		)
		Logger.eta.debug("  → Force refresh: \(forceRefresh)")

		// Cancel any existing task for this facility
		if let existingTask = activeTasks[facility.facilityId] {
			Logger.eta.debug(
				"  → Cancelling existing ETA task for this facility"
			)
			existingTask.cancel()
		}

		// Check if we have valid cached data and don't need to refresh
		if !forceRefresh,
			let route = facility.route,
		   route.isValid(from: userLocation)
		{
			// Create lightweight route info from cached facility data
			let travelTime = route.travelTime
			let distance = route.distance
			currentFacilityID = facility.facilityId
			Logger.eta.info(
				"🚗 Using cached ETA for '\(facility.displayName.title)': \(self.formatETA(travelTime))/\(self.formatDistance(distance))"
			)

			return
		}

		Logger.eta.debug("  → Starting ETA calculation")
		isCalculatingETA = true
		etaError = nil
		currentFacilityID = facility.facilityId

		let task = Task {
			// Create source and destination using facility's mapItem (synchronous, no network)
			let source = MKMapItem.forCurrentLocation()
			let destination = facility.makeMapItem()

			Logger.eta.debug("  → Creating MKDirections request")
			let request = MKDirections.Request()
			request.source = source
			request.destination = destination
			request.transportType = transportType
			request.requestsAlternateRoutes = false

			currentETARequest = request

			do {
				Logger.eta.debug("  → Calculating ETA...")
				let directions = MKDirections(request: request)
				let response = try await directions.calculateETA()

				// Check if task was cancelled
				guard !Task.isCancelled else {
					Logger.eta.debug("  → Task was cancelled")
					return
				}

				Logger.eta.debug("  → ETA response received")
				/// Only update if this is still the current request
				if currentETARequest == request
					&& currentFacilityID == facility.facilityId
				{
					let travelTime = response.expectedTravelTime
					let distance = response.distance

					isCalculatingETA = false

					// Cache the result in the facility model
					facility.updateRoutingData(
						distance: distance,
						travelTime: travelTime,
						from: userLocation
					)
					currentETA = travelTime

					Logger.eta.info(
						"🚗 ETA calculated for '\(facility.displayName.title)': \(self.formatETA(travelTime))"
					)
				} else {
					Logger.eta.debug(
						"  → Request/facility mismatch, discarding result"
					)
				}
			} catch {
				guard !Task.isCancelled else {
					Logger.eta.debug(
						"  → Task was cancelled during error handling"
					)
					return
				}

				Logger.eta.debug(
					"  → ETA calculation error: \(error.localizedDescription)"
				)
				if currentETARequest == request
					&& currentFacilityID == facility.facilityId
				{
					etaError = "Unable to calculate ETA"
					isCalculatingETA = false
					Logger.eta.error(
						"❌ ETA calculation failed for '\(facility.displayName.title)': \(error.localizedDescription)"
					)
				}
			}

			// Clean up task reference
			activeTasks.removeValue(forKey: facility.facilityId)
			Logger.eta.debug(
				"  → ETA calculation task completed and cleaned up"
			)
		}

		activeTasks[facility.facilityId] = task
	}

	// MARK: - Facility-to-Facility Distance

	/// Calculate driving distance and travel time between two facilities
	func calculateDistanceBetweenFacilities(
		from origin: ParkingFacility,
		to destination: ParkingFacility
	) async -> (distance: CLLocationDistance, travelTime: TimeInterval)? {
		let cacheKey = "\(origin.facilityId)-\(destination.facilityId)"
		if let cached = facilityToFacilityCache[cacheKey] { return cached }

		let request = MKDirections.Request()
		request.source = origin.makeMapItem()
		request.destination = destination.makeMapItem()
		request.transportType = .automobile

		let directions = MKDirections(request: request)
		guard let response = try? await directions.calculateETA() else { return nil }
		let result = (distance: response.distance, travelTime: response.expectedTravelTime)
		facilityToFacilityCache[cacheKey] = result
		return result
	}

	// MARK: - Batch ETA Calculation

	/// Calculate ETA for a facility and return the result without storing in shared state
	/// Useful for batch calculations without updating the UI state
	func getETA(
		from userLocation: CLLocationCoordinate2D,
		to facility: ParkingFacility,
		transportType: MKDirectionsTransportType = .automobile
	) async -> TimeInterval? {
		
		// Check cache first
		if let route = facility.route, route.isValid(from: userLocation) {
			Logger.eta.debug(
				"🚗 getETA: Using cached value for '\(facility.displayName.title)'"
			)
			return route.travelTime
		}

		Logger.eta.debug(
			"🚗 getETA: Calculating for '\(facility.displayName.title)'"
		)
		// Create source and destination using facility's mapItem (synchronous, no network)
		let source = MKMapItem.forCurrentLocation()
		let destination = facility.makeMapItem()

		let request = MKDirections.Request()
		request.source = source
		request.destination = destination
		request.transportType = transportType
		request.requestsAlternateRoutes = false

		do {
			let directions = MKDirections(request: request)
			let response = try await directions.calculateETA()

			let travelTime = response.expectedTravelTime
			let distance = response.distance

			// Cache the result
			facility.updateRoutingData(
				distance: distance,
				travelTime: travelTime,
				from: userLocation
			)

			Logger.eta.info(
				"🚗 getETA completed for '\(facility.displayName.title)': \(self.formatETA(travelTime))"
			)
			return travelTime
		} catch {
			Logger.eta.error(
				"❌ getETA failed for '\(facility.displayName.title)': \(error.localizedDescription)"
			)
			return nil
		}
	}

	// MARK: - Formatting Helpers

	/// Format ETA time interval to readable string
	func formatETA(_ timeInterval: TimeInterval) -> String {
		let duration: Duration = .seconds(timeInterval)
		return duration
			.formatted(
				.units(
					allowed: [.hours, .minutes],
					width: .condensedAbbreviated
				)
			)
	}

	/// Format distance to readable string
	func formatDistance(_ distance: CLLocationDistance) -> String {
		Self.distanceFormatter.string(fromDistance: distance)
	}

	// MARK: - State Management

	/// Cancel ETA calculation for a specific facility
	func cancelETA(for facilityID: String? = nil) {
		if let facilityID = facilityID {
			activeTasks[facilityID]?.cancel()
			activeTasks.removeValue(forKey: facilityID)

			// Only clear if it was for this facility
			if currentFacilityID == facilityID {
				currentETARequest = nil
				isCalculatingETA = false
				etaError = nil
			}
		} else {
			// Cancel all
			activeTasks.values.forEach { $0.cancel() }
			activeTasks.removeAll()
			currentETARequest = nil
			isCalculatingETA = false
			etaError = nil
		}
	}

	/// Clear cached route for a specific facility
	func clearCachedRoute(for facilityID: String) {
		if currentFacilityID == facilityID {
			currentETA = nil
		}
		Logger.eta.debug("🗺️ Cleared cached route for facility: \(facilityID)")
	}

	// MARK: - Batch ETA Calculation

	/// Calculate ETAs for all provided facilities with throttling and failure backoff.
	/// Results are persisted via `facility.updateRoutingData()`, which triggers `@Query` reactivity.
	/// Stops early after `maxConsecutiveFailures` consecutive MKDirections failures.
	func calculateBatchETA(
		from userLocation: CLLocationCoordinate2D,
		for facilities: [ParkingFacility],
		maxConsecutiveFailures: Int = 5
	) async {
		// Enforce cooldown to avoid MKDirections rate limiting
		let timeSinceLastBatch = Date().timeIntervalSince(lastBatchETATimestamp)
		if timeSinceLastBatch < batchETACooldown {
			let remaining = batchETACooldown - timeSinceLastBatch
			Logger.eta.debug(
				"🚗 Batch ETA: cooldown active, waiting \(remaining, format: .fixed(precision: 0))s"
			)
			try? await Task.sleep(for: .seconds(remaining))
			guard !Task.isCancelled else { return }
		}

		batchETATask?.cancel()
		lastBatchETATimestamp = Date()

		isCalculatingBatchETA = true

		let task = Task {
			// Partition: facilities with valid cached routes skip the network call
			var needsCalculation: [ParkingFacility] = []

			for facility in facilities {
				if let route = facility.route,
					route.isValid(from: userLocation)
				{
					// Already cached and valid, skip
				} else {
					needsCalculation.append(facility)
				}
			}

			Logger.eta.info(
				"🚗 Batch ETA: \(needsCalculation.count)/\(facilities.count) need calculation"
			)

			// Process sequentially with backoff on failure
			var consecutiveFailures = 0

			for facility in needsCalculation {
				guard !Task.isCancelled else { break }

				let result = await self.getETA(
					from: userLocation,
					to: facility
				)

				if result != nil {
					consecutiveFailures = 0
				} else {
					consecutiveFailures += 1

					if consecutiveFailures >= maxConsecutiveFailures {
						Logger.eta.warning(
							"🚗 Batch ETA: \(maxConsecutiveFailures) consecutive failures, stopping batch"
						)
						break
					}

					// Exponential backoff: 1s, 2s, 4s, 8s, capped at 16s
					let backoff = min(
						pow(2.0, Double(consecutiveFailures - 1)), 16.0
					)
					Logger.eta.debug(
						"🚗 Batch ETA: failure #\(consecutiveFailures), backing off \(backoff)s"
					)
					try? await Task.sleep(for: .seconds(backoff))
				}

				// Base delay between requests
				try? await Task.sleep(for: .milliseconds(200))
			}

			guard !Task.isCancelled else { return }

			isCalculatingBatchETA = false
			Logger.eta.notice(
				"🚗 Batch ETA complete: \(facilities.count) facilities processed (\(consecutiveFailures) trailing failures)"
			)
		}

		batchETATask = task
		// The work runs in its own task so a newer batch can cancel it;
		// forward cancellation from the caller too.
		await withTaskCancellationHandler {
			await task.value
		} onCancel: {
			task.cancel()
		}
	}
}
