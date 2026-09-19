//
//  BackgroundGradient.swift
//  MetroParking
//
//  Created by Tom Kwok on 6/12/2025.
//

import Foundation
import SwiftUI

struct BackgroundGradient: View {
	/// Whether to animate the gradient. When false, shows static gradient.
	let shouldAnimate: Bool

	/// Internal animation state - only used when shouldAnimate is true
	@State private var animationPhase: Bool = false

	@Environment(\.colorScheme) private var scheme

	private let width: Int = 3
	private let height: Int = 3

	private var animation: Animation {
		.smooth(duration: 10.0).repeatForever(autoreverses: true)
	}

	/// Pre-computed static points for initial state (no animation)
	private static let staticPoints: [SIMD2<Float>] = [
		[0.0, 0.0],
		[0.9, 0.0],
		[1.0, 0.0],
		[0.0, 0.8],
		[0.8, 0.1],
		[1.0, 0.2],
		[0.0, 1.2],
		[0.5, 1.0],
		[1.0, 1.0],
	]

	/// Pre-computed animated points for end state
	private static let animatedPoints: [SIMD2<Float>] = [
		[0.0, 0.0],
		[0.4, 0.0],
		[1.0, 0.0],
		[0.0, 0.2],
		[0.8, 0.2],
		[1.0, 0.1],
		[0.0, 1.2],
		[0.5, 1.0],
		[1.0, 1.0],
	]

	/// Returns the current points based on animation state
	private var currentPoints: [SIMD2<Float>] {
		// When not animating, always use static points
		guard shouldAnimate else {
			return Self.staticPoints
		}
		// When animating, SwiftUI interpolates between these based on animationPhase
		return animationPhase ? Self.animatedPoints : Self.staticPoints
	}

	private var colors: [Color] {
		let isLight = scheme == .light
		return [
			.cyan.opacity(0.4),
			.white.opacity(isLight ? 1.0 : 0.3),
			.white.opacity(isLight ? 0.8 : 0.3),
			.cyan.opacity(0.1),
			.cyan.opacity(0.1),
			.cyan.opacity(0.1),
			.clear,
			.clear,
			.clear,
		]
	}

	init(isAnimating: Bool = false) {
		self.shouldAnimate = isAnimating
	}

	var body: some View {
		MeshGradient(
			width: width,
			height: height,
			points: currentPoints,
			colors: colors,
			smoothsColors: true
		)
		.drawingGroup()  // Offload to Metal for better performance
		.ignoresSafeArea()
		.onAppear {
			// Only start animation if requested
			guard shouldAnimate else { return }
			withAnimation(animation) {
				animationPhase = true
			}
		}
	}
}

#Preview("Static") {
	BackgroundGradient(isAnimating: false)
}

#Preview("Animated") {
	BackgroundGradient(isAnimating: true)
}
