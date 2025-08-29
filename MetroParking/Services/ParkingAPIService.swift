//
//  ParkingAPI.swift
//  MetroParking
//
//  Created by Tom Kwok on 19/6/2025.
//

import Foundation
import OSLog

typealias FacilityID = String
typealias FacilityName = String

struct APIErrorResponse: Codable {
	let errorDetails: ErrorDetails?

	var message: String {
		return errorDetails?.message ?? "Unknown API error"
	}

	enum CodingKeys: String, CodingKey {
		case errorDetails = "ErrorDetails"
	}
}

struct ErrorDetails: Codable {
	let message: String
	let code: String?

	enum CodingKeys: String, CodingKey {
		case message = "Message"
		case code = "Code"
	}
}

enum APIError: Error, LocalizedError {
	case invalidURL
	case noData
	case networkError (Error)
	case decodingError (Error)

	var errorDescription: String? {
		switch self {
		case .invalidURL:
			return "Invalid URL"
		case .noData:
			return "No data received"
		case .networkError (let error):
			return "Network error: \(error.localizedDescription)"
		case .decodingError (let error):
			return "Decoding error: \(error.localizedDescription)"
		}
	}
}

class ParkingAPIService {
	static let shared = ParkingAPIService()
	let startTime = CFAbsoluteTimeGetCurrent()

	private init() {
	}

	private var baseURL: String {
		return Configuration.carParkBaseUrl
	}
	private var apiKey: String {
		return Configuration.tfnswApiKey
	}

	struct FacilityListItem: Codable {
		let facilityId: String
		let facilityName: String

		enum CodingKeys: String, CodingKey {
			case facilityId = "facility_id"
			case facilityName = "facility_name"
		}
	}

	// MARK: - API Methods

	func fetchFacility(id: String) async throws -> ParkingAPIResponse {
		guard let url = URL(string: "\(baseURL)/carpark?facility=\(id)") else {
			Logger.facilityRefresh.error("❌ Invalid URL for facility \(id)")
			throw APIError.invalidURL
		}

		var req = URLRequest(url: url)
		req.setValue("application/json", forHTTPHeaderField: "accept")
		req.setValue("apikey \(apiKey)", forHTTPHeaderField: "Authorization")

		Logger.facilityRefresh.info("🚀 Request for facility \(id)")
		Logger.facilityRefresh.debug("URL: \(url.absoluteString)")
		Logger.facilityRefresh.debug(
			"Header: \(req.allHTTPHeaderFields ?? [:])"
		)

		do {
			let (data, response) = try await URLSession.shared.data(for: req)
			let networkTime = CFAbsoluteTimeGetCurrent() - startTime

			Logger.facilityRefresh.info(
				"📥 Response received in \(String(format: "%.3f", networkTime))s"
			)
			Logger.facilityRefresh.debug("📊 Data size: \(data.count) bytes")

			// Check HTTP status
			if let httpResponse = response as? HTTPURLResponse {
				Logger.facilityRefresh.debug(
					"🌐 HTTP Status: \(httpResponse.statusCode)"
				)
				Logger.facilityRefresh.debug(
					"📨 Response headers: \(httpResponse.allHeaderFields)"
				)

				if httpResponse.statusCode == 429 {
					Logger.facilityRefresh.error("⚠️ Rate limited for facility \(id)")
					throw APIError.networkError(
						NSError(
							domain: "RateLimit",
							code: 429,
							userInfo: [
								NSLocalizedDescriptionKey: "Rate limit exceeded"
							]
						)
					)
				} else if httpResponse.statusCode != 200 {
					Logger.facilityRefresh.warning(
						"⚠️ HTTP \(httpResponse.statusCode) for facility \(id)"
					)
				}
			}

			if let rawString = String(data: data, encoding: .utf8) {
				Logger.facilityRefresh.info("📄 Raw JSON response: \(rawString)")

				let bytes = data.map {
					String(format: "%02x", $0)
				}.joined(
					separator: " "
				)
				Logger.facilityRefresh.debug(
					"🔍 Raw bytes (first 100): \(String(bytes.prefix(200)))"
				)
			} else {
				Logger.facilityRefresh.error("❌ Cannot convert data to UTF-8 string!")
			}

			return try attemptDecode(data: data, facilityId: id)

		} catch {
			throw APIError.networkError(error)
		}
	}

	private func attemptDecode(data: Data, facilityId: String) throws -> ParkingAPIResponse
		{
		let decoder = JSONDecoder()

		// Strategy 1: Decode it into single object
		do {
			let facility = try decoder.decode(
				ParkingAPIResponse.self,
				from: data
			)
			Logger.facilityRefresh.info("✅ Single object decode SUCCESS for \(facilityId)")
			return facility
		} catch let decodingError {
			Logger.facilityData.warning(
				"⚠️ Single object decode failed for \(facilityId)"
			)
			Logger.facilityData.debug("🔍 Decoding error: \(decodingError)")

			if let decodingError = decodingError as? DecodingError {
				logDecodingError(decodingError, context: "single object")
			}
		}

		// Strategy 2: Dictionary format
		do {
			let facilitiesDict = try decoder.decode(
				[String: ParkingAPIResponse] .self,
				from: data
			)
			Logger.facilityData.info(
				"📚 Dictionary contains \(facilitiesDict.keys.count) facilities"
			)
			Logger.facilityData.debug(
				"🗝️ Dictionary keys: \(Array(facilitiesDict.keys))"
			)

			if let facility = facilitiesDict[facilityId] ?? facilitiesDict.values.first {
				Logger.facilityData.info(
					"✅ Dictionary decode SUCCESS for \(facilityId)"
				)
				return facility
			} else {
				Logger.facilityData.error(
					"❌ Facility \(facilityId) not found in dictionary"
				)
			}
		} catch let decodingError {
			Logger.facilityData.warning(
				"⚠️ Dictionary decode failed for \(facilityId)"
			)
			if let decodingError = decodingError as? DecodingError {
				logDecodingError(decodingError, context: "dictionary")
			}
		}

		Logger.facilityData.error(
			"❌ ALL decode strategies failed for facility \(facilityId)"
		)
		throw APIError.noData
	}

	private func logDecodingError(_ error: DecodingError, context: String) {
		switch error {
		case .typeMismatch (let type, let ct):
			Logger.facilityData.debug(
				"🔍 [\(context)] Type mismatch: expected \(type), at path: \(ct.codingPath)"
			)
		case .valueNotFound (let type, let ct):
			Logger.facilityData.debug(
				"🔍 [\(context)] Value not found: \(type) at path: \(ct.codingPath)"
			)
		case .keyNotFound (let key, let ct):
			Logger.facilityData.debug(
				"🔍 [\(context)] Key not found: \(key.stringValue) at path: \(ct.codingPath)"
			)
		case .dataCorrupted (let ct):
			Logger.facilityData.debug(
				"🔍 [\(context)] Data corrupted at path: \(ct.codingPath)"
			)
			Logger.facilityData.debug(
				"🔍 [\(context)] Debug description: \(ct.debugDescription)"
			)
		@unknown default:
			Logger.facilityData.debug("🔍 [\(context)] Unknown decoding error: \(error)")
		}
	}
}

extension ParkingAPIService {

}
