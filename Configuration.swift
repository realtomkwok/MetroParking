//
//  Configuration.swift
//  MetroParking
//
//  Created by Tom Kwok on 19/6/2025.
//

import Foundation

enum Configuration {
	static let tfnswApiKey: String = {
		guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "TFNSW_API_KEY") as? String,
			  !apiKey.isEmpty else {
			fatalError("TFNSW_API_KEY not found in Info.plist. Please add your API key to the project configuration.")
		}
		return apiKey
	}()
	
	static let carParkBaseUrl: String = {
		return Bundle.main.object(forInfoDictionaryKey: "CAR_PARK_BASE_URL") as? String
		?? "https://api.transport.nsw.gov.au/v1"
	}()
	
		// Debug helper
	static func printConfiguration() {
		print("🔑 Configuration:")
		print("📍 Base URL: \(carParkBaseUrl)")
		print("🔐 API Key: \(tfnswApiKey.prefix(8))...") // Only show first 8 chars for security
	}
}
