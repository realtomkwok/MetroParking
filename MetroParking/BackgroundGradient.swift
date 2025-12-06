//
//  BackgroundGradient.swift
//  MetroParking
//
//  Created by Tom Kwok on 6/12/2025.
//

import Foundation
import SwiftUI

struct BackgroundGradient: View {
	@State private var isAnimating = false

	var body: some View {
		MeshGradient(
			width: 3,
			height: 3,
			points: [
				[0.0, 0.0],
				[0.5, 0.0],
				[1.0, 0.0],
				[0.0, 0.2],
				[isAnimating ? 0.9 : 0.3, isAnimating ? 0.6 : 0.2],
				[1.0, isAnimating ? 0.2 : 0.6],
				[0.0, 1.0],
				[0.5, 1.0],
				[1.0, 1.0],
			],
			colors: [
				.cyan.opacity(isAnimating ? 0.2 : 1.0),
				.cyan,
				.cyan,
				.clear,
				.clear,
				.clear,
				.clear,
				.clear,
				.clear,
			],
			smoothsColors: true
		)
		.edgesIgnoringSafeArea(.all)
		.onAppear {
			withAnimation(
				.smooth(duration: 10.0).repeatForever(autoreverses: true)
			) { isAnimating.toggle() }
		}
	}
}

#Preview {
	BackgroundGradient()
}
