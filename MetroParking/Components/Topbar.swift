//
//  TopbarView.swift
//  MetroParking
//
//  Created by Tom Kwok on 2/7/2025.
//

import SwiftUI

struct TopBar<LeadingContent: View, TrailingContent: View>: View {

  private let leadingContent: () -> LeadingContent
  private let trailingContent: () -> TrailingContent

  private let showBackground: Bool

  init(
    showBackground: Bool = true,
    @ViewBuilder leadingContent: @escaping () -> LeadingContent,
    @ViewBuilder trailingContent: @escaping () -> TrailingContent
  ) {
    self.showBackground = showBackground
    self.leadingContent = leadingContent
    self.trailingContent = trailingContent
  }

  var body: some View {

    /// Leading content
    HStack(alignment: .center) {
      leadingContent()
        .foregroundStyle(.foreground)
      Spacer()
      /// Trailing content (usually 1–2 buttons)

      trailingContent()
    }
    .fontWeight(.semibold)
    .frame(maxWidth: .infinity)
    .padding()
    .background {
      if showBackground {
        Rectangle()
          .fill(.ultraThinMaterial)
      }
    }
    .animation(.smooth(duration: 0.2), value: showBackground)
    /// Divider
    .overlay(
      Group {
        Rectangle()
          .frame(height: 0.5)
          .foregroundStyle(.quaternary)
          //					.safeAreaPadding(.horizontal)
          .ignoresSafeArea()
      },
      alignment: .bottom
    )
  }
}
