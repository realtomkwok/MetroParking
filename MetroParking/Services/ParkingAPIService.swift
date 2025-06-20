//
//  ParkingAPI.swift
//  MetroParking
//
//  Created by Tom Kwok on 19/6/2025.
//

import Foundation

typealias FacilityID = String
typealias FacilityName = String

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
		
		print ("Fetching facility \(id) from: \(url)")
		
		do {
			let (data, _) = try await URLSession.shared.data(for: req)
			
			do {
				let facility = try JSONDecoder().decode(ParkingAPIResponse.self, from: data)
				return facility
			} catch {
				let facilities = try JSONDecoder().decode([ParkingAPIResponse].self, from: data)
				guard let facility = facilities.first else {
					throw APIError.noData
				}
				
				return facility
			}
		} catch {
			throw APIError.networkError(error)
		}
	}
}
