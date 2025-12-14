//
//  PermissionView.swift
//  MetroParking
//
//  Created by Tom Kwok on 31/7/2025.
//

import OSLog
import SwiftUI
import SwiftUIBackports

struct PermissionView: View {
	@Environment(\.dismiss) private var dismiss
	@Environment(
		LocationManager.self
	) private var locationManager

	@State private var isIconAnimating = true


	var body: some View {
		NavigationStack {
			VStack {
				VStack(alignment: .leading, spacing: 24) {
					Image(systemName: iconName)
						.font(.system(size: 60))
						.frame(width: 60, height: 60)
						.foregroundStyle(iconColor.gradient)
						.contentTransition(
							.symbolEffect(
								.replace.magic(fallback: .upUp.byLayer),
								options: .nonRepeating
							)
						)

					VStack(alignment: .leading, spacing: 8) {
						Text(titleText)
							.font(.title2)
							.fontWeight(.semibold)
							.multilineTextAlignment(.leading)

						Text(messageText)
							.font(.body)
							.foregroundStyle(.secondary)
							.multilineTextAlignment(.leading)
					}
				}
				.frame(maxWidth: .infinity, alignment: .leading)

				Spacer()

				Button(action: {
					locationManager.requestLocationPermission()
					Task {
						while locationManager.authorisationStatus
							== .notDetermined
						{
							try? await Task.sleep(nanoseconds: 500_000_000)
						}

						dismiss()
					}
				}) {
					Text(buttonText)
						.fontWeight(.semibold)
						.frame(maxWidth: .infinity)
				}
				.backport
				.glassProminentButtonStyle()
				.buttonBorderShape(.capsule)
				.controlSize(.large)
			}
			.frame(maxWidth: .infinity)

			.padding()
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button {
						dismiss()
					} label: {
						Label("Done", systemImage: "xmark")
							.fontWeight(.semibold)
							.frame(width: 20, height: 20)
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
		.onAppear {
			let animationDelay: UInt64 = 1_500_000_000

			Task {
				// Wait for 1.5 second
				try? await Task.sleep(nanoseconds: animationDelay)  // 1 second in nanoseconds

				// Trigger the animation by changing the state
				withAnimation(.snappy) {
					isIconAnimating = false
				}
			}
		}
	}

	// Dynamic content based on current permission status
	private var iconName: String {
		if isIconAnimating {
			return "location.app.fill"
		}

		switch locationManager.authorisationStatus {
		case .notDetermined:
			return "location.app"
		case .denied, .restricted:
			return "location.slash.fill"
		default:
			return "location.circle"
		}
	}

	private var iconColor: Color {
		switch locationManager.authorisationStatus {
		case .notDetermined:
			return .blue
		case .denied, .restricted:
			return .orange
		default:
			return .blue
		}
	}

	private var titleText: String {
		switch locationManager.authorisationStatus {
		case .notDetermined:
			return "Location Access Required"
		case .denied, .restricted:
			return "Location Access Denied"
		default:
			return "Location Access Granted"
		}
	}

	private var messageText: AttributedString {
		switch locationManager.authorisationStatus {
		case .notDetermined:
			do {
				let string: AttributedString = try AttributedString(
					markdown:
						"To access location-based features, such as estimated travel time and distance, tap **Allow Location Access** below to grant the permission."
				)

				return string
			} catch {
				Logger.ui.error("Failed to parse AttributedString")
				return AttributedString("")
			}
		case .denied, .restricted:
				do {
					let string: AttributedString = try AttributedString(
						markdown:
							"To access location-based features, such as estimated travel time and distance, tap **Open Settings** below to grant the permission."
					)

					return string
				} catch {
					Logger.ui.error("Failed to parse AttributedString")
					return AttributedString("")
				}

		default:
			return AttributedString(
				"Location access helps improve your experience."
			)
		}
	}

	private var buttonText: String {
		switch locationManager.authorisationStatus {
		case .notDetermined:
			return "Allow Location Access"
		case .denied, .restricted:
			return "Open Settings"
		default:
			return "OK"
		}
	}
}

#Preview {
	PermissionView()
		.modelContainer(.preview())
		.environment(LocationManager.shared)
}
