//
//  ParkingAPI.swift
//  MetroParking
//
//  Created by Tom Kwok on 19/6/2025.
//

import Foundation

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
	case networkError(Error)
	case decodingError(Error)
	
	var errorDescription: String? {
		switch self {
			case .invalidURL:
				return "Invalid URL"
			case .noData:
				return "No data received"
			case .networkError(let error):
				return "Network error: \(error.localizedDescription)"
			case .decodingError(let error):
				return "Decoding error: \(error.localizedDescription)"
		}
	}
}

class ParkingAPIService {
	static let shared = ParkingAPIService()
	
	private init() {}
	
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

	// API METHODS
	// Fatch all the facilities and return
	func fetchAllFacilities() async throws -> [FacilityID: FacilityName] {
		guard let url = URL(string: "\(baseURL)/carpark") else {
			throw APIError.invalidURL
		}
		
		var req = URLRequest(url: url)
		req.setValue("application/json", forHTTPHeaderField: "accept")
		req.setValue("apikey \(apiKey)", forHTTPHeaderField: "Authorization")
		
		print("🌐 Fetching ALL facilities from: \(url)")
		
		do {
			let (data, res) = try await URLSession.shared.data(for: req)
			
			if let httpRes = res as? HTTPURLResponse {
				print("Status code: \(httpRes.statusCode)")
			}
			
			if let jsonString = String(data: data, encoding: .utf8) {
				print("Raw response preview:")
				print(String(jsonString.prefix(800)) + "...")
			}
			
			let facilities = try JSONDecoder().decode([FacilityID: FacilityName].self, from: data)
			print("Successfully decoded \(facilities.count) facilities")
			
			// Exclude historical data
			return facilities.filter { (_, name) in
				let isHistorical = name.lowercased().contains("historical only")
				
				return !isHistorical
			}
			
			
		} catch let decodingError as DecodingError {
			throw APIError.decodingError(decodingError)
		} catch {
			throw APIError.networkError(error)
		}
	}

	func fetchFacility(id: String) async throws -> ParkingAPIResponse {
		guard let url = URL(string: "\(baseURL)/carpark?facility=\(id)") else {
			throw APIError.invalidURL
		}
		
		var req = URLRequest(url: url)
		req.setValue("application/json", forHTTPHeaderField: "accept")
		req.setValue("apikey \(apiKey)", forHTTPHeaderField: "Authorization")
		
		print("Fetching facility \(id) from: \(url)")
		
		do {
			let (data, response) = try await URLSession.shared.data(for: req)
			
				// Check HTTP status
			if let httpResponse = response as? HTTPURLResponse {
				if httpResponse.statusCode == 429 {
					print("⚠️ Rate limited for facility \(id)")
					throw APIError.networkError(NSError(domain: "RateLimit", code: 429, userInfo: [NSLocalizedDescriptionKey: "Rate limit exceeded"]))
				} else if httpResponse.statusCode != 200 {
					print("⚠️ HTTP \(httpResponse.statusCode) for facility \(id)")
				}
			}
			
				// Check for specific error response (only if it contains "ErrorDetails")
			if let jsonString = String(data: data, encoding: .utf8),
				jsonString.contains("ErrorDetails") {
				print("❌ API error response for facility \(id)")
				throw APIError.noData
			}
			
				// Strategy 1: Try single object (most common)
			do {
				let facility = try JSONDecoder().decode(ParkingAPIResponse.self, from: data)
				print("✅ Facility \(id) decoded as single object")
				return facility
			} catch {
				print("⚠️ Single object decode failed for \(id), trying dictionary...")
			}
			
				// Strategy 2: Try dictionary format
			do {
				let facilitiesDict = try JSONDecoder().decode([FacilityID: ParkingAPIResponse].self, from: data)
				if let facility = facilitiesDict[id] ?? facilitiesDict.values.first {
					print("✅ Facility \(id) decoded from dictionary")
					return facility
				}
			} catch {
				print("⚠️ Dictionary decode failed for \(id)")
			}
			
			print("❌ All decode strategies failed for facility \(id)")
			throw APIError.noData
			
		} catch {
			throw APIError.networkError(error)
		}
	}
}
