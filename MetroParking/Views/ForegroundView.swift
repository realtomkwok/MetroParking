//
//  ForegroundView.swift
//  MetroParking
//
//  Created by Tom Kwok on 2/9/2025.
//

import SwiftUI
import SwiftData

struct ForegroundView: View {
	@ObservedObject var appState = AppStateManager.shared
	@ObservedObject var locationState = LocationManager.shared

	@State private var selectedScreen: ScreenView = .pinned
	@State private var showSettingsSheet: Bool = false
	@State private var detailSheetDetent: PresentationDetent = .medium

	/// Tracking scroll position and dynamically change the background of Topbar
	@State private var isScrolled = false
	@State private var initialPosition: CGFloat?

	@ObservedObject private var facilityManager = FacilityManager.shared

	@Query private var allFacilities: [ParkingFacility]

	var body: some View {
		ScrollView {
			/// Track scroll position with GeometryReader
			GeometryReader { proxy in
				Color.clear
					.onChange(of: proxy.frame(in: .named("scroll")).minY) {
						_,
						newValue in
						// Store initial position on first read
						if initialPosition == nil {
							initialPosition = newValue
						}

						// Show background after scrolling 30 points from initial position
						if let initial = initialPosition {
							isScrolled = newValue < (initial)
						}
					}
			}
			.frame(height: 0)

			LazyVStack(alignment: .leading, pinnedViews: .sectionHeaders) {
				Section {
					selectedScreen.destinationView()
				} header: {
					TopBar(showBackground: isScrolled) {
						/// Menu (select views)
						HStack(alignment: .center) {
							Menu {
								ForEach(ScreenView.allCases) { screen in
									Button(action: {
										selectedScreen = screen
									}) {
										HStack {
											Text(screen.displayName)
											Image(systemName: screen.iconName)
										}
									}
								}
							} label: {
								HStack(alignment: .center) {
									Text(selectedScreen.displayName)
										.font(.title)
										.lineLimit(1)
										.multilineTextAlignment(.leading)
										.tracking(-0.4)
									Image(systemName: "chevron.down")
										.font(.callout)
									Spacer()
								}
								.foregroundStyle(.primary)
							}

						}
					} trailingContent: {
						/// Topbar trailing buttons
						HStack(spacing: 16) {

							Button {
								Task {
									await facilityManager
										.performLoad(forced: true)
								}
							} label: {
								Label("Refresh", systemImage: "arrow.clockwise")
									.fontWeight(.semibold)
									.symbolEffect(
										.rotate.clockwise.byLayer,
										options: .repeat(.continuous),
										isActive: facilityManager.isRefreshing
									)
									.frame(width: 24, height: 24)
									.foregroundStyle(.secondary)
							}
							.frame(width: 36, height: 36)
							.disabled(facilityManager.isRefreshing)
							.buttonBorderShape(.circle)
							.buttonStyle(.bordered)
							.foregroundStyle(.primary)
							.controlSize(.regular)

							Button {
								showSettingsSheet = true
							} label: {
								Label("More", systemImage: "ellipsis")
									.fontWeight(.semibold)
									.symbolEffect(
										.wiggle.byLayer,
										options: .nonRepeating,
										isActive: showSettingsSheet
									)
									.frame(width: 24, height: 24)
									.foregroundStyle(.secondary)
							}
							.frame(width: 36, height: 36)
							.buttonBorderShape(.circle)
							.buttonStyle(.bordered)
							.foregroundStyle(.primary)
							.controlSize(.regular)
						}
					}
				}
			}
		}
		.fontDesign(.rounded)
		.coordinateSpace(name: "scroll")


		.sheet(isPresented: $showSettingsSheet) {
			SettingsView()
				.presentationDetents([.large])
				.presentationDragIndicator(.visible)
				.presentationBackground(.thickMaterial)
		}
	}
}

#Preview("Foreground Sheet") {
	ForegroundView(
		appState: AppStateManager(),
		locationState: LocationManager()
	)
	.modelContainer(PreviewHelper.previewContainer(withSamplePins: false))
}
