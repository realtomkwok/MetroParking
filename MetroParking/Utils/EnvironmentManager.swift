//
//  EnvironmentManager.swift
//  MetroParking
//
//  Created by Tom Kwok on 18/8/2025.
//

import Foundation

/// Manages environment variables from .env files and system environment
final class EnvironmentManager {
	static let shared = EnvironmentManager()

	private var environmentVariables: [String: String] = [:]

	private init() {
		loadEnvironmentVariables()
	}

	/// Load environment variables from .env file and system environment
	private func loadEnvironmentVariables() {
		/// First, load from .env file
		loadFromDotEnvFile()

		/// Then, load from system environment (these override .env values)
		loadFromSystemEnvironment()

		#if DEBUG
			printLoadedEnvironment()
		#endif
	}

	/// Load variables from .env file in the project bundle
	private func loadFromDotEnvFile() {
		guard let envPath = Bundle.main.path(forResource: ".env", ofType: nil) else {
			print("⚠️ No .env file found in bundle. Using fallback values.")
			return
		}

		guard let envContent = try? String(contentsOfFile: envPath, encoding: .utf8) else {
			print("⚠️ Could not read .env file")
			return
		}

		parseEnvironmentContent(envContent)
	}

	/// Load variables from system environment
	private func loadFromSystemEnvironment() {
		let systemEnv = ProcessInfo.processInfo.environment
		for (key, value) in systemEnv {
			environmentVariables[key] = value
		}
	}

	/// Parse environment file content
	private func parseEnvironmentContent(_ content: String) {
		let lines = content.components(separatedBy: .newlines)

		for line in lines {
			let trimmedLine = line.trimmingCharacters(in: .whitespaces)

			// Skip empty lines and comments
			if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
				continue
			}

			// Parse KEY=VALUE format
			let components = trimmedLine.components(separatedBy: "=")
			guard components.count >= 2 else { continue }

			let key = components[0].trimmingCharacters(in: .whitespaces)
			let value = components.dropFirst().joined(separator: "=").trimmingCharacters(
				in: .whitespaces)

			// Remove quotes if present
			let cleanValue = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

			environmentVariables[key] = cleanValue
		}
	}

	/// Get environment variable value
	func getValue(for key: String, fallback: String? = nil) -> String? {
		return environmentVariables[key] ?? fallback
	}

	/// Get required environment variable (throws if not found)
	func getRequiredValue(for key: String) throws -> String {
		guard let value = environmentVariables[key], !value.isEmpty else {
			throw EnvironmentError.missingRequiredVariable(key)
		}
		return value
	}

	/// Check if running in debug mode
	var isDebug: Bool {
		#if DEBUG
			return true
		#else
			return false
		#endif
	}

	/// Get current environment (development, staging, production)
	var currentEnvironment: EnvironmentType {
		let envString = getValue(for: "ENVIRONMENT", fallback: "development") ?? "development"
		return EnvironmentType(rawValue: envString.lowercased()) ?? .development
	}

	private func printLoadedEnvironment() {
		print("🌍 Environment Manager - Loaded Variables:")
		print("📱 Environment: \(currentEnvironment.rawValue)")

		// Only print non-sensitive info
		let safeKeys = ["CAR_PARK_BASE_URL", "SUPABASE_URL", "ENVIRONMENT"]
		for key in safeKeys {
			if let value = environmentVariables[key] {
				print("🔧 \(key): \(value)")
			}
		}

		// Print sensitive keys with masked values
		let sensitiveKeys = ["TFNSW_API_KEY", "SUPABASE_PUBLISHABLE_KEY"]
		for key in sensitiveKeys {
			if let value = environmentVariables[key] {
				let maskedValue = String(value.prefix(4)) + "***"
				print("🔐 \(key): \(maskedValue)")
			}
		}
	}
}

// MARK: - Supporting Types

enum EnvironmentType: String, CaseIterable {
	case development = "development"
	case staging = "staging"
	case production = "production"

	var displayName: String {
		switch self {
		case .development: return "Development"
		case .staging: return "Staging"
		case .production: return "Production"
		}
	}
}

enum EnvironmentError: LocalizedError {
	case missingRequiredVariable(String)

	var errorDescription: String? {
		switch self {
		case .missingRequiredVariable(let key):
			return "Required environment variable '\(key)' is missing or empty"
		}
	}
}
