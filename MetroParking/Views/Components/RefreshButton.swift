//
//  RefreshButton.swift
//  MetroParking
//
//  Created by Tom Kwok on 1/2/2026.
//

import SwiftUI

@ViewBuilder
func RefreshButton(
	action: @escaping () async -> Void,
	isActive: Bool,
	isDisabled: Bool
) -> some View {
	Button {
		Task {
			await action()
		}
	} label: {
		Label("Refresh", systemImage: "arrow.clockwise")
			.symbolEffect(
				.rotate.clockwise.byLayer,
				options: .repeat(.periodic(delay: 0.3)),
				isActive: isActive
			)
	}
	.disabled(isDisabled)
	.accessibilityLabel("Refresh")
}
