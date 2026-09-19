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

	/// Panel width for a container.
	///
	/// When a vertical fold runs through the container (iPhone Duo, open), the
	/// panel fills the leading pane up to the fold so no content sits on the
	/// hinge, and the map gets the other pane. Otherwise it's a fixed-range card.
	static func width(forContainerWidth containerWidth: CGFloat, fold: CGRect?) -> CGFloat {
		if let fold, fold.height > fold.width {
			let leadingPane = fold.minX - 2 * margin
			if leadingPane >= minWidth {
				return leadingPane
			}
		}
		return min(maxWidth, max(minWidth, containerWidth * 0.36))
	}

	/// The frame of the active fold, if the device reports one.
	/// Reserved regions arrive with the iOS 27.1 SDK.
	nonisolated static func activeFold(in proxy: GeometryProxy) -> CGRect? {
		#if canImport(SwiftUICore, _version: 8.0.85)
			if #available(iOS 27.1, *) {
				return proxy.reservedRegions(kind: .division)
					.first(where: \.isActive)?
					.frame
			}
		#endif
		return nil
	}
}

private struct FloatingPanelModifier: ViewModifier {
	let width: CGFloat

	func body(content: Content) -> some View {
		let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

		content
			.frame(width: width)
			.frame(maxHeight: .infinity)
			.clipShape(shape)
			.glassEffect(.regular, in: shape)
			// Each edge pads from its own safe-area inset; insets on iPhone Duo are asymmetric.
			.padding(FloatingPanel.margin)
	}
}

extension View {
	func floatingPanel(width: CGFloat) -> some View {
		modifier(FloatingPanelModifier(width: width))
	}
}
