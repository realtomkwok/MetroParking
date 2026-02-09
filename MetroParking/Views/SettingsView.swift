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

	let version: String =
		Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
		?? "--"

	let build: String =
		Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "--"

	let devEmail: URL = URL.safe(
		Bundle.main.infoDictionary?["DEV_EMAIL"] as? String ?? ""
	)

	let devWebsite: URL =
		URL.safe(
			Bundle.main.infoDictionary?["DEV_WEBSITE_URL"] as? String ?? ""
		)

	let testFlightUrl: URL =
		URL.safe(
			Bundle.main.infoDictionary?["DEV_WEBSITE_URL"] as? String ?? ""
		)

	var body: some View {
		NavigationStack {
			List {

				Section(.settingsSectionHelp) {
					SettingsRow(
						"tips.section.title",
						icon: "sparkles",
						iconColour: .yellow,
						destination: { Settings_TipsView("tips.section.title") }
					)
					SettingsRow(
						"feedback.row.faq",
						icon: "questionmark.circle.fill",
						iconColour: .blue,
						systemURL: testFlightUrl
					)
					SettingsRow(
						"feedback.section.title",
						icon: "exclamationmark.bubble.fill",
						iconColour: .pink,
						destination: { Settings_FeedbackView("feedback.section.title") }
					)
				}
				Section {
					SettingsRow(
						"settings.title.developer",
						icon: "figure.flexibility",
						iconColour: .orange,
						externalURL: devWebsite
					) {
						Text("Tom Kwok")
							.foregroundStyle(.primary)
					}
					SettingsRow(
						"settings.row.version",
						icon: "info.circle",
						iconColour: .blue.mix(with: .cyan, by: 0.5),
						accessory: {
							Text("\(version) (\(build))")
								.foregroundStyle(.secondary)
						}
					)
				} header: {
					Text(.settingsSectionAbout)
				} footer: {
					Text(.settingsFootnote)
				}

				#if DEBUG
					Section("Debug") {
						SettingsRow(
							"API Debug",
							icon: "hammer.fill",
							iconColour: .gray,
							destination: {
								APIUsageDebugView()
									.environment(FacilityManager.shared)
							}
						)
						SettingsRow(
							"Background Refresh",
							icon: "arrow.clockwise.circle.fill",
							iconColour: .gray,
							destination: {
								BackgroundRefreshDebugView()
							}
						)
					}
				#endif
			}
			.navigationTitle(.settingsLabelMore)
			.toolbarTitleDisplayMode(.large)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button {
						dismiss()
					} label: {
						Label(.actionButtonClose, systemImage: "xmark")
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
	let title: LocalizedStringKey
	@ViewBuilder let content: Content

	init(
		_ title: LocalizedStringKey,
		@ViewBuilder content: () -> Content
	) {
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
	let iconColour: Color
	let rowAction: SettingsRowAction
	let destination: Destination?
	@ViewBuilder let accessory: Accessory

	@Environment(\.openURL) private var openURL
	@State private var isShowingSafari: Bool = false
	@State private var iconWidth: Double = 0

	// MARK: - Navigation Initialiser

	/// Creates a settings row with navigation to a destination view.
	init(
		_ title: LocalizedStringKey,
		subtitle: LocalizedStringKey? = nil,
		icon: String,
		iconColour: Color,
		@ViewBuilder destination: () -> Destination,
		@ViewBuilder accessory: () -> Accessory
	) {
		self.title = title
		self.subtitle = subtitle
		self.icon = icon
		self.iconColour = iconColour
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
		iconColour: Color,
		externalURL: URL,
		@ViewBuilder accessory: () -> Accessory
	) where Destination == EmptyView {
		self.title = title
		self.subtitle = subtitle
		self.icon = icon
		self.iconColour = iconColour
		self.rowAction = .externalURL(externalURL)
		self.destination = nil
		self.accessory = accessory()
	}

	/// Creates a settings row with a system URL (opens via openURL).
	init(
		_ title: LocalizedStringKey,
		subtitle: LocalizedStringKey? = nil,
		icon: String,
		iconColour: Color,
		systemURL: URL,
		@ViewBuilder accessory: () -> Accessory
	) where Destination == EmptyView {
		self.title = title
		self.subtitle = subtitle
		self.icon = icon
		self.iconColour = iconColour
		self.rowAction = .systemURL(systemURL)
		self.destination = nil
		self.accessory = accessory()
	}

	/// Creates a settings row with a custom action.
	init(
		_ title: LocalizedStringKey,
		subtitle: LocalizedStringKey? = nil,
		icon: String,
		iconColour: Color,
		action: @escaping () -> Void,
		@ViewBuilder accessory: () -> Accessory
	) where Destination == EmptyView {
		self.title = title
		self.subtitle = subtitle
		self.icon = icon
		self.iconColour = iconColour
		self.rowAction = .action(action)
		self.destination = nil
		self.accessory = accessory()
	}

	/// Creates a settings row with no interaction (static content only).
	init(
		_ title: LocalizedStringKey,
		subtitle: LocalizedStringKey? = nil,
		icon: String,
		iconColour: Color,
		@ViewBuilder accessory: () -> Accessory
	) where Destination == EmptyView {
		self.title = title
		self.subtitle = subtitle
		self.icon = icon
		self.iconColour = iconColour
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
					.foregroundStyle(iconColour)
					.symbolRenderingMode(.hierarchical)
					.symbolColorRenderingMode(.gradient)
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
		iconColour: Color,
		@ViewBuilder destination: () -> Destination
	) {
		self.init(
			title,
			subtitle: subtitle,
			icon: icon,
			iconColour: iconColour,
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
		iconColour: Color,
		externalURL: URL
	) where Destination == EmptyView {
		self.init(
			title,
			subtitle: subtitle,
			icon: icon,
			iconColour: iconColour,
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
		iconColour: Color,
		systemURL: URL
	) where Destination == EmptyView {
		self.init(
			title,
			subtitle: subtitle,
			icon: icon,
			iconColour: iconColour,
			systemURL: systemURL
		) {
			EmptyView()
		}
	}

	/// Creates a settings row with a custom action and no accessory.
	init(
		_ title: LocalizedStringKey,
		subtitle: LocalizedStringKey? = nil,
		icon: String,
		iconColour: Color,
		action: @escaping () -> Void
	) where Destination == EmptyView {
		self.init(
			title,
			subtitle: subtitle,
			icon: icon,
			iconColour: iconColour,
			action: action
		) {
			EmptyView()
		}
	}

	/// Creates a settings row with no interaction and no accessory.
	init(
		_ title: LocalizedStringKey,
		subtitle: LocalizedStringKey? = nil,
		icon: String,
		iconColour: Color,
	) where Destination == EmptyView {
		self.title = title
		self.subtitle = subtitle
		self.icon = icon
		self.iconColour = iconColour
		self.rowAction = .none
		self.destination = nil
		self.accessory = EmptyView()
	}
}

// MARK: - Tips Subpage

@ViewBuilder
private func Settings_TipsView(_ title: LocalizedStringKey) -> some View {
	SettingsSubpage(title) {
		List {
			Section(.navigationSectionTitle) {
				Label(
					.tipsTitleSwipeToPin,
					systemImage: "arrow.right.to.line"
				)
				Label(
					.tipsTitleSwipeToRefresh,
					systemImage: "arrow.clockwise"
				)
			}
			// Add more tips as needed
		}
	}
}

extension SettingsView {
	@ViewBuilder
	private func Settings_FeedbackView(_ title: LocalizedStringKey) -> some View
	{
		SettingsSubpage(title) {
			List {
				Section {

					Section(.feedbackLabelIssueNotListed) {

					}
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
		Settings_TipsView("Feedback")
	}
}
