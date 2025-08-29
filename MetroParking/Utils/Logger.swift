//
//  Logger.swift
//  MetroParking
//
//  Created by Tom Kwok on 28/8/2025.
//

import OSLog

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier ?? "MetroParking"

    static let facilityData = Logger(subsystem: subsystem, category: "Facility Data")

    static let facilityRefresh = Logger(subsystem: subsystem, category: "Facility Refresh")
}
