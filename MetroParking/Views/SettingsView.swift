//
//  SettingsView.swift
//  MetroParking
//
//  Created by Tom Kwok on 26/12/2025.
//

import SwiftUI

// MARK: - Settings Main View

struct SettingsView: View {
	@Environment(\.dismiss) private var dismiss

	let version =
		Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
		?? "--"

	let build =
		Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "--"

	var body: some View {
		NavigationStack {
			List {
				Section("Help") {
					SettingsRow(
						"Tips",
						icon: "sparkles",
						action: .navigation { AnyView(Settings_TipsView()) }
					)
					SettingsRow(
						"Report a bug",
						icon: "ladybug",
						action: .navigation { AnyView(EmptyView()) }
					)
				}
				Section("About") {
					SettingsRow(
						"Developer",
						icon: "figure.flexibility",
						action: .externalLink(URL(string: "https://tomkwok.xyz")!)
					) {
						Text("Tom Kwok")
							.foregroundStyle(.foreground)

					}
					SettingsRow(
						"Version",
						icon: "info.circle"
					) {
						Text("\(version) (\(build))")
							.foregroundStyle(.secondary)
					}
				}

				#if DEBUG
					Section("Developer") {
						SettingsRow(
							"API Debug",
							icon: "hammer",
							action: .navigation {
								AnyView(
									APIUsageDebugView()
										.environment(FacilityManager.shared)
								)
							}
						)
						SettingsRow(
							"Background Refresh",
							icon: "arrow.clockwise.circle",
							action: .navigation { AnyView(BackgroundRefreshDebugView()) }
						)
					}
				#endif
			}
//			.navigationTitle("Settings")
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button("Close", systemImage: "xmark") {
						dismiss()
					}
				}
			}
		}
	}
}

// MARK: - Settings Subpage Container

/// A reusable container for settings subpages with consistent styling.
struct SettingsSubpage<Content: View>: View {
	let title: String
	@ViewBuilder let content: Content

	init(_ title: String, @ViewBuilder content: () -> Content) {
		self.title = title
		self.content = content()
	}

	var body: some View {
		content
			.navigationTitle(title)
			.navigationBarTitleDisplayMode(.inline)
	}
}

// MARK: - Settings Row Label Style

/// Consistent label styling for settings rows: blue icon, primary text.
struct SettingsLabelStyle: LabelStyle {
	func makeBody(configuration: LabelStyleConfiguration) -> some View {
		HStack(spacing: 12) {
			configuration.icon
				.foregroundStyle(Color.blue)
			configuration.title
				.foregroundStyle(Color.primary)
		}
	}
}

// MARK: - Unified Settings Row

/// Defines the action type for a settings row.
enum SettingsRowAction {
	/// Navigates to a destination view within the navigation stack.
	case navigation(() -> AnyView)
	/// Opens a URL in an in-app Safari sheet.
	case externalLink(URL)
	/// No action - displays content only.
	case none
}

/// A unified, reusable settings row that handles navigation, external links, and static display.
struct SettingsRow<Accessory: View>: View {
	let title: String
	let subtitle: String?
	let icon: String
	let action: SettingsRowAction
	@ViewBuilder let accessory: Accessory

	@State private var isShowingSafari = false

	/// Creates a settings row with a trailing accessory view.
	init(
		_ title: String,
		subtitle: String? = nil,
		icon: String,
		action: SettingsRowAction = .none,
		@ViewBuilder accessory: () -> Accessory
	) {
		self.title = title
		self.subtitle = subtitle
		self.icon = icon
		self.action = action
		self.accessory = accessory()
	}

	var body: some View {
		Group {
			switch action {
			case .navigation(let destination):
				NavigationLink {
					destination()
				} label: {
					rowLabel
				}

			case .externalLink(let url):
				Button {
					isShowingSafari = true
				} label: {
					HStack {
						rowLabel
						Spacer()
						accessory
					}
				}
				.sheet(isPresented: $isShowingSafari) {
					SafariView(url: url)
				}

			case .none:
				LabeledContent {
					accessory
				} label: {
					labelContent
				}
			}
		}
	}

	/// The row label used for navigation and external link actions.
	private var rowLabel: some View {
		LabeledContent {
			if case .navigation = action {
				accessory
			}
		} label: {
			labelContent
		}
	}

	/// The label content (icon + title + optional subtitle).
	private var labelContent: some View {
		HStack {
			Label(title, systemImage: icon)
				.labelStyle(SettingsLabelStyle())
			if let subtitle, !subtitle.isEmpty {
				Text(subtitle)
					.foregroundStyle(.secondary)
			}
		}
	}
}

/// Convenience initialiser for rows without accessory content.
extension SettingsRow where Accessory == EmptyView {
	init(
		_ title: String,
		subtitle: String? = nil,
		icon: String,
		action: SettingsRowAction = .none
	) {
		self.init(title, subtitle: subtitle, icon: icon, action: action) {
			EmptyView()
		}
	}
}

// MARK: - Tips Subpage

private struct Settings_TipsView: View {
	var body: some View {
		SettingsSubpage("Tips") {
			List {
				Section("Navigation") {
					Label(
						"Swipe right to pin a car park",
						systemImage: "arrow.right.to.line"
					)
					.contentTransition(
						.symbolEffect(
							.replace.magic(fallback: .downUp.byLayer),
							options: .repeat(.periodic(delay: 3.0))
						)
					)
					Label(
						"Swipe left to get direction to a car park",
						systemImage: "arrow.left.to.line"
					)
					Label(
						"Swipe down to refresh the list",
						systemImage: "arrow.clockwise"
					)
				}
				// Add more tips as needed
			}
		}
	}
}

// MARK: - Previews

#Preview("Settings") {
	SettingsView()
}

#Preview("Tips") {
	NavigationStack {
		Settings_TipsView()
	}
}
