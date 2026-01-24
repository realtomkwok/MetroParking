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

	var body: some View {
		NavigationStack {
			List {

				Section("Help") {
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
					Text("About")
				} footer: {
					Text(
						"Data provided by [Transport for NSW Open Data](https://opendata.transport.nsw.gov.au/data/dataset/car-park-api)"
					)
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
			.navigationTitle("More")
			.toolbarTitleDisplayMode(.large)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button {
						dismiss()
					} label: {
						Label("Close", systemImage: "xmark")
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
	let title: String
	let subtitle: String?
	let icon: String
	let rowAction: SettingsRowAction
	let destination: Destination?
	@ViewBuilder let accessory: Accessory

	@Environment(\.openURL) private var openURL
	@State private var isShowingSafari = false

	// MARK: - Navigation Initialiser

	/// Creates a settings row with navigation to a destination view.
	init(
		_ title: String,
		subtitle: String? = nil,
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
		_ title: String,
		subtitle: String? = nil,
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
		_ title: String,
		subtitle: String? = nil,
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
		_ title: String,
		subtitle: String? = nil,
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
		_ title: String,
		subtitle: String? = nil,
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
			if let subtitle, !subtitle.isEmpty {
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
		_ title: String,
		subtitle: String? = nil,
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
		_ title: String,
		subtitle: String? = nil,
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
		_ title: String,
		subtitle: String? = nil,
		icon: String,
		systemURL: URL
	) where Destination == EmptyView {
		self.init(title, subtitle: subtitle, icon: icon, systemURL: systemURL) {
			EmptyView()
		}
	}

	/// Creates a settings row with a custom action and no accessory.
	init(
		_ title: String,
		subtitle: String? = nil,
		icon: String,
		action: @escaping () -> Void
	) where Destination == EmptyView {
		self.init(title, subtitle: subtitle, icon: icon, action: action) {
			EmptyView()
		}
	}

	/// Creates a settings row with no interaction and no accessory.
	init(
		_ title: String,
		subtitle: String? = nil,
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

@ViewBuilder
private func Settings_FeedbackView() -> some View {
	SettingsSubpage("Feedback") {
		List {
			Section {
				SettingsRow(
					"Report a bug",
					icon: "ladybug",
					externalURL: URL(
						string: "https://testflight.apple.com/join/metroparking"
					)!
				)
				SettingsRow(
					"Request a feature",
					icon: "plus.bubble",
					externalURL: URL(
						string: "https://testflight.apple.com/join/metroparking"
					)!
				)
			}
			Section("Issue not listed?") {
				SettingsRow(
					"Contact Developer",
					subtitle: "via Email",
					icon: "envelope",
					systemURL: URL(string: "mailto:tom@itsnoice.com")!
				)
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
