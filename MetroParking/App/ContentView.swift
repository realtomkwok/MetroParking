//
//  ContentView.swift
//  MetroParking
//
//  Created by Tom Kwok on 18/5/2025.
//

import MapKit
import OSLog
import SwiftData
import SwiftUI

/// Root view: a full-screen map with the browse/detail stack layered on top.
///
/// - Compact width: a persistent bottom sheet with detents, like Maps on iPhone.
/// - Regular width or compact height (iPhone Duo inner display, landscape):
///   a floating panel beside the map. Layout is driven by size class only,
///   never by device or orientation.
struct ContentView: View {
	@Environment(\.modelContext) private var modelContext
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	@Environment(\.verticalSizeClass) private var verticalSizeClass

	@Environment(FacilityManager.self) private var facilityDataMgr
	@Environment(ETAManager.self) private var etaMgr
	@Environment(LocationManager.self) private var locationMgr
	@Environment(DeepLinkManager.self) private var deepLinkMgr

	@State private var sheet = MapSheetModel()
	@State private var containerSize: CGSize = .zero
	/// Active fold on a foldable (iOS 27.1+), in this view's coordinates.
	@State private var foldFrame: CGRect?
	@State private var batchETATask: Task<Void, Never>?
	@State private var scopeShiftTask: Task<Void, Never>?

	/// Larger distance threshold for ETA recalculation (500m).
	/// At driving speed, 100m triggers every ~5s which overwhelms MKDirections rate limits.
	/// ETAs to distant parking lots don't change meaningfully over 500m.
	private let batchETADistanceThreshold: CLLocationDistance = 500

	private var panelWidth: CGFloat {
		FloatingPanel.width(forContainerWidth: containerSize.width, fold: foldFrame)
	}

	private var usesFloatingPanel: Bool {
		horizontalSizeClass == .regular || verticalSizeClass == .compact
	}

	/// Lets the sheet settle at its new detent before the map re-frames, so the
	/// two motions read as one settle instead of fighting each other on curves
	/// that can't be matched. Maps does the same.
	private static let scopeShiftDelay: TimeInterval = 0.5

	/// The map's own curve for a scope change.
	private static let scopeShift: Animation = .spring(duration: 0.5, bounce: 0.15)

	/// Share of the map's height the sheet covers.
	///
	/// Derived from the detent rather than live sheet geometry, so the map
	/// doesn't re-frame on every frame of a drag. `.medium` and `.large` share a
	/// value: at `.large` the map is hidden anyway, so re-framing there would
	/// only cost a big camera move on the way back down.
	private var bottomOcclusionFraction: Double {
		guard !usesFloatingPanel, containerSize.height > 0 else { return 0 }

		let covered =
			sheet.detent == MapSheetModel.peekDetent
			? MapSheetModel.peekHeight
			: containerSize.height / 2
		return covered / containerSize.height
	}

	/// Share of the map's width the floating panel covers.
	private var leadingOcclusionFraction: Double {
		guard usesFloatingPanel, containerSize.width > 0 else { return 0 }

		return (panelWidth + FloatingPanel.margin) / containerSize.width
	}

	var body: some View {
		ZStack(alignment: .topLeading) {
			// Edge to edge, with no safe-area padding: padding would shrink the
			// map itself, and a delayed scope shift would then expose a gap
			// under the sheet. The occlusion is handled in the camera framing.
			ParkingMapView(model: sheet)
				.ignoresSafeArea()

			if usesFloatingPanel {
				SheetStack(model: sheet)
					.floatingPanel(width: panelWidth)
					.transition(.move(edge: .leading).combined(with: .opacity))
			}
		}
		.onGeometryChange(for: CGSize.self) { proxy in
			proxy.size
		} action: { newSize in
			containerSize = newSize
		}
		.onGeometryChange(for: CGRect?.self) { proxy in
			FloatingPanel.activeFold(in: proxy)
		} action: { fold in
			foldFrame = fold
		}
		.animation(.smooth, value: usesFloatingPanel)
		.sheet(
			isPresented: Binding(
				get: { !usesFloatingPanel },
				set: { _ in }  // Persistent: only the layout decides.
			)
		) {
			SheetStack(model: sheet)
				.presentationDetents(
					MapSheetModel.detents,
					selection: $sheet.detent
				)
				.presentationBackgroundInteraction(.enabled(upThrough: .medium))
				.presentationDragIndicator(.visible)
				.interactiveDismissDisabled()
		}
		.onChange(of: sheet.selectedFacilityId) { _, facilityId in
			updateCamera(for: facilityId)
		}
		.onChange(of: sheet.detent) {
			// Let the sheet land first; the map then springs to the new scope.
			shiftScope(after: Self.scopeShiftDelay)
		}
		.onChange(of: usesFloatingPanel) {
			shiftScope(after: 0)
		}
		.onChange(of: containerSize) {
			shiftScope(after: 0)
		}
		.onChange(of: deepLinkMgr.selectedFacilityId, initial: true) {
			_,
			facilityId in
			guard let facilityId else { return }
			handleDeepLink(facilityId: facilityId)
		}
		.task {
			// Initial batch ETA on first appearance if location is already available
			if let location = locationMgr.currentLocation {
				await triggerBatchETA(location: location)
			}
		}
		.onChange(of: facilityDataMgr.staticDataLoadTime) {
			// Facilities have just been seeded: frame the opening overview.
			if sheet.selectedFacilityId == nil { shiftScope(after: 0) }

			// First launch: facilities are seeded after the view appears, so the
			// initial batch above found nothing to calculate.
			if let location = locationMgr.currentLocation {
				batchETATask?.cancel()
				batchETATask = Task {
					await triggerBatchETA(location: location)
				}
			}
		}
		.onChange(of: locationMgr.isLocationAvailable) { _, isAvailable in
			// Location just arrived: close in on what's nearby.
			if sheet.selectedFacilityId == nil { shiftScope(after: 0) }

			if isAvailable, let location = locationMgr.currentLocation {
				batchETATask?.cancel()
				batchETATask = Task {
					await triggerBatchETA(location: location)
				}
			}
		}
		.onChange(of: locationMgr.currentLocation) {
			oldLocation,
			newLocation in
			guard let newLoc = newLocation else { return }

			// Use a larger threshold for ETA recalculation than the 100m location filter.
			// At driving speed, 100m fires every ~5s which overwhelms MKDirections (50 req/min).
			let isSignificantChange: Bool
			if let oldLoc = oldLocation {
				isSignificantChange =
					newLoc.distance(from: oldLoc)
					> batchETADistanceThreshold
			} else {
				isSignificantChange = true
			}

			guard isSignificantChange else { return }

			batchETATask?.cancel()
			batchETATask = Task {
				await triggerBatchETA(location: newLoc)
			}
		}
	}
}

// MARK: - Map camera
extension ContentView {
	private func updateCamera(for facilityId: String?) {
		// Fetch outside the animated transaction: a synchronous main-thread
		// fetch on the animation's first frame drops that frame.
		if let facilityId {
			guard
				let coordinate = fetchFacility(id: facilityId)?.location
					.coordinate
			else { return }  // Unknown id: leave the camera where it is.
			withAnimation(.smooth) {
				sheet.focus(on: coordinate)
			}
		} else {
			let coordinates = overviewCoordinates()
			withAnimation(.smooth) {
				sheet.showAll(fitting: coordinates)
			}
		}
	}

	/// Syncs the occlusion shares and re-frames the camera, optionally once the
	/// sheet has had `delay` seconds to settle. Cancels any pending shift, so
	/// dragging through detents resolves to a single move.
	private func shiftScope(after delay: TimeInterval) {
		scopeShiftTask?.cancel()
		scopeShiftTask = Task {
			if delay > 0 {
				try? await Task.sleep(for: .seconds(delay))
				guard !Task.isCancelled else { return }
			}

			sheet.bottomOcclusionFraction = bottomOcclusionFraction
			sheet.leadingOcclusionFraction = leadingOcclusionFraction

			withAnimation(Self.scopeShift) {
				updateCamera(for: sheet.selectedFacilityId)
			}
		}
	}

	/// What the map frames when nothing is selected: the nearest few facilities
	/// plus the user, or every facility when there's no location to work from.
	private func overviewCoordinates() -> [CLLocationCoordinate2D] {
		let descriptor = FetchDescriptor<ParkingFacility>()
		let facilities = (try? modelContext.fetch(descriptor)) ?? []

		guard let location = locationMgr.currentLocation else {
			return facilities.map(\.location.coordinate)
		}

		let nearest =
			facilities
			.map { facility in
				(
					coordinate: facility.location.coordinate,
					distance: CLLocation(
						latitude: facility.location.latitude,
						longitude: facility.location.longitude
					).distance(from: location)
				)
			}
			.sorted { $0.distance < $1.distance }
			.prefix(MapSheetModel.nearestCount)
			.map(\.coordinate)

		guard !nearest.isEmpty else { return [] }
		return nearest + [location.coordinate]
	}

	private func fetchFacility(id facilityId: String) -> ParkingFacility? {
		var descriptor = FetchDescriptor<ParkingFacility>(
			predicate: #Predicate { $0.facilityId == facilityId }
		)
		descriptor.fetchLimit = 1
		return try? modelContext.fetch(descriptor).first
	}
}

// MARK: - Batch ETA
extension ContentView {
	private func triggerBatchETA(location: CLLocation) async {
		let facilities =
			(try? modelContext.fetch(FetchDescriptor<ParkingFacility>())) ?? []
		guard !facilities.isEmpty else { return }
		await etaMgr.calculateBatchETA(
			from: location.coordinate,
			for: facilities
		)
	}
}

// MARK: - Deep link
extension ContentView {
	private func handleDeepLink(facilityId: String) {
		defer { deepLinkMgr.clearSelection() }

		guard fetchFacility(id: facilityId) != nil else {
			Logger.deeplink.error(
				"⚠️ Deep link: No facility found with ID: \(facilityId)"
			)
			return
		}

		Logger.deeplink.info("✅ Deep link: Showing facility \(facilityId)")
		sheet.select(facilityId)
	}
}

#Preview("With Pinned Facilities") {
	ContentView()
		.modelContainer(.preview(includeSampleData: true, favoriteCount: 3))
		.previewEnvironment()
}

#Preview("Empty State") {
	ContentView()
		.modelContainer(.emptyPreview())
		.previewEnvironment()
}
