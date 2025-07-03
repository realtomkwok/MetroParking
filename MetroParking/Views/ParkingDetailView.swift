//
//  ParkingDetailView.swift
//  MetroParking
//
//  Created by Tom Kwok on 26/6/2025.
//

import MapKit
import SwiftData
import SwiftUI

struct FacilityDetailView: View {

  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  let facility: ParkingFacility
  let onDismiss: () -> Void

  private var occupancyProgress: Double {
    guard facility.totalSpaces > 0 else { return 0 }
    return Double(facility.currentOccupancy) / Double(facility.totalSpaces)
  }

  var body: some View {
    NavigationView {
      ScrollView {
        LazyVStack(alignment: .leading, pinnedViews: .sectionHeaders) {

          Section {
            Button {
              // TODO: Direction Button with ETA
              // TODO: Calling user's navigation app
            } label: {
              HStack(alignment: .center, spacing: 8) {
                Spacer()
                Label("Drive there", systemImage: "car.fill")
                // TODO: Connect ETA from location service
                Spacer()
              }
            }
            .font(.headline)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .labelStyle(.titleAndIcon)
            .controlSize(.extraLarge)
            .padding()

            Grid {
              GridRow {
                // TODO: Current Stauts

                VStack(alignment: .leading) {
                  HStack(alignment: .center) {
                    Label("Capacity", systemImage: "gauge")
                      .font(.headline)
                      .textCase(.uppercase)
                      .foregroundStyle(.secondary)
                  }
                  .padding()

                  Spacer()

                  /// Current available spaces
                  /// TODO: Dynamic position of the number
                  VStack(alignment: .trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                      Text(
                        "\(facility.displayAvailableSpots)"
                      )
                      .font(.system(size: 48))
                      .fontDesign(.rounded)
                      .foregroundStyle(.primary)
                      .contentTransition(
                        .numericText(
                          value: Double(
                            facility
                              .currentAvailableSpots
                          )
                        )
                      )
                      Text("spaces")
                        .foregroundStyle(.secondary)
                    }

                    Gauge(value: occupancyProgress) {
                      Label("Value", systemImage: "car")
                    }
                    .gaugeStyle(.accessoryLinear)
                    .tint(
                      Gradient(colors: [
                        AvailabilityStatus.available
                          .color,
                        AvailabilityStatus.almostFull
                          .color,
                        AvailabilityStatus.full.color,
                      ])
                    )
                  }
                  .padding()

                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .background(.thickMaterial)
                .clipShape(
                  RoundedRectangle(
                    cornerRadius: 24,
                    style: .continuous
                  )
                )

                VStack(alignment: .leading) {
                  HStack(alignment: .center) {
                    Label("Capacity", systemImage: "gauge")
                      .font(.headline)
                      .textCase(.uppercase)
                      .foregroundStyle(.secondary)
                  }
                  .padding()

                  Spacer()

                  /// Current available spaces
                  /// TODO: Dynamic position of the number
                  VStack(alignment: .trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                      Text(
                        "\(facility.displayAvailableSpots)"
                      )
                      .font(.system(size: 48))
                      .fontDesign(.rounded)
                      .foregroundStyle(.primary)
                      .contentTransition(
                        .numericText(
                          value: Double(
                            facility
                              .currentAvailableSpots
                          )
                        )
                      )
                      Text("spaces")
                        .foregroundStyle(.secondary)
                    }

                    Gauge(value: occupancyProgress) {
                      Label("Value", systemImage: "car")
                    }
                    .gaugeStyle(.accessoryLinear)
                    .tint(
                      Gradient(colors: [
                        AvailabilityStatus.available
                          .color,
                        AvailabilityStatus.almostFull
                          .color,
                        AvailabilityStatus.full.color,
                      ])
                    )
                  }
                  .padding()

                }
                .frame(maxWidth: .infinity, maxHeight: 200)
                .background(.thickMaterial)
                .clipShape(
                  RoundedRectangle(
                    cornerRadius: 24,
                    style: .continuous
                  )
                )

              }

              // TODO: Forecast and trend
              GridRow {
                VStack(alignment: .leading) {
                  HStack(alignment: .center) {
                    Label("Capacity", systemImage: "gauge")
                      .font(.headline)
                      .textCase(.uppercase)
                      .foregroundStyle(.secondary)
                  }
                  .padding()

                  Spacer()

                  /// Current available spaces
                  /// TODO: Dynamic position of the number
                  VStack(alignment: .trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                      Text(
                        "\(facility.displayAvailableSpots)"
                      )
                      .font(.system(size: 48))
                      .fontDesign(.rounded)
                      .foregroundStyle(.primary)
                      .contentTransition(
                        .numericText(
                          value: Double(
                            facility
                              .currentAvailableSpots
                          )
                        )
                      )
                      Text("spaces")
                        .foregroundStyle(.secondary)
                    }

                    Gauge(value: occupancyProgress) {
                      Label("Value", systemImage: "car")
                    }
                    .gaugeStyle(.accessoryLinear)
                    .tint(
                      Gradient(colors: [
                        AvailabilityStatus.available
                          .color,
                        AvailabilityStatus.almostFull
                          .color,
                        AvailabilityStatus.full.color,
                      ])
                    )
                  }
                  .padding()

                }
                .frame(maxWidth: .infinity, maxHeight: 200)
                .background(.thickMaterial)
                .clipShape(
                  RoundedRectangle(
                    cornerRadius: 24,
                    style: .continuous
                  )
                )

                VStack(alignment: .leading) {
                  HStack(alignment: .center) {
                    Label("Capacity", systemImage: "gauge")
                      .font(.headline)
                      .textCase(.uppercase)
                      .foregroundStyle(.secondary)
                  }
                  .padding()

                  Spacer()

                  /// Current available spaces
                  /// TODO: Dynamic position of the number
                  VStack(alignment: .trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                      Text(
                        "\(facility.displayAvailableSpots)"
                      )
                      .font(.system(size: 48))
                      .fontDesign(.rounded)
                      .foregroundStyle(.primary)
                      .contentTransition(
                        .numericText(
                          value: Double(
                            facility
                              .currentAvailableSpots
                          )
                        )
                      )
                      Text("spaces")
                        .foregroundStyle(.secondary)
                    }

                    Gauge(value: occupancyProgress) {
                      Label("Value", systemImage: "car")
                    }
                    .gaugeStyle(.accessoryLinear)
                    .tint(
                      Gradient(colors: [
                        AvailabilityStatus.available
                          .color,
                        AvailabilityStatus.almostFull
                          .color,
                        AvailabilityStatus.full.color,
                      ])
                    )
                  }
                  .padding()

                }
                .frame(maxWidth: .infinity, maxHeight: 200)
                .background(.thickMaterial)
                .clipShape(
                  RoundedRectangle(
                    cornerRadius: 24,
                    style: .continuous
                  )
                )

              }

              // TODO: Look around
              //					LookAroundPreview(scene: <#T##Binding<MKLookAroundScene?>#>)

              // TODO: Stats for nerd (rest of information)
              List {
                Text("1")
              }

            }
            .padding()

            Spacer()
          } header: {
            TopBar {
              HStack(alignment: .center) {
                Text("\(facility.displayName)")
                  .font(.title)
                  .lineLimit(2)
              }
            } trailingContent: {
              HStack(alignment: .center) {
                Button {
                  facility.isFavourite = !facility.isFavourite
                } label: {
                  Label(
                    facility.isFavourite ? "Pinned" : "Pin",
                    systemImage: facility.isFavourite
                      ? "star.fill" : "star"
                  )
                  .frame(width: 24, height: 24)
                  .contentTransition(
                    .symbolEffect(
                      .replace.magic(
                        fallback: .downUp.wholeSymbol
                      ),
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
          }
        }
      }
    }
    .onAppear {
      facility.markAsVisited()
      try? modelContext.save()
    }
  }

}

extension FacilityDetailView {

}

#Preview {
  FacilityDetailView(
    facility: PreviewHelper.fullFacility(),
    onDismiss: {
      print("Should close this view")
    }
  )
}
