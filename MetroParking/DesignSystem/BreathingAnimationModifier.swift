//
//  BreathingAnimationModifier.swift
//  MetroParking
//
//  Created by Tom Kwok on 10/1/2026.
//

import SwiftUI

/// A view modifier that applies a breathing animation effect by pulsing the opacity.
struct BreathingAnimationModifier: ViewModifier {
	let isAnimating: Bool
	let minOpacity: Double
	let duration: Double

	init(
		isAnimating: Bool,
		minOpacity: Double = 0.5,
		duration: Double = 0.8
	) {
		self.isAnimating = isAnimating
		self.minOpacity = minOpacity
		self.duration = duration
	}

	func body(content: Content) -> some View {
		content
			.phaseAnimator(
				isAnimating ? [1.0, minOpacity] : [1.0],
				trigger: isAnimating
			) { content, phase in
				content.opacity(phase)
			} animation: { _ in
				isAnimating
					? .easeInOut(duration: duration).repeatCount(
						Int.max,
						autoreverses: true
					)
					: .default
			}
	}
}

extension View {
	/// Applies a breathing animation effect to the view.
	///
	/// - Parameters:
	///   - isAnimating: Whether the breathing animation should be active.
	///   - minOpacity: The minimum opacity value during the animation. Defaults to 0.5.
	///   - duration: The duration of one breathing cycle. Defaults to 0.8 seconds.
	/// - Returns: A view with the breathing animation applied.
	func breathingAnimation(
		_ isAnimating: Bool,
		minOpacity: Double = 0.5,
		duration: Double = 0.8
	) -> some View {
		modifier(
			BreathingAnimationModifier(
				isAnimating: isAnimating,
				minOpacity: minOpacity,
				duration: duration
			)
		)
	}
}
