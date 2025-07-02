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
    Grid {
      GridRow(alignment: .center) {
        /// Leading content
        HStack {
          leadingContent()
            .foregroundStyle(.foreground)
          Spacer()

        }
        .gridColumnAlignment(.leading)
        .gridCellColumns(2)

        /// Trailing content (usually 1–2 buttons)
        trailingContent()
          .gridColumnAlignment(.trailing)
          .gridCellColumns(1)
      }
      //		  .padding(.top)
    }
    .fontWeight(.semibold)
    .frame(height: 56)
    .frame(maxWidth: .infinity)
    .padding()
    .background {
      if showBackground {
        Rectangle()
          .fill(.thinMaterial)
      }
    }
    .animation(.smooth(duration: 0.2), value: showBackground)
  }
}
