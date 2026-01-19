//
//  WidgetAPIService.swift
//  MetroParkingWidget
//
//  Created by Tom Kwok on 1/1/2026.
//
//  Lightweight API service for widget to fetch fresh vacancy data
//  when cached data becomes stale. Updates SharedDataManager cache
//  so main app can also benefit from the fresh data.

import Foundation

/// Lightweight API service for widget-only use
/// Fetches fresh vacancy data and updates the shared cache
///
/// **Note:** This duplicates core logic from `ParkingAPIService` (main app).
/// Duplication is intentional because widget extensions can't import main app code.
/// Keep both implementations synchronized when making changes to API calls.
///
/// **Future:** Consider moving shared API logic to a framework target (v0.6.0+).
struct WidgetAPIService {

    static let shared = WidgetAPIService()

    private let session = URLSession.shared
    private let decoder = JSONDecoder()

    private init() {}

    // MARK: - Fetch Fresh Data

    /// Fetches fresh vacancy data for a facility and updates the shared cache
    /// - Parameters:
    ///   - facilityId: The facility ID to fetch
    ///   - existingData: Existing widget data to preserve non-vacancy fields (name, address, etc.)
    /// - Returns: Updated WidgetFacilityData with fresh vacancy, or nil if fetch failed
    func fetchAndUpdateCache(
        facilityId: String,
        existingData: SharedDataManager.WidgetFacilityData?
    ) async -> SharedDataManager.WidgetFacilityData? {

        do {
            let response = try await fetchFacility(id: facilityId)

            // Parse vacancy from API response
            let total = Int(response.spots) ?? 0
            let occupied = Int(response.occupancy.total ?? "0") ?? 0
            let available = max(0, total - occupied)
            let occupancyRatio = total > 0 ? Double(occupied) / Double(total) : 0

            // Determine availability status
            let availabilityStatus: String
            if total == 0 {
                availabilityStatus = "No Data"
            } else if available == 0 {
                availabilityStatus = "Full"
            } else if occupancyRatio >= 0.9 {
                availabilityStatus = "Almost Full"
            } else {
                availabilityStatus = "Available"
            }

            // Parse display name from facility name
            let displayName = parseFacilityName(response.facilityName)

            // Create updated widget data
            let now = Date()
            let updatedData = SharedDataManager.WidgetFacilityData(
                facilityId: facilityId,
                name: response.facilityName,
                displayTitle: existingData?.displayTitle ?? displayName.title,
                displaySubtitle: existingData?.displaySubtitle ?? displayName.subtitle,
                address: existingData?.address ?? response.location.address,
                availableSpaces: available,
                totalSpaces: total,
                occupancyRatio: occupancyRatio,
                availabilityStatus: availabilityStatus,
                distance: existingData?.distance,
                travelTime: existingData?.travelTime,
                lastUpdated: now,
                cacheTimestamp: now
            )

            // Save to shared cache (main app will also read this)
            await SharedDataManager.shared.saveWidgetData(updatedData, triggerReload: false)

            print("✅ Widget API: Fetched fresh data for \(displayName.title) - \(available)/\(total) available")

            return updatedData

        } catch {
            print("❌ Widget API: Failed to fetch facility \(facilityId): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Private Methods

    private func fetchFacility(id: String) async throws -> ParkingAPIResponse {
        let url = try buildURL(for: id)
        let request = buildRequest(for: url)

        let (data, response) = try await session.data(for: request)

        try validateResponse(response)

        return try decode(data, facilityId: id)
    }

    private func buildURL(for facilityId: String) throws -> URL {
        guard let url = URL(string: "\(Configuration.carParkBaseUrl)/carpark?facility=\(facilityId)") else {
            throw WidgetAPIError.invalidURL
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
        req.timeoutInterval = 10 // Widget has limited time
        return req
    }

    private func validateResponse(_ res: URLResponse) throws {
        guard let httpResponse = res as? HTTPURLResponse else {
            throw WidgetAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw WidgetAPIError.httpError(httpResponse.statusCode)
        }
    }

    private func decode(_ data: Data, facilityId: String) throws -> ParkingAPIResponse {
        // Try direct decode first
        if let response = try? decoder.decode(ParkingAPIResponse.self, from: data) {
            return response
        }

        // Fallback to dictionary format
        let dict = try decoder.decode([String: ParkingAPIResponse].self, from: data)

        if let response = dict[facilityId] ?? dict.values.first {
            return response
        }

        throw WidgetAPIError.noData
    }

    /// Parse facility name into title and subtitle
    /// e.g., "Park&Ride - Gordon Station (North)" -> (title: "Gordon Station", subtitle: "North")
    private func parseFacilityName(_ name: String) -> (title: String, subtitle: String) {
        // Remove "Park&Ride - " prefix
        var cleanName = name
            .replacingOccurrences(of: "Park&Ride - ", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)
        
        // Apply capitalisation to match ParkingFacility.displayName behaviour
        cleanName = cleanName.localizedCapitalized
        
        // Match pattern: "Title (Subtitle)"
        // Captures: content inside parentheses as subtitle
        let regex = /^(.+?)\s*\((.+?)\)$/
        
        if let match = cleanName.firstMatch(of: regex) {
            let title = String(match.1).trimmingCharacters(in: .whitespaces)
            let subtitle = String(match.2).trimmingCharacters(in: .whitespaces)
            return (title: title, subtitle: subtitle)
        }
        
        // No parentheses found - return full name as title
        return (title: cleanName, subtitle: "")
    }
}

// MARK: - Errors

enum WidgetAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .noData:
            return "No data returned"
        }
    }
}
