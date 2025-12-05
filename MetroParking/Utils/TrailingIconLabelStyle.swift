//
//  TrailingIconLabelStyle.swift
//  MetroParking
//
//  Created by Tom Kwok on 5/12/2025.
//

import SwiftUI
import Foundation

struct TrailingIconLabelStyle: LabelStyle {
	func makeBody(configuration: LabelStyleConfiguration) -> some View {
		HStack {
			configuration.title
			Spacer()
			configuration.icon
		}
	}
}
