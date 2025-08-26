//
//  Configuration.swift
//  MetroParking
//
//  Created by Tom Kwok on 19/6/2025.
//

import Foundation
import os.log

enum Configuration {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.tomkwok.MetroParking",
        category: "Configuration"
    )

    // MARK: - TfNSW API Key

    static let tfnswApiKey: String = {
        guard
            let key = Bundle.main.object(forInfoDictionaryKey: "TFNSW_API_KEY")
                as? String,
            !key.isEmpty,
            !key.hasPrefix("YOUR_"),
            !key.contains("YOUR_API_KEY")
        else {
            logger.error("❌ TFNSW_API_KEY missing - app will not function")
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

            logger.error("❌ TFNSW_API_KEY invalid format")
            fatalError(
                "TFNSW_API_KEY appears to be invalid. Use a real API key from TfNSW."
            )
        }

        logger.info("✅ TFNSW API key loaded")
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
            logger.warning("⚠️ CAR_PARK_BASE_URL missing, using: \(fallback)")
            return fallback
        }

        logger.info("✅ Car park base URL loaded: \(urlString)")
        return "https://" + urlString
    }()

    // MARK: - Supabase configuration
    static let supabaseUrl: String = {
        guard
            let urlString = Bundle.main.object(
                forInfoDictionaryKey: "SUPABASE_URL"
            ) as? String,
            !urlString.isEmpty,
            !urlString.hasPrefix("YOUR_")
        else {

            logger.info(
                "ℹ️ Supabase not configured - analytics features disabled"
            )
            return ""
        }

        // Validate Supabase URL format
        guard let url = URL(string: "https" + urlString),
            url.host?.contains("supabase") == true
        else {

            logger.warning("⚠️ Invalid SUPABASE_URL format, disabling analytics")
            return ""
        }

        logger.info("✅ Supabase URL loaded")
        return "https://" + urlString
    }()

    static let supabasePublishableKey: String = {
        guard
            let key = Bundle.main.object(
                forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY"
            ) as? String,
            !key.isEmpty,
            !key.hasPrefix("YOUR_")
        else {

            logger.info("ℹ️ Supabase key not configured")
            return ""
        }

        // Validate Supabase key format (starts with specific prefix)
        guard key.hasPrefix("eyJ") && key.count > 100 else {
            logger.warning("⚠️ Invalid SUPABASE_PUBLISHABLE_KEY format")
            return ""
        }

        logger.info("✅ Supabase key loaded")
        return key
    }()

    // MARK: - Debug Helper

    static func printConfiguration() {
        logger.info("🔑 Configuration loaded:")//a
        logger.info("📍 Base URL: \(carParkBaseUrl)")
        logger.info("🔐 API Key: \(tfnswApiKey.prefix(8))...")

        if !supabaseUrl.isEmpty {
            logger.info("🗄️ Supabase: Enabled")
        } else {
            logger.info("🗄️ Supabase: Disabled")
        }
    }
}

// MARK: - Configuration Check 
extension Configuration {
    /// Call this in DEBUG to verify all configs are properly set
    static func validateInDebug() {
        #if DEBUG
            var issues: [String] = []

            if tfnswApiKey.hasPrefix("YOUR_") || tfnswApiKey.count < 32 {
                issues.append(
                    "TFNSW_API_KEY appears to be placeholder or too short"
                )
            }

            if carParkBaseUrl.hasPrefix("YOUR_") {
                issues.append("CAR_PARK_BASE_URL appears to be placeholder")
            }

            if !issues.isEmpty {
                print("🚨 Configuration issues found:")
                issues.forEach { print("  - \($0)") }
                print("📝 Please update your Config.xcconfig file")
            } else {
                print("✅ All configurations look good!")
            }
        #endif
    }
}
