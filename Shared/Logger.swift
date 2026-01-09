//
//  Logger.swift
//  MetroParking
//
//  Created by Tom Kwok on 28/8/2025.
//

import OSLog

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier ?? "MetroParking"

    static let appConfiguration = Logger(subsystem: subsystem, category: "Configuration")

    static let facilityData = Logger(subsystem: subsystem, category: "Facility Data")

    static let facilityRefresh = Logger(subsystem: subsystem, category: "Facility Refresh")

    static let maps = Logger(subsystem: subsystem, category: "Map Service")

	static let mapCamera = Logger(subsystem: subsystem, category: "Map Camera")

    static let ui = Logger(subsystem: subsystem, category: "UI")

	static let api = Logger(subsystem: subsystem, category: "API")

	static let location = Logger(subsystem: subsystem, category: "Location Services")

	static let widget = Logger(subsystem: subsystem, category: "Widget")
}
