//
//  TravelSection.swift
//  MetroParking
//
//  Created by Tom Kwok on 5/12/2025.
//

import MapKit
import SwiftUI

extension DetailSections {
	struct TrafficView: View {

		let selectedFacility: ParkingFacility

		@Environment(LocationManager.self) private var locationMgr

		var body: some View {
			DetailCard(
				labelHeading: String(localized: .facilityDetailSectionTravels),
				labelIcon: "location.circle.fill",
				content: Group {
					if locationMgr.isLocationAvailable {
						TravelInfoContent(
							selectedFacility: selectedFacility
						)
					} else {
						LocationPromptContent()
					}
				}
				.animation(
					.smooth,
					value: locationMgr.isLocationAvailable
				),
				trailingTopContent: EmptyView()
			)
		}

		// MARK: - Location Prompt (no route/etaMgr dependency)

		struct LocationPromptContent: View {
			@Environment(LocationManager.self) private var locationMgr
			@State private var showLocationPermissionAlert: Bool = false

			var body: some View {
				HStack(alignment: .firstTextBaseline) {
					Text(.locationAlertTitle)
						.font(.headline)
						.foregroundStyle(.secondary)

					Spacer()

					Button {
						if locationMgr.isLocationDenied {
							showLocationPermissionAlert = true
						} else {
							locationMgr.requestLocationPermission()
						}
					} label: {
						Label(
							.actionButtonEnable,
							systemImage: "location"
						)
						.font(.subheadline)
						.fontWeight(.semibold)
					}
					.buttonStyle(.glass)
					.buttonBorderShape(.capsule)
					.controlSize(.regular)
					.alert(
						.locationAlertHeadline,
						isPresented: $showLocationPermissionAlert,
						actions: {
							Button(.locationButtonTurnOnInSettings) {
								Task { @MainActor in
									if let settingsURL = URL(
										string: UIApplication
											.openSettingsURLString
									) {
										await UIApplication.shared.open(
											settingsURL
										)
									}
								}
							}
							Button(
								.locationButtonKeepOff,
								role: .cancel
							) {

							}
						},
						message: {
							Text(.locationAlertDescription)
						}
					)
				}
				.transition(.blurReplace)
			}
		}

		// MARK: - Travel Info (no locationMgr dependency)

		struct TravelInfoContent: View {
			let selectedFacility: ParkingFacility
			@Environment(ETAManager.self) private var etaMgr

			var body: some View {
				HStack(alignment: .center) {
					TravelDataDisplay(
						displayTravelTime: selectedFacility.route.map {
							etaMgr.formatETA($0.travelTime)
						} ?? "",
						displayDistance: selectedFacility.route.map {
							etaMgr.formatDistance($0.distance)
						} ?? "",
						etaValue: etaMgr.currentETA ?? 0
					)

					Spacer()

					NavigationMenuView(
						selectedFacility: selectedFacility
					)
				}
				.animation(
					.smooth,
					value: selectedFacility.route?.travelTime
				)
			}
		}

		// MARK: - Travel Data (POD view — String/Double only, memcmp diffing)

		struct TravelDataDisplay: View {
			let displayTravelTime: String
			let displayDistance: String
			let etaValue: Double

			var body: some View {
				VStack(alignment: .leading, spacing: 4) {
					if displayTravelTime.isEmpty {
						Text(.facilityDetailLabelNoData)
							.font(.headline)
							.foregroundStyle(.secondary)
					} else {
						Text(displayTravelTime)
							.foregroundStyle(.primary)
							.font(.title)
							.fontWeight(.semibold)
							.contentTransition(
								.numericText(
									value: etaValue
								)
							)
					}

					if !displayDistance.isEmpty {
						HStack(
							alignment: .firstTextBaseline,
							spacing: 4
						) {
							Text(displayDistance)
								.font(.headline)
							Text(.facilityDetailLabelAway)
								.foregroundStyle(.secondary)
								.font(.callout)
						}
						.foregroundStyle(.primary)
					}
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.transition(.blurReplace)
			}
		}


		struct NavigationMenuView: View {
			let selectedFacility: ParkingFacility

			var body: some View {
				Menu {
					ForEach(MapProvider.allCases, id: \.id) { provider in
						Button(provider.displayText, systemImage: provider.icon) {
							openInMaps(
								selectedFacility.makeMapItem(),
								provider: provider
							)
						}
					}
				} label: {
					Label(
						.actionButtonGo,
						systemImage:
							"arrow.trianglehead.turn.up.right.diamond.fill"
					)
					.fontWeight(.semibold)
					.labelStyle(.titleAndIcon)
				}
				.menuStyle(.button)
				.controlSize(.regular)
				.buttonStyle(.glassProminent)
				.containerShape(.circle)
				.contentTransition(
					.symbolEffect(.replace.magic(fallback: .downUp))
				)
				.transition(.blurReplace)
			}
		}
	}
}
