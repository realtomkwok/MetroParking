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
	case webLink(SettingItem, URL)
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

	@State private var showingWebView = false
	@State private var webViewUrl: URL?

	private var settingSections: [SettingSection] {
		[
			SettingSection(
				title: "General",
				items: [
					.navigation(
						SettingItem(
							title: "Pinned Parking",
							icon: "star.fill",
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
						AnyView(LiveActivitiesSettings())
					),
					.navigation(
						SettingItem(
							title: "Widgets",
							icon: "square.grid.2x2.fill",
						),
						AnyView(WidgetSettings())
					),
				]
			),

			SettingSection(
				title: "Advanced",
				items: [
					.navigation(
						SettingItem(
							title: "Advanced",
							icon: "gearshape.2.fill"
						),
						AnyView(AdvancedSettings())
					)
				]
			),

			SettingSection(
				title: "Support & Legal",
				items: [
					.navigation(
						SettingItem(
							title: "Tips",
							icon: "lightbulb.fill",
						),
						AnyView(TipsSettings())
					),
					.webLink(
						SettingItem(
							title: "Legal",
							icon: "info.circle.text.page.fill",
						),
						URL.safe("https://tomkwok.xyz")
					),
					.webLink(
						SettingItem(
							title: "Privacy Policy",
							icon: "shield.lefthalf.filled",
						),
						URL.safe("https://tomkwok.xyz")
					),
				]
			),

			SettingSection(
				title: "About",
				items: [
					.navigation(
						SettingItem(
							title: "About Developer",
							icon: "hand.wave.fill"
						),
						AnyView(AboutDeveloperView())
					)
				]
			),

			SettingSection(
				title: "Version",
				items: [
					.info(
						SettingItem(
							title: "Version",
							icon: "arrow.down.app.fill"
						),
						Bundle.main.infoDictionary?[
							"CFBundleShortVersionString"
						] as? String ?? "--"
					),
					.info(
						SettingItem(
							title: "Build",
							icon: "numbers.rectangle.fill"
						),
						Bundle.main.infoDictionary?["CFBundleVersion"]
							as? String ?? "--"
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
									globalIndex: globalIndex,
									onWebLinkTap: { url in
										webViewUrl = url
										showingWebView = true
									}
								)
							}
						}
					}

					Section {

					} footer: {
						Footer()
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
				.sheet(isPresented: $showingWebView) {
					if let url = webViewUrl {
						SafariView(url: url)
					}
				}
			}
		}
	}
}

struct SettingRow: View {
	let item: SettingType
	let globalIndex: Int
	let onWebLinkTap: ((URL) -> Void)?

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
		case .webLink(let setting, let url):
			Button(action: {
				onWebLinkTap?(url)
			}) {
				Label {
					Text(setting.title)
						.foregroundStyle(.primary)
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
			.foregroundStyle(.primary)
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

/// Pinned Parking
struct FavouritesSettings: View {
	@Query(
		filter: #Predicate<ParkingFacility> { facility in
			facility.isFavourite == true
		}

	) private var favourites: [ParkingFacility]

	var body: some View {
		List {
			ForEach(favourites, id: \.id) { facility in
				Text(facility.displayName)
			}
			.onDelete(perform: unfavouriteFacility)
		}
		.toolbar {
			EditButton()
		}
	}

	private func unfavouriteFacility(at offsets: IndexSet) {
		for index in offsets {
			favourites[index].isFavourite = false
		}
	}
}

/// Live Activities
struct LiveActivitiesSettings: View {

	var body: some View {
		Text("Live Activities")
	}
}

/// Widgets
struct WidgetSettings: View {

	var body: some View {
		Text("Widget")
	}
}

/// FAQ
struct FaqView: View {
	var body: some View {
		Text("Faq")
	}
}

/// Premium
struct AdvancedSettings: View {
	var body: some View {
		Text("Premium")
	}
}

/// Developer
struct AboutDeveloperView: View {

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Image(systemName: "info.bubble.fill")
				.font(.title)
				.symbolRenderingMode(.palette)
				.foregroundStyle(Color.white, Color.secondary)
			Text(
				"Car park data provided by NSW Government through Transport for NSW Open Data Program. We acknowledge the NSW Government's commitment to making transport data freely available to support innovation and improve customer experiences."
			)
			.font(.footnote)
			.foregroundStyle(.secondary)
		}
	}
}

struct TipsSettings: View {
	
	var body: some View {
		Text("Tips")
	}
}

struct Footer: View {
	@State private var showingApiSite = false

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text(
				"Car park data provided by NSW Government through Transport for NSW Open Data Program. We acknowledge the NSW Government's commitment to making transport data freely available to support innovation and improve customer experiences."
			)
			.font(.footnote)
			Button {
				showingApiSite = true
			} label: {
				HStack {
					Image(systemName: "arrow.up.right.square.fill")
					Text("Car Park API")
				}
			}
			.controlSize(.mini)
			.buttonBorderShape(.automatic)
			.sheet(isPresented: $showingApiSite) {
				SafariView(
					url: URL(
						string:
							"https://data.nsw.gov.au/data/dataset/2-car-park-api"
					)!
				)
			}
		}
	}
}

#Preview {
	SettingsView()
}
