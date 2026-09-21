//
//  MapControlCluster.swift
//  MetroParking
//
//  Created by Tom Kwok on 21/9/2026.
//

import MapKit
import SwiftUI

/// The map's controls, placed top-trailing like Maps on iPhone.
///
/// Fixed, and deliberately so. An earlier version rode the bottom sheet and had
/// to work out where the sheet's top edge was; `.medium` is not half the screen
/// on every display — the iPhone Duo's cover screen gives it about 58% — so the
/// controls ended up half-swallowed by the sheet there. Nothing up here needs to
/// know about the sheet at all.
///
/// `scope` ties the compass back to its map, so it can be positioned here
/// instead of at MapKit's own top-trailing corner, where it would collide with
/// the button. `MapUserLocationButton` can't be used the same way: hand-placed
/// it declines to render even with `.mapControlVisibility(.visible)` and
/// location granted, so recentring is our own button.
struct MapControlCluster: View {
	let model: MapSheetModel
	let scope: Namespace.ID

	@Environment(LocationManager.self) private var locationMgr

	/// Bumped on each recentre, purely to drive the haptic.
	@State private var locateCount = 0

	var body: some View {
		VStack(alignment: .trailing, spacing: 8) {
			GlassEffectContainer(spacing: 8) {
				Button(action: locate) {
					Label(.mapControlLocate, systemImage: "location")
						.labelStyle(.iconOnly)
				}
				.buttonStyle(.glass)
				.buttonBorderShape(.circle)
				.controlSize(.large)
				.disabled(locationMgr.isLocationDenied)
				.sensoryFeedback(.selection, trigger: locateCount)
				.accessibilityIdentifier("map-locate-button")
			}

			// Keeps MapKit's own rule: visible once the map has been rotated.
			MapCompass(scope: scope)
		}
		.padding(.trailing, MapSheetModel.controlGap)
		.padding(.top, MapSheetModel.controlGap)
	}

	/// Recentres on the user, reusing the map's one framing path so the sheet's
	/// occlusion is compensated here too.
	private func locate() {
		guard let location = locationMgr.currentLocation else {
			locationMgr.requestLocationPermission()
			return
		}

		locateCount += 1
		withAnimation(.smooth) {
			model.focus(on: location.coordinate)
		}
	}
}

#Preview {
	@Previewable @Namespace var scope

	Color.green.opacity(0.3)
		.overlay(alignment: .topTrailing) {
			MapControlCluster(model: MapSheetModel(), scope: scope)
		}
		.previewEnvironment()
}
