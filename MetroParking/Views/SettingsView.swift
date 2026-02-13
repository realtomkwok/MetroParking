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

	let version = InfoPlistStrings.version
	let build = InfoPlistStrings.build
	let devEmail = InfoPlistStrings.devEmail
	let devWebsite = InfoPlistStrings.devWebsite
	let testFlightUrl = InfoPlistStrings.testFlightUrl
	let feedbackForm = InfoPlistStrings.feedbackFormUrl
	let privacyPolicyUrl = InfoPlistStrings.privacyTermsUrl
	let reviewUrl = InfoPlistStrings.appStoreReviewUrl

	var body: some View {
		NavigationStack {
			List {

				Section {
					SettingsRow(
						"tips.section.title",
						icon: "sparkles",
						iconColour: .yellow.mix(with: .orange, by: 0.3),
						destination: { Settings_TipsView() }
					)
					SettingsRow(
						"feedback.section.title",
						icon: "exclamationmark.bubble.fill",
						iconColour: .purple,
						externalURL: feedbackForm,
					) {
						ExternalAccessory()
					}
					SettingsRow(
						"review.section.title",
						icon: "star.bubble.fill",
						iconColour: .orange,
						systemURL: reviewUrl
					) {
					}
				}

				Section {

					SettingsRow(
						"testflight.section.title",
						subtitle: "testflight.section.subtitle",
						icon: "testtube.2",
						iconColour: .blue,
						systemURL: testFlightUrl
					) {
					}
				}

				Section {
					SettingsRow(
						"settings.title.developer",
						icon: "figure.flexibility",
						iconColour: .pink,
						externalURL: devWebsite
					) {
						Text(verbatim: "Tom Kwok")
					}
					SettingsRow(
						"settings.row.privacy",
						icon: "checkmark.seal.text.page.fill",
						iconColour: .brown,
						externalURL: privacyPolicyUrl
					)
					SettingsRow(
						"settings.row.version",
						icon: "info.circle.fill",
						iconColour: .blue.mix(with: .teal, by: 0.5),
						accessory: {
							Text("\(version) (\(build))")
								.foregroundStyle(.secondary)
						}
					)
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

struct ExternalAccessory: View {
	var body: some View {
		Label(.externalLinkLabel, systemImage: "arrow.up.forward")
			.font(.callout)
			.fontWeight(.medium)
			.foregroundStyle(Color(uiColor: .tertiaryLabel))
			.labelStyle(.iconOnly)
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

struct SettingsRow<Destination: View, Accessory: View>: View {
	let title: LocalizedStringKey
	let subtitle: LocalizedStringKey?
	let icon: String?
	let iconColour: Color?
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
		icon: String? = nil,
		iconColour: Color? = nil,
		externalURL: URL,
		@ViewBuilder accessory: () -> Accessory = { ExternalAccessory() }
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
				if let icon, let iconColour {
					Image(systemName: icon)
						.foregroundStyle(iconColour)
						.symbolRenderingMode(.hierarchical)
						.symbolColorRenderingMode(.gradient)
				} else {
					EmptyView()
				}
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

struct Settings_TipsView: View {
	let title: LocalizedStringKey = "tips.section.title"

	let learnMoreUrl = InfoPlistStrings.learnMoreUrl

	@ViewBuilder
	private func FAQBody(
		_ title: LocalizedStringKey,
		_ body: LocalizedStringKey,
		systemIcon: String,
		iconColour: Color
	) -> some View {
		VStack(alignment: .listRowSeparatorLeading, spacing: 16) {
			RoundedRectangle(cornerRadius: 8, style: .circular)
				.foregroundStyle(iconColour.gradient)
				.aspectRatio(1.0, contentMode: .fit)
				.frame(maxWidth: 48)
				.overlay {
					Image(systemName: systemIcon)
						.font(.title)
						.fontWeight(.semibold)
						.foregroundStyle(.white.gradient)
						.symbolRenderingMode(.hierarchical)
						.symbolColorRenderingMode(.gradient)
						.padding()
				}
			VStack(alignment: .listRowSeparatorLeading, spacing: 8) {
				Text(title)
					.font(.headline)
					.fixedSize(horizontal: false, vertical: true)

				Text(body)
					.font(.body)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}

		}

	}

	var body: some View {
		SettingsSubpage(title) {
			List {
				Section(.faqCarparkSectionTitle) {
					FAQBody(
						"faq.carpark.hours.title",
						"faq.carpark.hours.body",
						systemIcon: "parkingsign.square.fill",
						iconColour: .blue
					)
					SettingsRow(
						"faq.carpark.learnMore.title",
						subtitle: "faq.carpark.learnMore.subtitle",
						externalURL: learnMoreUrl
					)
				}

				Section(.faqsSectionTitle) {
					FAQBody(
						"faq.1.title",
						"faq.1.body",
						systemIcon: "arrow.clockwise.circle.fill",
						iconColour: .green
					)
					FAQBody(
						"faq.2.title",
						"faq.2.body",
						systemIcon: "location.circle.fill",
						iconColour: .blue
					)
					FAQBody(
						"faq.3.title",
						"faq.3.body",
						systemIcon: "exclamationmark.bubble.fill",
						iconColour: .purple
					)
				}

				Section(.navigationSectionTitle1) {
					SettingsRow(
						"tips.title.swipeToPin",
						icon: "star.fill",
						iconColour: .yellow.mix(with: .orange, by: 0.5)
					)
					SettingsRow(
						"tips.title.swipeToRefresh",
						icon: "arrow.clockwise",
						iconColour: .blue.mix(with: .cyan, by: 0.5)
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
