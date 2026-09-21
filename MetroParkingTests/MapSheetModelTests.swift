//
//  MapSheetModelTests.swift
//  MetroParking
//
//  Created by Tom Kwok on 13/9/2026.
//

import CoreLocation
import MapKit
import SwiftUI
import Testing

@testable import MetroParking

@MainActor
@Suite("Map sheet navigation", .tags(.navigation))
struct MapSheetModelTests {

	@Test func `starts on the facility list with nothing selected`() {
		let model = MapSheetModel()

		#expect(model.path.isEmpty)
		#expect(model.selectedFacilityId == nil)
		#expect(model.detent == .medium)
	}

	@Test func `selecting a facility shows its detail`() {
		let model = MapSheetModel()

		model.select("6")

		#expect(model.path == [.facility(id: "6")])
		#expect(model.selectedFacilityId == "6")
	}

	@Test func `selecting replaces a deeper navigation path`() {
		let model = MapSheetModel()
		model.path = [.facility(id: "6"), .facility(id: "7")]

		model.select("17")

		#expect(model.path == [.facility(id: "17")])
	}

	@Test func `selection follows the top of the path after a nearby push`() {
		let model = MapSheetModel()
		model.select("6")

		model.path.append(.facility(id: "7"))

		#expect(model.selectedFacilityId == "7")
	}

	@Test func `selecting the current facility keeps the path unchanged`() {
		let model = MapSheetModel()
		model.path = [.facility(id: "6"), .facility(id: "7")]

		model.select("7")

		#expect(model.path == [.facility(id: "6"), .facility(id: "7")])
	}

	@Test func `selecting from the collapsed sheet expands it to medium`() {
		let model = MapSheetModel()
		model.detent = MapSheetModel.peekDetent

		model.select("6")

		#expect(model.detent == .medium)
	}

	@Test func `selecting from a full-height list keeps the sheet large`() {
		let model = MapSheetModel()
		model.detent = .large

		model.select("6")

		#expect(model.detent == .large)
	}

	@Test func `tapping a pin while the sheet is large reveals the map`() {
		let model = MapSheetModel()
		model.detent = .large

		model.handleMapSelection("6")

		#expect(model.selectedFacilityId == "6")
		#expect(model.detent == .medium)
	}

	@Test func `tapping empty map returns to the list`() {
		let model = MapSheetModel()
		model.select("6")

		model.handleMapSelection(nil)

		#expect(model.path.isEmpty)
		#expect(model.selectedFacilityId == nil)
	}

	@Test func `focusing moves the camera to the facility`() throws {
		let model = MapSheetModel()
		let coordinate = CLLocationCoordinate2D(latitude: -33.8, longitude: 151.0)

		model.focus(on: coordinate)

		let region = try #require(model.camera.region)
		#expect(region.center.latitude == coordinate.latitude)
		#expect(region.center.longitude == coordinate.longitude)
		#expect(model.camera.positionedByUser == false)
	}

	@Test func `showing all frames every facility`() throws {
		let model = MapSheetModel()
		model.focus(on: CLLocationCoordinate2D(latitude: -33.8, longitude: 151.0))

		model.showAll(fitting: [
			CLLocationCoordinate2D(latitude: -33.9, longitude: 151.0),
			CLLocationCoordinate2D(latitude: -33.7, longitude: 151.2),
		])

		let region = try #require(model.camera.region)
		#expect(abs(region.center.latitude - -33.8) < 0.0001)
		#expect(abs(region.center.longitude - 151.1) < 0.0001)
		// Both points inside, with padding around them.
		#expect(region.span.latitudeDelta > 0.2)
		#expect(region.span.longitudeDelta > 0.2)
		#expect(model.camera.positionedByUser == false)
	}

	@Test func `showing all without coordinates falls back to the overview`()
		throws
	{
		let model = MapSheetModel()

		model.showAll(fitting: [])

		let region = try #require(model.camera.region)
		#expect(
			region.center.latitude
				== MapSheetModel.overviewRegion.center.latitude
		)
		#expect(
			region.center.longitude
				== MapSheetModel.overviewRegion.center.longitude
		)
	}

	@Test func `framing offsets the centre away from the sheet`() throws {
		let model = MapSheetModel()
		let coordinate = CLLocationCoordinate2D(latitude: -33.8, longitude: 151.0)

		model.focus(on: coordinate)
		let unoccluded = try #require(model.camera.region)

		// Half the map covered by the sheet.
		model.bottomOcclusionFraction = 0.5
		model.focus(on: coordinate)
		let occluded = try #require(model.camera.region)

		// The centre moves south, so the facility sits in the visible top half.
		#expect(occluded.center.latitude < unoccluded.center.latitude)
		// And the span grows, so the same context still fits in that half.
		#expect(occluded.span.latitudeDelta > unoccluded.span.latitudeDelta)

		// The facility should land near the middle of the uncovered band.
		let visibleCentre =
			occluded.center.latitude + occluded.span.latitudeDelta * 0.25
		#expect(abs(visibleCentre - coordinate.latitude) < 0.0001)
	}

	@Test func `framing offsets away from the floating panel`() throws {
		let model = MapSheetModel()
		let coordinate = CLLocationCoordinate2D(latitude: -33.8, longitude: 151.0)

		model.leadingOcclusionFraction = 0.5
		model.focus(on: coordinate)
		let region = try #require(model.camera.region)

		// The centre moves west, so the facility sits in the visible trailing half.
		#expect(region.center.longitude < coordinate.longitude)
	}

	@Test func `a single facility gets a usable span, not a zero one`() throws {
		let region = try #require(
			MapSheetModel.region(fitting: [
				CLLocationCoordinate2D(latitude: -33.8, longitude: 151.0)
			])
		)

		#expect(region.span.latitudeDelta > 0)
		#expect(region.span.longitudeDelta > 0)
	}

	@Test func `identical coordinates get a usable span, not a zero one`() throws
	{
		let coordinate = CLLocationCoordinate2D(latitude: -33.8, longitude: 151.0)

		let region = try #require(
			MapSheetModel.region(fitting: [coordinate, coordinate, coordinate])
		)

		#expect(region.center.latitude == coordinate.latitude)
		#expect(region.span.latitudeDelta > 0)
		#expect(region.span.longitudeDelta > 0)
	}
}

@MainActor
@Suite("Deep links", .tags(.navigation), .serialized)
struct DeepLinkTests {

	@Test(
		arguments: [
			("metroparking://facility/6", "6"),
			("metroparking://facility/486", "486"),
		]
	)
	func `facility links select that facility`(url: String, expectedId: String) throws {
		let manager = DeepLinkManager.shared
		defer { manager.clearSelection() }

		let handled = manager.handleURL(try #require(URL(string: url)))

		#expect(handled)
		#expect(manager.selectedFacilityId == expectedId)
	}

	@Test(
		arguments: [
			"https://facility/6",
			"metroparking://settings/6",
			"metroparking://facility",
		]
	)
	func `other links are ignored`(url: String) throws {
		let manager = DeepLinkManager.shared
		manager.clearSelection()

		let handled = manager.handleURL(try #require(URL(string: url)))

		#expect(!handled)
		#expect(manager.selectedFacilityId == nil)
	}
}

@MainActor
@Suite("Floating panel sizing", .tags(.navigation))
struct FloatingPanelTests {

	@Test(
		arguments: [
			(600, 340),  // narrow: clamped up to the minimum width
			(1000, 360),  // 36% of the width
			(1400, 420),  // wide: clamped down to the maximum width
		] as [(CGFloat, CGFloat)]
	)
	func `sizes to the container without a fold`(containerWidth: CGFloat, expected: CGFloat) {
		#expect(FloatingPanel.width(forContainerWidth: containerWidth, fold: nil) == expected)
	}

	@Test func `fills the leading pane up to a vertical fold`() {
		let fold = CGRect(x: 440, y: 0, width: 8, height: 900)

		let width = FloatingPanel.width(forContainerWidth: 888, fold: fold)

		#expect(width == 440 - 2 * FloatingPanel.margin)
	}

	@Test func `ignores a horizontal fold`() {
		let fold = CGRect(x: 0, y: 400, width: 900, height: 8)

		let width = FloatingPanel.width(forContainerWidth: 1000, fold: fold)

		#expect(width == 360)
	}

	@Test func `ignores a fold that leaves too little room`() {
		let fold = CGRect(x: 200, y: 0, width: 8, height: 900)

		let width = FloatingPanel.width(forContainerWidth: 1000, fold: fold)

		#expect(width == 360)
	}
}
