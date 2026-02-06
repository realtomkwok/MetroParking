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
	@Environment(\.openURL) private var openUrl

	let version =
		Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
		?? "--"

	let build =
		Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "--"

	let devEmail = Bundle.main.infoDictionary?["DEV_EMAIL"] as? String ?? ""

	let devWebsite =
		Bundle.main.infoDictionary?["DEV_WEBSITE_URL"] as? String ?? ""

	let testFlightUrl =
		Bundle.main.infoDictionary?["TESTFLIGHT_URL"] as? String ?? ""

	var body: some View {
		NavigationStack {
			List {

				Section(.help) {
					SettingsRow(
						"Tips",
						icon: "sparkles",
						destination: { Settings_TipsView() }
					)
					SettingsRow(
						"Feedback",
						icon: "bubble.left.and.exclamationmark.bubble.right",
						destination: { Settings_FeedbackView() }
					)
				}
				Section {
					SettingsRow(
						"Developer",
						icon: "figure.flexibility",
						externalURL: URL(string: "https://tomkwok.xyz")!
					) {
						Text("Tom Kwok")
							.foregroundStyle(.primary)
					}
					SettingsRow(
						"Version",
						icon: "info.circle",
						accessory: {
							Text("\(version) (\(build))")
								.foregroundStyle(.secondary)
						}
					)
				} header: {
					Text(.about)
				} footer: {
					Text(.settingsFootnote)
				}

				#if DEBUG
					Section("Debug") {
						SettingsRow(
							"API Debug",
							icon: "hammer",
							destination: {
								APIUsageDebugView()
									.environment(FacilityManager.shared)
							}
						)
						SettingsRow(
							"Background Refresh",
							icon: "arrow.clockwise.circle",
							destination: {
								BackgroundRefreshDebugView()
							}
						)
					}
				#endif
			}
			.navigationTitle(.more)
			.toolbarTitleDisplayMode(.large)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button {
						dismiss()
					} label: {
						Label(.close, systemImage: "xmark")
							.labelStyle(.iconOnly)
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

// MARK: - Unified Settings Row

/// Defines the interaction type for a settings row.
enum SettingsRowAction {
	/// Navigates to a destination view within the NavigationStack.
	case navigation
	/// Opens an external URL in Safari (in-app sheet).
	case externalURL(URL)
	/// Opens an external URL using the system handler.
	case systemURL(URL)
	/// Executes a custom action.
	case action(() -> Void)
	/// No interaction (static display only).
	case none
}

/// A unified, reusable settings row that handles navigation, external links, actions, and static display.
///
/// Usage examples:
/// ```swift
/// // Navigation to a destination view
/// SettingsRow("Profile", icon: "person") {
///     ProfileView()
/// }
///
/// // External URL (opens in Safari sheet)
/// SettingsRow("Website", icon: "globe", externalURL: URL(string: "https://example.com")!)
///
/// // System URL (opens via openURL environment)
/// SettingsRow("Email", icon: "envelope", systemURL: URL(string: "mailto:hi@example.com")!)
///
/// // Custom action
/// SettingsRow("Reset", icon: "arrow.counterclockwise", action: { resetSettings() })
///
/// // Static row with accessory
/// SettingsRow("Version", icon: "info.circle") {
///     Text("1.0.0").foregroundStyle(.secondary)
/// }
/// ```
struct SettingsRow<Destination: View, Accessory: View>: View {
	let title: LocalizedStringKey
	let subtitle: LocalizedStringKey?
	let icon: String
	let rowAction: SettingsRowAction
	let destination: Destination?
	@ViewBuilder let accessory: Accessory

	@Environment(\.openURL) private var openURL
	@State private var isShowingSafari = false

	// MARK: - Navigation Initialiser

	/// Creates a settings row with navigation to a destination view.
	init(
		_ title: LocalizedStringKey,
		subtitle: LocalizedStringKey? = nil,
		icon: String,
		@ViewBuilder destination: () -> Destination,
		@ViewBuilder accessory: () -> Accessory
	) {
		self.title = title
		self.subtitle = subtitle
		self.icon = icon
		self.rowAction = .navigation
		self.destination = destination()
		self.accessory = accessory()
	}

	// MARK: - Action-Based Initialisers

	/// Creates a settings row with an external URL (opens in Safari sheet).
	init(
		_ title: LocalizedStringKey,
		subtitle: LocalizedStringKey? = nil,
		icon: String,
		externalURL: URL,
		@ViewBuilder accessory: () -> Accessory
	) where Destination == EmptyView {
		self.title = title
		self.subtitle = subtitle
		self.icon = icon
		self.rowAction = .externalURL(externalURL)
		self.destination = nil
		self.accessory = accessory()
	}

	/// Creates a settings row with a system URL (opens via openURL).
	init(
		_ title: LocalizedStringKey,
		subtitle: LocalizedStringKey? = nil,
		icon: String,
		systemURL: URL,
		@ViewBuilder accessory: () -> Accessory
	) where Destination == EmptyView {
		self.title = title
		self.subtitle = subtitle
		self.icon = icon
		self.rowAction = .systemURL(systemURL)
		self.destination = nil
		self.accessory = accessory()
	}

	/// Creates a settings row with a custom action.
	init(
		_ title: LocalizedStringKey,
		subtitle: LocalizedStringKey? = nil,
		icon: String,
		action: @escaping () -> Void,
		@ViewBuilder accessory: () -> Accessory
	) where Destination == EmptyView {
		self.title = title
		self.subtitle = subtitle
		self.icon = icon
		self.rowAction = .action(action)
		self.destination = nil
		self.accessory = accessory()
	}

	/// Creates a settings row with no interaction (static content only).
	init(
		_ title: LocalizedStringKey,
		subtitle: LocalizedStringKey? = nil,
		icon: String,
		@ViewBuilder accessory: () -> Accessory
	) where Destination == EmptyView {
		self.title = title
		self.subtitle = subtitle
		self.icon = icon
		self.rowAction = .none
		self.destination = nil
		self.accessory = accessory()
	}

	// MARK: - Body

	var body: some View {
		Group {
			switch rowAction {
			case .navigation:
				if let destination {
					NavigationLink {
						destination
					} label: {
						rowContent
					}
				}

			case .externalURL(let url):
				Button {
					isShowingSafari = true
				} label: {
					rowContent
				}
				.sheet(isPresented: $isShowingSafari) {
					SafariView(url: url)
				}

			case .systemURL(let url):
				Button {
					openURL(url)
				} label: {
					rowContent
				}

			case .action(let action):
				Button(action: action) {
					rowContent
				}

			case .none:
				rowContent
			}
		}
	}

	// MARK: - Private Views

	/// The full row content with label and accessory.
	private var rowContent: some View {
		LabeledContent {
			accessory
		} label: {
			Label {
				Text(title)
					.foregroundStyle(Color.primary)
			} icon: {
				Image(systemName: icon)
			}
			if let subtitle {
				Text(subtitle)
					.font(.caption)
					.foregroundStyle(Color.secondary)
			}
		}
	}
}

// MARK: - Convenience Initialisers (No Accessory)

extension SettingsRow where Accessory == EmptyView {
	/// Creates a settings row with navigation and no accessory.
	init(
		_ title: LocalizedStringKey,
		subtitle: LocalizedStringKey? = nil,
		icon: String,
		@ViewBuilder destination: () -> Destination
	) {
		self.init(
			title,
			subtitle: subtitle,
			icon: icon,
			destination: destination
		) {
			EmptyView()
		}
	}

	/// Creates a settings row with an external URL and no accessory.
	init(
		_ title: LocalizedStringKey,
		subtitle: LocalizedStringKey? = nil,
		icon: String,
		externalURL: URL
	) where Destination == EmptyView {
		self.init(
			title,
			subtitle: subtitle,
			icon: icon,
			externalURL: externalURL
		) {
			EmptyView()
		}
	}

	/// Creates a settings row with a system URL and no accessory.
	init(
		_ title: LocalizedStringKey,
		subtitle: LocalizedStringKey? = nil,
		icon: String,
		systemURL: URL
	) where Destination == EmptyView {
		self.init(title, subtitle: subtitle, icon: icon, systemURL: systemURL) {
			EmptyView()
		}
	}

	/// Creates a settings row with a custom action and no accessory.
	init(
		_ title: LocalizedStringKey,
		subtitle: LocalizedStringKey? = nil,
		icon: String,
		action: @escaping () -> Void
	) where Destination == EmptyView {
		self.init(title, subtitle: subtitle, icon: icon, action: action) {
			EmptyView()
		}
	}

	/// Creates a settings row with no interaction and no accessory.
	init(
		_ title: LocalizedStringKey,
		subtitle: LocalizedStringKey? = nil,
		icon: String
	) where Destination == EmptyView {
		self.title = title
		self.subtitle = subtitle
		self.icon = icon
		self.rowAction = .none
		self.destination = nil
		self.accessory = EmptyView()
	}
}

// MARK: - Tips Subpage

@ViewBuilder
private func Settings_TipsView() -> some View {
	SettingsSubpage("Tips") {
		List {
			Section(.navigation) {
				Label(
					.swipeRightToPinACarPark,
					systemImage: "arrow.right.to.line"
				)
				Label(
					.swipeDownToRefreshTheList,
					systemImage: "arrow.clockwise"
				)
			}
			// Add more tips as needed
		}
	}
}

extension SettingsView {
	@ViewBuilder
	private func Settings_FeedbackView() -> some View {
		SettingsSubpage("Feedback") {
			List {
				Section {
					SettingsRow(
						"Report a bug",
						icon: "ladybug",
						systemURL: URL(
							string: testFlightUrl
						)!
					)
					SettingsRow(
						"Request a feature",
						icon: "plus.bubble",
						systemURL: URL(
							string: testFlightUrl
						)!
					)
				}
				Section(.issueNotListed) {
					SettingsRow(
						"Contact Developer",
						subtitle: "via Email",
						icon: "envelope",
						systemURL: URL(string: "mailto:\(devEmail)")!
					)
				}
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
