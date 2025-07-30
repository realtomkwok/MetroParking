//
//  SettingsView.swift
//  MetroParking
//
//  Created by Tom Kwok on 29/7/2025.
//

import SwiftData
import SwiftUI

enum SettingType {
  case navigation(SettingItem, AnyView)
  case toggle(SettingItem, Binding<Bool>)
  case info(SettingItem, String)
}

struct SettingSection {
  let title: String
  let items: [SettingType]
}

struct SettingItem {
  let title: String
  let icon: String
  var iconBg: Color = .secondary
  var description: String?
}

struct SettingsView: View {
  /// Load SwiftData environment
  @Environment(\.modelContext) private var modelContext

  @Environment(\.dismiss) private var dismiss
  @State private var notificationsEnabled = true
  @State private var darkModeEnabled = false

  private var settingSections: [SettingSection] {
    [
      SettingSection(
        title: "",
        items: [
          .navigation(
            SettingItem(
              title: "Favourites",
              icon: "heart.fill",
            ),
            AnyView(FavouritesSettings())
          ),
          .navigation(
            SettingItem(
              title: "Notification",
              icon: "bell.badge.fill",
            ),
            AnyView(NotificationSettings())
          ),
          .navigation(
            SettingItem(
              title: "Live Activities",
              icon: "clock.badge",
            ),
            // TODO: Live Activity
            AnyView(NotificationSettings())
          ),
          .navigation(
            SettingItem(
              title: "Widget",
              icon: "square.grid.2x2.fill",
            ),
            AnyView(NotificationSettings())
          ),
        ]
      ),

      SettingSection(
        title: "About",
        items: [
          .navigation(
            SettingItem(
              title: "FAQ",
              icon: "questionmark",
            ),
            AnyView(NotificationSettings())
          ),
          .navigation(
            SettingItem(
              title: "Tip Jar",
              icon: "app.gift.fill",
            ),
            AnyView(NotificationSettings())
          ),
        ]
      ),

      SettingSection(
        title: "About",
        items: [
          .info(
            SettingItem(
              title: "Version",
              icon: "arrow.down.app.fill"
            ),
            "1.0.0"
          ),
          .info(
            SettingItem(
              title: "Build",
              icon: "numbers.rectangle.fill"
            ),
            "123"
          ),
        ]
      ),
    ]
  }

  var body: some View {
    NavigationStack {
      VStack {
        List {
          ForEach(Array(settingSections.enumerated()), id: \.offset) {
            sectionIndex,
            section in
            Section {
              ForEach(section.items.indices, id: \.self) {
                itemIndex in
                let globalIndex =
                  settingSections.prefix(sectionIndex)
                  .reduce(0) { $0 + $1.items.count }
                  + itemIndex

                SettingRow(
                  item: section.items[itemIndex],
                  globalIndex: globalIndex
                )
              }
            }
          }

          Section {
            VStack(alignment: .center) {
              Text("Hellojdkfjkdfjkdfj")
            }
            .frame(maxWidth: .infinity, alignment: .center)

          }
        }
        .scrollContentBackground(.hidden)
        .listSectionSpacing(24)
        .contentMargins(.top, 16)
        .navigationTitle(
          Text("Settings")
        )
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button {
              dismiss()
            } label: {
              Label("Done", systemImage: "xmark")
                .fontWeight(.semibold)
                .frame(width: 20, height: 20)
                .foregroundStyle(.secondary)
            }
            .frame(width: 36, height: 36)
            .buttonBorderShape(.circle)
            .buttonStyle(.bordered)
            .foregroundStyle(.primary)
            .controlSize(.regular)
          }
        }
      }
    }
  }
}

struct SettingRow: View {
  let item: SettingType
  let globalIndex: Int

  let colours: [Color] = [
    .red, .orange, .yellow, .green, .teal, .blue, .indigo, .purple, .pink,
  ]

  var body: some View {
    switch item {
    case .toggle(let setting, let binding):
      Toggle(setting.title, systemImage: setting.icon, isOn: binding)
    case .navigation(let setting, let destination):
      NavigationLink(
        destination:
          destination
          .navigationTitle(setting.title),
        label: {
          Label {
            Text(setting.title)
          } icon: {
            Image(systemName: setting.icon)
              .font(.system(size: 20))
              .fontWeight(.bold)
              .imageScale(.small)
              .foregroundStyle(.white)
              .background(
                RoundedRectangle(
                  cornerRadius: 8,
                  style: .continuous
                )
                .frame(width: 28, height: 28)
                .foregroundColor(
                  colours[globalIndex % colours.count]
                )
              )
          }
        }
      )
    case .info(let setting, let value):
      HStack {
        Label {
          Text(setting.title)
        } icon: {
          Image(systemName: setting.icon)
            .font(.system(size: 20))
            .fontWeight(.bold)
            .imageScale(.small)
            .foregroundStyle(.white)
            .background(
              RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
              )
              .frame(width: 28, height: 28)
              .foregroundColor(.secondary)
            )
        }
        Spacer()
        Text(value).foregroundColor(.secondary)
      }
    }
  }
}

/// All settings
/// Notifications
struct NotificationSettings: View {

  var body: some View {
    Text("Notification")
  }
}

/// Favourites
struct FavouritesSettings: View {
  @Query(
    filter: #Predicate<ParkingFacility> { facility in
      facility.isFavourite == true
    }) private var favourites: [ParkingFacility]

  var body: some View {
    List {
      ForEach(favourites, id: \.id) { facility in
        Text(facility.displayName)
      }
      .onDelete(perform: unfavouriteFacility)
    }
  }

  private func unfavouriteFacility(at offsets: IndexSet) {
    for index in offsets {
      favourites[index].isFavourite = false
    }
  }
}

#Preview {
  SettingsView()
}
