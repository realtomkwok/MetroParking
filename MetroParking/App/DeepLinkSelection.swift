//
//  DeepLinkSelection.swift
//  MetroParking
//
//  Created by Tom Kwok on 21/9/2026.
//

import OSLog
import SwiftData
import SwiftUI

/// Turns a facility ID arriving from a widget tap or a `metroparking://` URL into
/// a selection in the sheet.
///
/// Runs with `initial: true` so a link that launched the app cold is handled as
/// soon as the view appears, not only on the next change.
struct DeepLinkSelection: ViewModifier {
	let model: MapSheetModel

	@Environment(\.modelContext) private var modelContext
	@Environment(DeepLinkManager.self) private var deepLinkMgr

	func body(content: Content) -> some View {
		content
			.onChange(of: deepLinkMgr.selectedFacilityId, initial: true) {
				_,
				facilityId in
				guard let facilityId else { return }
				select(facilityId)
			}
	}

	private func select(_ facilityId: String) {
		defer { deepLinkMgr.clearSelection() }

		guard modelContext.facility(id: facilityId) != nil else {
			Logger.deeplink.error(
				"⚠️ Deep link: No facility found with ID: \(facilityId)"
			)
			return
		}

		Logger.deeplink.info("✅ Deep link: Showing facility \(facilityId)")
		model.select(facilityId)
	}
}

extension View {
	/// Selects the facility a deep link names, if the store knows it.
	func deepLinkSelection(into model: MapSheetModel) -> some View {
		modifier(DeepLinkSelection(model: model))
	}
}
