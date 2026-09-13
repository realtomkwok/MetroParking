//
//  FloatingPanel.swift
//  MetroParking
//
//  Created by Tom Kwok on 13/9/2026.
//

import SwiftUI

/// Maps-style floating card used instead of a bottom sheet when there is room
/// beside the map: regular width (iPhone Duo inner display, Pro Max landscape)
/// or compact height (iPhone landscape).
enum FloatingPanel {
	static let margin: CGFloat = 12
	static let minWidth: CGFloat = 340
	static let maxWidth: CGFloat = 420

	static func width(forContainerWidth containerWidth: CGFloat) -> CGFloat {
		min(maxWidth, max(minWidth, containerWidth * 0.36))
	}
}

private struct FloatingPanelModifier: ViewModifier {
	let containerWidth: CGFloat

	func body(content: Content) -> some View {
		let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

		content
			.frame(width: FloatingPanel.width(forContainerWidth: containerWidth))
			.frame(maxHeight: .infinity)
			.clipShape(shape)
			.glassEffect(.regular, in: shape)
			// Each edge pads from its own safe-area inset; insets on iPhone Duo are asymmetric.
			.padding(FloatingPanel.margin)
	}
}

extension View {
	func floatingPanel(containerWidth: CGFloat) -> some View {
		modifier(FloatingPanelModifier(containerWidth: containerWidth))
	}
}
