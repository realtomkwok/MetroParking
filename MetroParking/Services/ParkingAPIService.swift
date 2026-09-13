//
//  ParkingAPIService.swift
//  MetroParking
//
//  Created by Tom Kwok on 19/6/2025.
//

import Foundation
import OSLog

/// Fetches car park occupancy from the TfNSW Car Park API.
///
/// Shared by the app and the widget extension (compiled into both targets).
/// Rate limiting (`APIDispatcher`) and usage accounting (`APIUsageMonitor`)
/// are the caller's responsibility.
struct ParkingAPIService: Sendable {
	static let shared = ParkingAPIService()

	private let session: URLSession

	init(session: URLSession = .shared) {
		self.session = session
	}

	// MARK: - API Methods

	/// - Parameter timeout: Request timeout; widgets use a short one because they have limited run time.
	func fetchFacility(
		id: String,
		timeout: TimeInterval = 60
	) async throws -> ParkingApiModel {
		let url = try buildURL(for: id)
		var request = buildRequest(for: url)
		request.timeoutInterval = timeout

		let (data, response) = try await session.data(for: request)

		try validateResponse(response)

		return try Self.decode(data, facilityId: id)
	}

	/// Decodes either a single facility object or a dictionary keyed by facility ID.
	static func decode(_ data: Data, facilityId: String) throws -> ParkingApiModel {
		let decoder = JSONDecoder()

		if let response = try? decoder.decode(ParkingApiModel.self, from: data) {
			return response
		}

		let dict: [String: ParkingApiModel]
		do {
			dict = try decoder.decode([String: ParkingApiModel].self, from: data)
		} catch {
			throw APIError.decodingFailed(error)
		}

		guard let response = dict[facilityId] ?? dict.values.first else {
			throw APIError.noDataForFacility(facilityId)
		}
		return response
	}

	// MARK: - Private methods

	private func buildURL(for facilityId: String) throws -> URL {
		guard
			let url = URL(
				string: "\(Configuration.carParkBaseUrl)/carpark?facility=\(facilityId)"
			)
		else {
			throw APIError.invalidURL
		}
		return url
	}

	private func buildRequest(for url: URL) -> URLRequest {
		var req = URLRequest(url: url)

		req.setValue("application/json", forHTTPHeaderField: "accept")
		req.setValue(
			"apikey \(Configuration.tfnswApiKey)",
			forHTTPHeaderField: "Authorization"
		)
		return req
	}

	private func validateResponse(_ res: URLResponse) throws {
		guard let httpResponse = res as? HTTPURLResponse else {
			Logger.api.error("HTTP error")
			throw URLError(.badServerResponse)
		}

		switch httpResponse.statusCode {
		case 200...299:
			return
		case 429:
			Logger.api.warning("⚠️ API rate limit hit")
			throw APIError.networkError(429)
		case 400...499:
			Logger.api.error("❌ Client error: \(httpResponse.statusCode)")
			throw APIError.networkError(httpResponse.statusCode)
		case 500...599:
			Logger.api.error("❌ Server error: \(httpResponse.statusCode)")
			throw APIError.networkError(httpResponse.statusCode)
		default:
			Logger.api.error("❌ Unexpected status: \(httpResponse.statusCode)")
			throw APIError.networkError(httpResponse.statusCode)
		}
	}
}

// MARK: - Supporting types

enum APIError: LocalizedError {
	case invalidURL
	case noDataForFacility(String)
	case decodingFailed(Error)
	case networkError(Int)

	var errorDescription: String? {
		switch self {
		case .invalidURL:
			return "Invalid API URL configuration"
		case .noDataForFacility(let id):
			return "No data returned for facility \(id)"
		case .decodingFailed(let error):
			return "Failed to decode API response: \(error.localizedDescription)"
		case .networkError(let code):
			return "Network error with status code: \(code)"
		}
	}
}
