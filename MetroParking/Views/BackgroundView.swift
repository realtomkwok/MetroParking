//
//  BackgroundView.swift
//  MetroParking
//
//  Created by Tom Kwok on 2/9/2025.
//

import SwiftUI
import SwiftData
import MapKit

struct BackgroundView: View {
	@ObservedObject var appState: AppStateManager
	@ObservedObject var locationState: LocationManager

	@Query var allFacilities: [ParkingFacility]
	@State private var showLocationPermissionAlert = false
	@State private var showLocationSettingsAlert = false

	var body: some View {
		VStack {
			Map(
				position: $appState.cameraPosition
			) {
				UserAnnotation()

				ForEach(allFacilities, id: \.facilityId) { facility in

					Annotation(
						facility.displayName,
						coordinate: CLLocationCoordinate2D(
							latitude: facility.latitude,
							longitude: facility.longitude
						)
					) {
						ParkingMapAnnotation(
							facility: facility,
							isSelected: appState.selectedFacility?.facilityId
								== facility.facilityId
						)
						.onTapGesture {
							appState.selectFacility(facility)
						}
					}

				}
			}
			.mapStyle(
				.standard(
					elevation: .realistic,
					emphasis: .muted,
					pointsOfInterest: [.publicTransport],
					showsTraffic: false
				)
			)
			.mapControls {
				MapScaleView()
				MapCompass()
			}
		}
		.overlay(alignment: .trailing) {
			VStack {
				Button {
					switch locationState.authorisationStatus {
					case .notDetermined, .restricted, .denied:
						showLocationPermissionAlert = true
					case .authorizedAlways, .authorizedWhenInUse:

						let newRegion =
							MapCameraHelper.getNearestFacilitiesRegion(
								facilities: allFacilities,
								count: 5,
							)

						withAnimation(.snappy(duration: 1.5)) {
							appState.cameraPosition = .region(newRegion)
						}

					@unknown default:
						showLocationPermissionAlert = true
					}
				} label: {
					VStack(alignment: .center, spacing: 8) {
						if locationState.isRefreshing {
							ProgressView()
						} else {
							Label(
								"Current Location",
								systemImage: locationState.isLocationAvailable
									? "location.fill" : "location"
							)
							.font(.headline)
							.frame(width: 40, height: 40)
							.background(.regularMaterial, in: Circle())
							.padding(.trailing)
							.contentTransition(
								.symbolEffect(.replace, options: .default)
							)
							.labelStyle(.iconOnly)
						}
					}
				}
				.sheet(isPresented: $showLocationPermissionAlert) {
					PermissionView()
						.presentationDetents([.medium])
						.presentationBackgroundInteraction(.disabled)

				}
				Spacer()
			}
		}
	}
}
