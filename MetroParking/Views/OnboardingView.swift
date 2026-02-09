//
//  OnboardingView.swift
//  MetroParking
//
//  Created by Tom Kwok on 26/12/2025.
//

import SwiftUI

/// Single-page onboarding view displayed on first app launch
/// Provides a welcome message and overview of key features
@available(iOS 26.0, *)
struct OnboardingView: View {
	@Environment(OnboardingManager.self) private var onboardingManager
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		VStack(spacing: 0) {
			// Content
			ScrollView(.vertical) {
				VStack(alignment: .leading, spacing: 16) {
					Spacer(minLength: 32)

					// App Icon & Title
					VStack(alignment: .leading, spacing: 16) {

						Image("Icon")
							.resizable()
							.frame(width: 128, height: 128)
							.aspectRatio(contentMode: .fit)
							.shadow(radius: 64)
							.accessibilityHidden(true)


						Text(.onboardingTitleWelcome)
							.font(.largeTitle)
							.fontWeight(.bold)

						Text(.onboardingMessageHeadline
						)
						.font(.body)
						.foregroundStyle(.secondary)
					}
					.padding(8)

					Spacer(minLength: 8)

					// Feature Highlights
					VStack(alignment: .leading, spacing: 16) {
						FeatureRow(
							order: 0,
							icon: "gauge.open.with.lines.needle.33percent",
							title: "Info at a Glance",
							description:
								"A glanceable overview of car park availability, location and more."
						)
						FeatureRow(
							order: 1,
							icon: "star.square.on.square.fill",
							title: "Pin Your Favourite",
							description:
								"Quick access to frequently used car parks on the top of the list."
						)

						FeatureRow(
							order: 2,
							icon: "square.grid.2x2.fill",
							title: "Live Widgets",
							description:
								"Quick look on the car park's availability on your home screen."
						)
					}

					Spacer(minLength: 32)
				}
				.padding(.horizontal, 24)
			}
			.safeAreaBar(edge: .bottom, alignment: .center) {
					// Get Started Button
				Button {
					onboardingManager.completeOnboarding()
					dismiss()
				} label: {
					Text(.onboardingButtonGetStarted)
						.font(.headline)
						.foregroundStyle(.white)
						.frame(maxWidth: .infinity)
						.padding()
						.background(Color.accentColor)
				}
				.accessibilityIdentifier("get-started-button")
				.buttonStyle(.glassProminent)
				.padding()
			}
			.scrollEdgeEffectStyle(.soft, for: .vertical)
		}
		.background {
			BackgroundGradient(isAnimating: true)
		}
		.interactiveDismissDisabled()
		.accessibilityIdentifier("onboarding-view")
	}
}

/// Reusable feature row component for onboarding
@available(iOS 26.0, *)
struct FeatureRow: View {
	let order: Int
	let icon: String
	let title: String
	let description: String

	var body: some View {
		HStack(alignment: .top, spacing: 24) {
			Image(systemName: icon)
				.font(.title)
				.foregroundStyle(Color.accentColor)
				.frame(width: 40)

			VStack(alignment: .leading, spacing: 4) {
				Text(title)
					.font(.headline)
				Text(description)
					.font(.subheadline)
					.foregroundStyle(.secondary)
					.lineLimit(2)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}

// MARK: - Previews

@available(iOS 26.0, *)
#Preview("Onboarding") {
	OnboardingView()
		.environment(OnboardingManager.shared)
}
