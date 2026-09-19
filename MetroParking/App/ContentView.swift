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

	/// Space the sheet or panel covers, so the map frames content in what's left visible.
	private var mapOcclusion: (edges: Edge.Set, length: CGFloat) {
		if usesFloatingPanel {
			return (.leading, panelWidth + FloatingPanel.margin)
		}

		// Use detent-derived heights rather than live sheet geometry so the map
		// doesn't re-layout on every frame of a sheet drag.
		let length =
			sheet.detent == MapSheetModel.peekDetent
			? MapSheetModel.peekHeight
			: containerSize.height / 2
		return (.bottom, length)
	}

	var body: some View {
		let occlusion = mapOcclusion

		ZStack(alignment: .topLeading) {
			ParkingMapView(model: sheet)
				.safeAreaPadding(occlusion.edges, occlusion.length)
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
		.onChange(of: usesFloatingPanel) {
			// The visible map area changed; keep the selection framed.
			updateCamera(for: sheet.selectedFacilityId)
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
		withAnimation(.smooth) {
			if let facilityId, let facility = fetchFacility(id: facilityId) {
				sheet.focus(on: facility.location.coordinate)
			} else {
				sheet.showAll()
			}
		}
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
