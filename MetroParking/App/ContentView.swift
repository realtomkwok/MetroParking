//
//  ContentView.swift
//  MetroParking
//
//  Created by Tom Kwok on 18/5/2025.
//

import MapKit
import SwiftData
import SwiftUI

/// Root view: a full-screen map with the browse/detail stack layered on top.
///
/// - Compact width: a persistent bottom sheet with detents, like Maps on iPhone.
/// - Regular width or compact height (iPhone Duo inner display, landscape):
///   a floating panel beside the map. Layout is driven by size class only,
///   never by device or orientation.
///
/// The sheet's only say over the map is the camera scope, which follows the
/// *detent* via `MapSheetModel.framed(_:)` — never live sheet geometry, which
/// would make the map chase the finger. `MapControlCluster` sits at a fixed
/// top-trailing position and is independent of the sheet entirely.
///
/// MapKit's own attribution and legal link stay at the bottom of the map and so
/// end up behind the sheet. Measured on 2026-09-21: a `safeAreaInset` on the map
/// does reach its safe area but MapKit places attribution against the *frame*
/// and ignores it, and shrinking the frame to move it re-opens the white gap
/// this layout exists to avoid. Neither is worth the trade.
struct ContentView: View {
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	@Environment(\.verticalSizeClass) private var verticalSizeClass

	@Environment(\.modelContext) private var modelContext
	@Environment(LocationManager.self) private var locationMgr
	@Environment(FacilityManager.self) private var facilityDataMgr

	@State private var sheet = MapSheetModel()
	/// Ties the map to the controls `MapControlCluster` places for it.
	@Namespace private var mapScope
	/// Active fold on a foldable (iOS 27.1+), in this view's coordinates.
	@State private var foldFrame: CGRect?
	@State private var scopeShiftTask: Task<Void, Never>?
	/// The safe area: what the floating panel and the controls are laid out in.
	@State private var containerSize: CGSize = .zero
	/// What lies beyond it — status bar, home indicator, landscape notch.
	///
	/// Read off the map, which ignores the safe area and so is the only layer
	/// here that still knows the insets. `containerSize` plus these is the
	/// screen, which is what the detents and the camera are shares of.
	@State private var safeAreaInsets = EdgeInsets()

	/// Lets the sheet settle at its new detent before the map re-frames, so the
	/// two motions read as one settle instead of fighting each other on curves
	/// that can't be matched. Maps does the same.
	private static let scopeShiftDelay: TimeInterval = 0.5

	/// The map's own curve for a scope change.
	private static let scopeShift: Animation = .spring(duration: 0.5, bounce: 0.15)

	private var panelWidth: CGFloat {
		FloatingPanel.width(forContainerWidth: containerSize.width, fold: foldFrame)
	}

	private var usesFloatingPanel: Bool {
		horizontalSizeClass == .regular || verticalSizeClass == .compact
	}

	/// The map spans this, not the safe-area box, and so do the detents.
	private var screenHeight: Double {
		Double(containerSize.height) + safeAreaInsets.top + safeAreaInsets.bottom
	}

	private var screenWidth: Double {
		Double(containerSize.width) + safeAreaInsets.leading
			+ safeAreaInsets.trailing
	}

	/// Points of the map's height the sheet covers.
	///
	/// Derived from the detent rather than live sheet geometry, so the map
	/// doesn't re-frame on every frame of a drag. `.medium` and `.large` share a
	/// value: at `.large` the map is hidden anyway, so re-framing there would
	/// only cost a big camera move on the way back down.
	private var sheetCover: Double {
		guard !usesFloatingPanel, screenHeight > 0 else { return 0 }

		// `.medium` is *about* half the screen — UIKit trims it on some
		// displays (the iPhone Duo's cover screen gives ~58%). Good enough
		// for framing, where a few percent is invisible; never good enough
		// to place a control against, which is why none are placed here.
		return sheet.detent == MapSheetModel.peekDetent
			? Double(MapSheetModel.peekHeight)
			: screenHeight / 2
	}

	/// Share of the map's height the sheet covers.
	private var bottomOcclusionFraction: Double {
		guard screenHeight > 0 else { return 0 }
		return sheetCover / screenHeight
	}

	/// Share of the map's width the floating panel covers.
	///
	/// The panel is laid out inside the safe area, so on a notched device in
	/// landscape it hides that inset as well as its own width and margin.
	private var leadingOcclusionFraction: Double {
		guard usesFloatingPanel, screenWidth > 0 else { return 0 }

		let covered =
			safeAreaInsets.leading + Double(panelWidth) + FloatingPanel.margin
		return covered / screenWidth
	}

	var body: some View {
		ZStack(alignment: .topLeading) {
			// Edge to edge, with no safe-area padding: padding would shrink the
			// map itself, and a delayed scope shift would then expose a gap
			// under the sheet. The occlusion is handled in the camera framing.
			ParkingMapView(model: sheet, scope: mapScope)
				.ignoresSafeArea()
				// The only proxy here that still reports the insets: every layer
				// above sits inside the safe area and so sees zero.
				.onGeometryChange(for: EdgeInsets.self) { proxy in
					proxy.safeAreaInsets
				} action: { insets in
					safeAreaInsets = insets
				}

			// Grouped so the animation covers the panel's insertion and removal
			// without also wrapping the map's container.
			Group {
				if usesFloatingPanel {
					SheetStack(model: sheet)
						.floatingPanel(width: panelWidth)
						.transition(
							.move(edge: .leading).combined(with: .opacity)
						)
				}
			}
			.animation(.smooth, value: usesFloatingPanel)
		}
		// On the ZStack, not the map: this layer carries the device's safe area,
		// so the controls clear the status bar, Dynamic Island and landscape
		// notch on every device without any of it being measured here.
		.overlay(alignment: .bottomTrailing) {
			MapControlCluster(model: sheet, scope: mapScope)
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
		.sheet(
			// Persistent: only the layout decides whether it is up.
			isPresented: .constant(!usesFloatingPanel)
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
		.onChange(of: facilityDataMgr.staticDataLoadTime) {
			frameOpeningOverview()
		}
		.onChange(of: locationMgr.isLocationAvailable) {
			frameOpeningOverview()
		}
		.schedulesBatchETA()
		.deepLinkSelection(into: sheet)
	}

	/// Facilities have been seeded, or location has arrived. Either one changes
	/// what the map should be framing — but only while nothing is selected.
	private func frameOpeningOverview() {
		guard sheet.selectedFacilityId == nil else { return }
		shiftScope(after: 0)
	}
}

// MARK: - Map camera
extension ContentView {
	private func updateCamera(for facilityId: String?) {
		// Fetch outside the animated transaction: a synchronous main-thread
		// fetch on the animation's first frame drops that frame.
		if let facilityId {
			guard
				let coordinate = modelContext.facility(id: facilityId)?.location
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
		let facilities = modelContext.allFacilities()

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
}

// MARK: - Previews

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
