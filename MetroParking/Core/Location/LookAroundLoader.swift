//
//  LookAroundLoader.swift
//  MetroParking
//
//  Created by Tom Kwok on 19/9/2026.
//

import MapKit
import OSLog

/// Loads the Look Around scene for one facility.
///
/// Owned by each detail view, so pushing a nearby facility and popping back
/// can't leave the previous screen showing another facility's scene.
@Observable
final class LookAroundLoader {

	enum Phase {
		case idle
		case loading
		case loaded(MKLookAroundScene)
		case unavailable(String)
	}

	private(set) var phase: Phase = .idle

	var isLoading: Bool {
		if case .loading = phase { return true }
		return false
	}

	func load(at coordinate: CLLocationCoordinate2D) async {
		phase = .loading

		do {
			let scene = try await MKLookAroundSceneRequest(coordinate: coordinate).scene
			guard !Task.isCancelled else { return }
			phase = scene.map(Phase.loaded) ?? .unavailable("Not available at this location")
		} catch {
			guard !Task.isCancelled else { return }
			Logger.maps.error("Look Around error: \(error.localizedDescription)")
			phase = .unavailable("Unable to load Look Around")
		}
	}
}
