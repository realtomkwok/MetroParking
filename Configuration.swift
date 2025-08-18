//
//  Configuration.swift
//  MetroParking
//
//  Created by Tom Kwok on 19/6/2025.
//

import Foundation

enum Configuration {
    private static let env = EnvironmentManager.shared
    
    /// TfNSW API Key - Required for API access
    static let tfnswApiKey: String = {
        do {
            return try env.getRequiredValue(for: "TFNSW_API_KEY")
        } catch {
            // Fallback to Info.plist for backwards compatibility
            guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "TFNSW_API_KEY") as? String,
                  !apiKey.isEmpty else {
                fatalError("TFNSW_API_KEY not found in environment variables or Info.plist. Please check your .env file or project configuration.")
            }
            return apiKey
        }
    }()
    
    /// Car Park API Base URL
    static let carParkBaseUrl: String = {
        return env.getValue(for: "CAR_PARK_BASE_URL") 
            ?? Bundle.main.object(forInfoDictionaryKey: "CAR_PARK_BASE_URL") as? String
            ?? "https://api.transport.nsw.gov.au/v1"
    }()
    
    /// Supabase Project URL
    static let supabaseUrl: String = {
        do {
            return try env.getRequiredValue(for: "SUPABASE_URL")
        } catch {
            // Fallback to Info.plist
            return Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String
			?? "SUPABASE_URL"
        }
    }()
    
    /// Supabase Publishable Key
    static let supabasePublishableKey: String = {
        do {
            return try env.getRequiredValue(for: "SUPABASE_PUBLISHABLE_KEY")
        } catch {
            // Fallback to Info.plist
            return Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String
                ?? "SUPABASE_PUBLISHABLE_KEY"
        }
    }()
    
    /// Current environment
    static let environment: EnvironmentType = env.currentEnvironment
    
    /// Check if running in debug mode
    static let isDebug: Bool = env.isDebug
    
    // MARK: - Debug Helpers
    
    /// Print configuration for debugging (masks sensitive values)
    static func printConfiguration() {
        print("🔑 Configuration (\(environment.displayName)):")
        print("📍 Base URL: \(carParkBaseUrl)")
        print("🔐 API Key: \(String(tfnswApiKey.prefix(8)))***")
        print("🏢 Supabase URL: \(supabaseUrl)")
        print("🔑 Supabase Key: \(String(supabasePublishableKey.prefix(8)))***")
        print("🐛 Debug Mode: \(isDebug)")
    }
    
    /// Validate that all required configuration is present
    static func validateConfiguration() throws {
        let requiredValues: [(key: String, value: String)] = [
            ("TFNSW_API_KEY", tfnswApiKey),
            ("SUPABASE_URL", supabaseUrl),
            ("SUPABASE_PUBLISHABLE_KEY", supabasePublishableKey)
        ]
        
        for (key, value) in requiredValues {
            if value.isEmpty {
                throw ConfigurationError.missingValue(key)
            }
        }
        
        print("✅ Configuration validation passed")
    }
}

// MARK: - Configuration Errors

enum ConfigurationError: LocalizedError {
    case missingValue(String)
    
    var errorDescription: String? {
        switch self {
        case .missingValue(let key):
            return "Required configuration value '\(key)' is missing or empty"
        }
    }
}
