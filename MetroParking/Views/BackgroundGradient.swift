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

	@Environment(\.colorScheme) private var scheme

	var width: Int = 3
	var height: Int = 3
	var points: [SIMD2<Float>] {
		return [
			[0.0, 0.0],
			[isAnimating ? 0.4 : 0.9, 0.0],
			[1.0, 0.0],
			[0.0, isAnimating ? 0.2 : 0.3],
			[0.8, isAnimating ? 0.2 : 0.1],
			[1.0, isAnimating ? 0.1 : 0.2],
			[0.0, 1.2],
			[0.5, 1.0],
			[1.0, 1.0],
		]
	}

	var colors: [Color] {

		return [
			scheme == .light ? .cyan : .cyan.mix(with: .black, by: 0.6),
			scheme == .light ? .white.opacity(1.0) :	.white.opacity(0.3),
			scheme == .light ? .white.opacity(0.8) : .white.opacity(0.3),
			.cyan.opacity(0.1),
			.cyan.opacity(0.1),
			.cyan.opacity(0.1),
			.clear,
			.clear,
			.clear,
		]
	}

	var body: some View {
		MeshGradient(
			width: width,
			height: height,
			points: points,
			colors: colors,
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
