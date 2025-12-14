//
//  Backports.swift
//  MetroParking
//
//  Created by Tom Kwok on 14/12/2025.
//

import SwiftUIBackports
import SwiftUI

@MainActor
@available(iOS 16, *)
public extension Backport where Content: View {

	@ViewBuilder func concentricClipShape() -> some View {
		if #available(iOS 26.0, *) {
			content
				.clipShape(.rect(corners: .concentric, isUniform: true))
		} else {
			content
				.clipShape(.rect(cornerRadius: 24, style: .circular))
		}
	}

	@ViewBuilder func labelIconToTitle(_ value: CGFloat) -> some View {
		if #available(iOS 26.0, *) {
			content.labelIconToTitleSpacing(value)
		} else {
			content
		}
	}

	@ViewBuilder func navigationSubtitle(_ subtitle: Text) -> some View {
		if #available(iOS 26.0, *) {
			content.navigationSubtitle(subtitle)
		} else {
			content
		}
	}
}
