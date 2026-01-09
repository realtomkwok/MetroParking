//
//  LookAroundManager.swift
//  MetroParking
//
//  Created by Tom Kwok on 7/12/2025.
//

import MapKit
import Foundation
import OSLog

@Observable
class LookAroundManager {

	static let shared = LookAroundManager()

	var lookAroundScene: MKLookAroundScene?
	var coordinate: CLLocationCoordinate2D?
	var isLoading: Bool = false
	var errorMessage: String?

	func loadPreview() async {
		Task {
			guard let coordinate = coordinate else {
				errorMessage = "Location not available"
				return
			}
			
			// Reset state
			isLoading = true
			errorMessage = nil
			lookAroundScene = nil
			
			let request = MKLookAroundSceneRequest(coordinate: coordinate)

			do {
				lookAroundScene = try await request.scene
				
				// Check if scene is actually nil (no Look Around available at location)
				if lookAroundScene == nil {
					errorMessage = "Not available at this location"
				}
			} catch {
				Logger.maps.error("Look Around error: \(error.localizedDescription)")
				errorMessage = "Unable to load Look Around"
			}
			
			isLoading = false
		}
	}
}

