//
//  ParkingAPI.swift
//  MetroParking
//
//  Created by Tom Kwok on 19/6/2025.
//

import Foundation
import OSLog

class ParkingAPIService {
	static let shared = ParkingAPIService()

	private let session = URLSession.shared
	private let rateLimiter = RateLimiter(minInterval: 1)
	private let decoder = JSONDecoder()

	private init() {
	}

	// MARK: - API Methods

	func fetchFacility(id: String) async throws -> ParkingAPIResponse {
		await rateLimiter.waitIfNeeded()

		// Record API usage
		APIUsageMonitor.recordCall()

		let url = try buildURL(for: id)
		let request = buildRequest(for: url)

		let (data, response) = try await session.data(for: request)

		try validateResponse(response)

		return try decode(data, facilityId: id)
	}

	// MARK: - Private methods

	private func buildURL(for facilityId: String) throws -> URL {
		guard let url = URL(string: "\(Configuration.carParkBaseUrl)/carpark?facility=\(facilityId)") else {
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
			Logger.facilityRefresh.error("HTTP error")
			throw URLError(.badServerResponse)
		}

		switch httpResponse.statusCode {
		case 200 ... 299:
			return
		case 429:
			Logger.facilityRefresh.warning("⚠️ API rate limit hit")
			throw APIError.networkError(429)
		case 400 ... 499:
			Logger.facilityRefresh.error("❌ Client error: \(httpResponse.statusCode)")
			throw APIError.networkError(httpResponse.statusCode)
		case 500 ... 599:
			Logger.facilityRefresh.error("❌ Server error: \(httpResponse.statusCode)")
			throw APIError.networkError(httpResponse.statusCode)
		default:
			Logger.facilityRefresh.error("❌ Unexpected status: \(httpResponse.statusCode)")
			throw APIError.networkError(httpResponse.statusCode)

		}
	}

	func decode(_ data: Data, facilityId: String) throws -> ParkingAPIResponse {

		if let response = try? decoder.decode(
			ParkingAPIResponse.self,
			from: data
		) {
			return response
		}

		// Fallback to dictionary format decoder
		do {
			let dict = try decoder.decode(
				[String: ParkingAPIResponse] .self,
				from: data
			)

			if let response = dict[facilityId] ?? dict.values.first {
				return response
			} else {
				throw APIError.noDataForFacility(facilityId)
			}
		} catch {
			throw APIError.decodingFailed(error)
		}
	}
}

// MARK: - Supporting types

enum APIError: LocalizedError {
	case invalidURL
	case noDataForFacility (String)
	case decodingFailed (Error)
	case networkError (Int)

	var errorDescription: String? {
		switch self {
		case .invalidURL:
			return "Invalid API URL configuration"
		case .noDataForFacility (let id):
			return "No data returned for facility \(id)"
		case .decodingFailed (let error):
			return "Failed to decode API response: \(error.localizedDescription)"
		case .networkError (let code):
			return "Network error with status code: \(code)"
		}
	}
}
