//
//  BackgroundView.swift
//  MetroParking
//
//  Created by Tom Kwok on 2/9/2025.
//

import MapKit
import OSLog
import SwiftData
import SwiftUI

struct BackgroundView: View {
	@ObservedObject var appState = AppStateManager.shared
	@ObservedObject var locationState = LocationManager.shared
	@ObservedObject var mapCamera = MapCameraManager.shared

	@Query var allFacilities: [ParkingFacility]
	@State private var showLocationPermissionAlert = false
	@State private var showLocationSettingsAlert = false

	var body: some View {
		GeometryReader { geometry in
			Map(
				position: $mapCamera.cameraPosition
			) {
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
			.onReceive(appState.$currentSheetDetent) { detent in
				Task { @MainActor in
					try? await Task.sleep(for: .milliseconds(50))
					mapCamera.updateSheetHeight(for: detent, geometry.size.height)
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
			}
		}
		// TODO: Get current user location
//		.overlay(alignment: .trailing) {
//			VStack {
//				Button {
//					switch locationState.authorisationStatus {
//					case .notDetermined, .restricted, .denied:
//						showLocationPermissionAlert = true
//					case .authorizedAlways, .authorizedWhenInUse:
//						guard
//							let currentLocation = locationState.currentLocation
//						else {
//							Logger.location.warning("No location available")
//							return
//						}
//
//							let nearbyFacilities = allFacilities.sorted {
//								$0.lastCalculatedDistance! < $1.lastCalculatedDistance!
//							}
//
//							appState
//								.selectFacilityWithContext(
//									currentLocation.coordinate,
//									nearby: nearbyFacilities
//								)
//
//						mapCamera
//							.updateCameraPosition(
//								trueCentre: currentLocation.coordinate
//							)
//
//					@unknown default:
//						showLocationPermissionAlert = true
//					}
//				} label: {
//					VStack(alignment: .center, spacing: 8) {
//						if locationState.isRefreshing {
//							ProgressView()
//						} else {
//							Label(
//								"Current Location",
//								systemImage: locationState.isLocationAvailable
//									? "location.fill" : "location"
//							)
//							.font(.headline)
//							.frame(width: 40, height: 40)
//							.background(.regularMaterial, in: Circle())
//							.padding(.trailing)
//							.contentTransition(
//								.symbolEffect(.replace, options: .default)
//							)
//							.labelStyle(.iconOnly)
//						}
//					}
//				}
//				.sheet(isPresented: $showLocationPermissionAlert) {
//					PermissionView()
//						.presentationDetents([.medium])
//						.presentationBackgroundInteraction(.disabled)
//				}
//				Spacer()
//			}
//		}
	}
}
