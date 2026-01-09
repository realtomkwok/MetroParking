//
//  Configuration.swift
//  MetroParking
//
//  Created by Tom Kwok on 19/6/2025.
//

import Foundation
import os.log

enum Configuration {

    // MARK: - TfNSW API Key

    static let tfnswApiKey: String = {
        guard
            let key = Bundle.main.object(forInfoDictionaryKey: "TFNSW_API_KEY")
                as? String,
            !key.isEmpty,
            !key.hasPrefix("YOUR_"),
            !key.contains("YOUR_API_KEY")
        else {
            Logger.appConfiguration.error("❌ TFNSW_API_KEY missing - app will not function")
            fatalError(
                "TFNSW_API_KEY not configured. Get your key from https://opendata.transport.nsw.gov.au/"
            )

        }

        /// Validation
        guard key.count >= 16,
            key.allSatisfy({ $0.isASCII && !$0.isWhitespace }),
            !key.lowercased().contains("example"),
            !key.lowercased().contains("test")
        else {

            Logger.appConfiguration.error("❌ TFNSW_API_KEY invalid format")
            fatalError(
                "TFNSW_API_KEY appears to be invalid. Use a real API key from TfNSW."
            )
        }

        Logger.appConfiguration.info("✅ TFNSW API key loaded")
        return key

    }()

    // MARK: - Car Park Base Url

    static let carParkBaseUrl: String = {
        guard
            let urlString = Bundle.main.object(
                forInfoDictionaryKey: "CAR_PARK_BASE_URL"
            ) as? String,
            !urlString.isEmpty
        else {
            let fallback = "https://api.transport.nsw.gov.au/v1"
            Logger.appConfiguration.warning("⚠️ CAR_PARK_BASE_URL missing, using: \(fallback)")
            return fallback
        }

        Logger.appConfiguration.info("✅ Car park base URL loaded: \(urlString)")
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return urlString
        } else {
            return "https://" + urlString
        }
    }()


    // MARK: - Debug Helper

    static func printConfiguration() {
        Logger.appConfiguration.info("🔑 Configuration loaded:")
        Logger.appConfiguration.info("📍 Base URL: \(carParkBaseUrl)")
        Logger.appConfiguration.info("🔐 API Key: \(tfnswApiKey.prefix(8))...")

    }
}

// MARK: - Configuration Check 
extension Configuration {
    /// Call this in DEBUG to verify all configs are properly set
    static func validateInDebug() {
        #if DEBUG
            var issues: [String] = []

            if tfnswApiKey.hasPrefix("YOUR_") || tfnswApiKey.count < 16 {
                issues.append(
                    "TFNSW_API_KEY appears to be placeholder or too short"
                )
            }

            if carParkBaseUrl.hasPrefix("YOUR_") {
                issues.append("CAR_PARK_BASE_URL appears to be placeholder")
            }

            if !issues.isEmpty {
                Logger.appConfiguration.error("🚨 Configuration issues found:")
                issues.forEach {
                    Logger.appConfiguration.debug("  - \($0)")
                }
                Logger.appConfiguration.fault("📝 Please update your Config.xcconfig file")
            } else {
                Logger.appConfiguration.notice("✅ All configurations look good!")
            }
        #endif
    }
}
