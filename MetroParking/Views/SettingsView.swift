//
//  SettingsView.swift
//  MetroParking
//
//  Created by Tom Kwok on 26/12/2025.
//

//

import SwiftUI

struct SettingsView: View {
	@Namespace private var namespace
	@State private var isShowingSettingsSheet = false

	var body: some View {
		Button {
			isShowingSettingsSheet = true
		} label: {
			Label("Settings", systemImage: "ellipsis")
				.labelStyle(.iconOnly)
		}
		.matchedTransitionSource(id: "settingsButton", in: namespace)
		.sheet(isPresented: $isShowingSettingsSheet) {
			NavigationStack {
				SettingsMenuView(namespace: namespace)
					.navigationTransition(
						.zoom(sourceID: "settingsButton", in: namespace)
					)
			}
		}
	}
}

private struct SettingsMenuView: View {
	let namespace: Namespace.ID
	@Environment(\.dismiss) private var dismiss

	var body: some View {

		List {
			Section {
				NavigationLink(destination: AboutView()) {
					Label("About", systemImage: "info.circle")
				}
			}
			#if DEBUG
				Section("Developer") {
					NavigationLink(destination: APIUsageDebugView()) {
						Label("API Debug", systemImage: "hammer")
					}

					NavigationLink(destination: BackgroundRefreshDebugView()) {
						Label(
							"Background Refresh",
							systemImage: "arrow.clockwise.circle"
						)
					}
				}
			#endif
		}

		.navigationTitle("Settings")
		.navigationBarTitleDisplayMode(.large)
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Button("Close", systemImage: "xmark") {
					dismiss()
				}
			}
		}
	}
}

struct AboutView: View {

	var body: some View {
		Text("About")
			.navigationTitle("About")
	}
}

#Preview {
	SettingsView()
}
