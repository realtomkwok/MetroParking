//
//  RefreshConfiguration.swift
//  MetroParking
//
//  Created by Tom Kwok on 17/8/2025.
//

import Foundation

struct RefreshConfiguration {
	/// Global settings
	static let globalMinInterval: TimeInterval = 0.2
	static let globalMaxConcurrency: Int = 2
	static let globalDelay: Double = 1.0

	/// Tier-specific settings (use RefreshTier from ParkingFacility)
	static func getSettings(for tier: RefreshTier) -> (
		interval: TimeInterval,
		maxConcurrency: Int,
		baseDelay: TimeInterval
	) {
		switch tier {
		case .realTime: return (15, globalMaxConcurrency, globalDelay)
		case .standard: return (600, globalMaxConcurrency, globalDelay)
		case .idle: return (1800, globalMaxConcurrency, globalDelay)
		case .onDemand: return (.infinity, 1, globalDelay)
		}
	}
}
