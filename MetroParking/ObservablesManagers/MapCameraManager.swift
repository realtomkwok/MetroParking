//
//  MapCameraManager.swift
//  MetroParking
//
//  Created by Tom Kwok on 1/9/2025.
//

import Foundation
import MapKit
import OSLog
import SwiftUI

@MainActor
class MapCameraManager: ObservableObject {

	static let shared = MapCameraManager()

	@Published var cameraPosition: MapCameraPosition = .automatic
	@Published var cameraBounds: MapCameraBounds? = nil

	private var facilityManager = FacilityManager.shared

	private var trueCentre: CLLocationCoordinate2D
	private var offsetCentre: CLLocationCoordinate2D? = nil
	private var currentSheetHeight: CGFloat = 0
	private var screenHeight: CGFloat = 0

	private let metresPerDegree: Double = 111_000.0

	private let sydneyRegionCentre = CLLocationCoordinate2D(
		latitude: -33.821870,
		longitude: 151.008529
	)

	init() {
		trueCentre = sydneyRegionCentre
	}
}

extension MapCameraManager {

	func setupInitialCameraPosition(animated: Bool = false) async {
		let facilities = await facilityManager.getAllFacilities()
		guard !facilities.isEmpty else {
			Logger.mapCamera.debug(
				"No facilities available for initial camera setup"
			)
			return
		}

		let coordinates = facilities.map { facility in
			CLLocationCoordinate2D(
				latitude: facility.latitude,
				longitude: facility.longitude
			)
		}

		let trueCentre = getTrueCentre(from: coordinates)
		self.trueCentre = trueCentre

		updateCameraPosition(trueCentre: trueCentre, context: .overview)

		Logger.mapCamera.debug("Camera position set to initial overview")
	}

	private func getTrueCentre(from coordinates: [CLLocationCoordinate2D])
		-> CLLocationCoordinate2D
	{
		guard !coordinates.isEmpty else {
			Logger.mapCamera.debug("Coordinate not found.")
			return sydneyRegionCentre
		}

		let latitudes = coordinates.map { $0.latitude }
		let longitudes = coordinates.map { $0.longitude }

		let centreLat = latitudes.reduce(0, +) / Double(coordinates.count)
		let centreLon = longitudes.reduce(0, +) / Double(coordinates.count)

		let trueCentre = CLLocationCoordinate2D(
			latitude: centreLat,
			longitude: centreLon
		)

		self.trueCentre = trueCentre

		return CLLocationCoordinate2D(
			latitude: centreLat,
			longitude: centreLon
		)
	}

	private func getDistance(
		from coordinates: [CLLocationCoordinate2D]
	) -> CLLocationDistance {
		guard coordinates.count > 1 else { return 3000 }

		let latitudes = coordinates.map { $0.latitude }
		let longitudes = coordinates.map { $0.longitude }

		let latSpan = (latitudes.max() ?? 0) - (latitudes.min() ?? 0)
		let lonSpan = (longitudes.max() ?? 0) - (longitudes.min() ?? 0)

		let maxSpan = max(latSpan, lonSpan)

		let baseDistance = maxSpan * metresPerDegree
		return max(baseDistance * 1.5, 500)  // Add 50% padding and minimum 500m
	}

	private func getOffsetCentre(
		trueCentre: CLLocationCoordinate2D,
		distance: CLLocationDistance
	) -> CLLocationCoordinate2D {

		// Calculate offset ratio based on sheet coverage
		// Use 0.5 multiplier to shift centre to middle of visible area
		let offsetRatio = (currentSheetHeight / screenHeight) * 0.5

		// Calculate offset in degrees
		let viewHeightInMeters = distance / 2  // Approximate visible height
		let latitudeOffset =
			(viewHeightInMeters * offsetRatio) / metresPerDegree

		let offsetCentre = CLLocationCoordinate2D(
			latitude: trueCentre.latitude - latitudeOffset,  // Subtract to move map up
			longitude: trueCentre.longitude
		)

		Logger.mapCamera.info(
			"""
			Offset calculation:
			Sheet coverage: \(self.currentSheetHeight/self.screenHeight)
			Offset ratio: \(offsetRatio)
			Latitude offset: \(latitudeOffset) degrees
			"""
		)

		return offsetCentre
	}
}

// MARK: - Update maps
extension MapCameraManager {

	func updateCameraPosition(
		trueCentre: CLLocationCoordinate2D,
		mapItems: MKMapItem? = nil,
		context: CameraContext,
		animated: Bool = true,
		coordinates: [CLLocationCoordinate2D] = []
	) {

		Logger.mapCamera
			.debug(
				"Updating camera position. True centre received: \(trueCentre.latitude), \(trueCentre.longitude)"
			)

		let settings = CameraSettings.optimal(for: context)

		let distance =
			settings.distance > 0
			? settings.distance
			: getDistance(
				from: coordinates.isEmpty ? [trueCentre] : coordinates
			)

		let offsetCentre = getOffsetCentre(
			trueCentre: trueCentre,
			distance: distance
		)

		let camera = MapCamera(
			centerCoordinate: offsetCentre,
			distance: distance,
			heading: settings.heading,
			pitch: settings.pitch
		)

		if animated {
			withAnimation(.snappy(duration: 0.2)) {
				cameraPosition = .camera(camera)
			}
		} else {
			cameraPosition = .camera(camera)
		}
	}

	func updateSheetHeight(
		for detent: PresentationDetent,
		_ screenHeight: CGFloat
	) {
		var sheetHeight: CGFloat {
			switch detent {
			case .fraction(0.2): screenHeight * 0.2
			default: screenHeight * 0.5
			}
		}

		if sheetHeight != self.currentSheetHeight {
			self.screenHeight = screenHeight
			self.currentSheetHeight = sheetHeight

			// Should update the map camera view

			updateCameraPosition(
				trueCentre: self.trueCentre,
				context: .overview
			)

			Logger.mapCamera.debug(
				"""
				Screen height: \(screenHeight)
				Current detent and its height: \(self.currentSheetHeight)
				True centre received: \(self.trueCentre.latitude), \(self.trueCentre.longitude)
				"""
			)
		}
	}
}

// Camera Settings
extension MapCameraManager {

	func focusOnFacility(_ facility: ParkingFacility) {
		updateCameraPosition(
			trueCentre: CLLocationCoordinate2D(
				latitude: facility.latitude,
				longitude: facility.longitude
			),
			context: .single
		)
	}

	func zoomToFacilities(_ facilities: [ParkingFacility]) {
		let coordinates = facilities.map { facility in
			CLLocationCoordinate2D(
				latitude: facility.latitude,
				longitude: facility.longitude
			)
		}
		updateCameraPosition(
			trueCentre: getTrueCentre(from: coordinates),
			context: .multiple(count: facilities.count)
		)
	}

	func zoomToAll() {
		// Should init a position
		updateCameraPosition(trueCentre: sydneyRegionCentre, context: .overview)
	}
}

// MARK: - Adaptive camera parameters
struct CameraSettings {
	let heading: Double
	let pitch: Double
	let distance: Double

	static func optimal(for context: CameraContext) -> CameraSettings {
		switch context {
		case .single:
			return CameraSettings(heading: 0, pitch: 15, distance: 3000)
		case .multiple(let count):
			let pitch = min(60, max(30, Double(count) * 5))
			return CameraSettings(heading: 0, pitch: pitch, distance: 0)
		case .overview:
			return CameraSettings(heading: 0, pitch: 0, distance: 500000)
		}
	}
}

enum CameraContext: Equatable {
	case single
	case multiple(count: Int)
	case overview
}
