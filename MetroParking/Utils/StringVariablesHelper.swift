//
//  StringVariablesHelper.swift
//  MetroParking
//
//  Created by Tom Kwok on 10/2/2026.
//

import Foundation

/// Info.plist string variables used across the app (primarily in SettingsView).
/// Access values via `InfoPlistStrings[key]` or the typed static properties.
enum InfoPlistStrings {
	private static let info = Bundle.main.infoDictionary

	static subscript(key: String) -> String {
		info?[key] as? String ?? ""
	}

	static let version: String = info?["CFBundleShortVersionString"] as? String ?? "--"
	static let build: String = info?["CFBundleVersion"] as? String ?? "--"
	static let devEmail: URL = URL.safe(Self["DEV_EMAIL"])
	static let devWebsite: URL = URL.safe(Self["DEV_WEBSITE_URL"])
	static let testFlightUrl: URL = URL.safe(Self["TESTFLIGHT_URL"])
	static let feedbackFormUrl: URL = URL.safe(Self["FEEDBACK_FORM_URL"])
	static let privacyTermsUrl: URL = URL.safe(Self["PRIVACY_TERMS_PAGE_URL"])
	static let marketingPageUrl: URL = URL.safe(Self["MKT_PAGE_URL"])
	static let learnMoreUrl: URL = URL.safe("https://transportnsw.info/travel-info/ways-to-get-around/drive/parking/transport-parkride-car-parks")
	static let appStoreReviewUrl: URL = URL.safe(Self["AS_REVIEW_URL"])
}
