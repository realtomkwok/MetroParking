//
//  ParkingDetailView.swift
//  MetroParking
//
//  Created by Tom Kwok on 26/6/2025.
//

import SwiftData
import SwiftUI

struct FacilityDetailView: View {
  let facility: ParkingFacility
  let onDismiss: () -> Void

  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationView {
      VStack(alignment: .leading, spacing: 16) {
        Topbar()

        VStack(alignment: .leading) {
          Text("\(facility.suburb), \(facility.address)")
            .font(.subheadline)
            .foregroundColor(.secondary)

          Text("Total Spaces: \(facility.totalSpaces)")
            .font(.headline)

          if let lastVisited = facility.lastVisited {
            Text("Last visited: \(lastVisited, format: .dateTime)")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        Spacer()
      }
      .padding()
    }
    .onAppear {
      facility.markAsVisited()
      try? modelContext.save()
    }
  }

  @ViewBuilder
  // TODO: Add the consistent topbar component
  func Topbar() -> some View {
    HStack {
      Text("\(facility.displayName)")
        .font(.title2)
        .multilineTextAlignment(.leading)
      Spacer(minLength: 16)

      HStack(alignment: .center) {
        Button {
          facility.isFavourite = !facility.isFavourite
        } label: {
          Label(
            facility.isFavourite ? "Pinned" : "Pin",
            systemImage: facility.isFavourite ? "star.fill" : "star"
          )
          .frame(width: 24, height: 24)
          .contentTransition(
            .symbolEffect(
              .replace.magic(fallback: .downUp.wholeSymbol),
              options: .nonRepeating
            )
          )
        }

        Button {
          onDismiss()
          dismiss()
        } label: {
          Label("Close", systemImage: "xmark")
            .frame(width: 24, height: 24)
        }
      }
      .buttonStyle(.bordered)
      .buttonBorderShape(.circle)
      .foregroundStyle(.secondary)
    }
    .frame(height: 56)
    .fontWeight(.bold)
  }
}

#Preview {
  FacilityDetailView(
    facility: PreviewHelper.fullFacility(),
    onDismiss: {
      print("Should close this view")
    }
  )
}
