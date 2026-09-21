//
//  LookAroundSection.swift
//  MetroParking
//
//  Created by Tom Kwok on 5/12/2025.
//

import MapKit
import SwiftUI

extension DetailSections {

	struct LookAroundView: View {
		let loader: LookAroundLoader

		@ViewBuilder
		func loadingView() -> some View {
			VStack(spacing: 12) {
				ProgressView()
					.controlSize(.large)
			}
			.frame(maxWidth: .infinity)
		}

		@ViewBuilder
		func errorView(errorMsg: String) -> some View {
			Text(errorMsg)
				.font(.headline)
				.foregroundStyle(.secondary)
		}

		@ViewBuilder
		func lookAroundView(_ scene: MKLookAroundScene) -> some View {
			LookAroundPreview(initialScene: scene)
				.frame(height: 200)
				.clipShape(.containerRelative)
				.transition(.blurReplace)
				.glassEffect(
					.clear,
					in: .rect(corners: .concentric, isUniform: true)
				)
				.zIndex(0)
		}

		let labelHeading: String = "Look Around"
		let labelIcon: String = "binoculars.circle.fill"

		var body: some View {
			ZStack {
				switch loader.phase {
				case .idle:
					EmptyView()
				case .loading:
					DetailCard(
						labelHeading: labelHeading,
						labelIcon: labelIcon,
						content: loadingView(),
						trailingTopContent: EmptyView()
					)
					.transition(.blurReplace)
					.zIndex(1)
				case .unavailable(let message):
					DetailCard(
						labelHeading: labelHeading,
						labelIcon: labelIcon,
						content: errorView(errorMsg: message),
						trailingTopContent: EmptyView()
					)
				case .loaded(let scene):
					lookAroundView(scene)
				}
			}
			.clipShape(.containerRelative)
			.animation(.smooth, value: loader.isLoading)
		}
	}
}
