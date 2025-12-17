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

	func loadPreview() async {
		Task {
			if let coordinate = coordinate {
				let request = MKLookAroundSceneRequest(coordinate: coordinate)

				do {
					lookAroundScene = try await request.scene
				} catch (let error) {
					Logger.maps.error("\(error.localizedDescription)")
				}
			}
		}
	}
}

