//
//  APIRateLimitTester.swift
//  MetroParking
//
//  Test API rate limits to find optimal settings
//

import Foundation

class APIRateLimitTester {

	// Test facility IDs that are known to work
	private static let testFacilityIds = ["17", "22", "33", "16", "8"]

	/// Quick comprehensive test to find optimal settings
	static func findOptimalSettings() async -> (
		interval: TimeInterval, concurrency: Int
	) {
		print("🧪 Starting comprehensive rate limit test...")

		// Test 1: Find burst capacity (how many requests before rate limiting)
		let burstCapacity = await findBurstCapacity()
		print("📊 Burst capacity: \(burstCapacity) requests")

		// Test 2: Find minimum safe interval using binary search
		let optimalInterval = await findOptimalInterval(targetSuccessRate: 0.95)
		print("⏱️ Optimal interval: \(optimalInterval)s")

		// Test 3: Test concurrency at optimal interval
		let optimalConcurrency = await findOptimalConcurrency(
			interval: optimalInterval
		)
		print("🔄 Optimal concurrency: \(optimalConcurrency)")

		print(
			"🎯 Recommended settings: \(optimalInterval)s interval, \(optimalConcurrency) concurrency"
		)
		return (optimalInterval, optimalConcurrency)
	}

	/// Quick burst test to see immediate rate limit
	static func quickBurstTest() async {
		print("⚡ Quick burst test (10 rapid requests)...")

		let startTime = Date()
		var successCount = 0

		for i in 1...10 {
			let facilityId = testFacilityIds[i % testFacilityIds.count]

			do {
				_ = try await ParkingAPIService.shared.fetchFacility(
					id: facilityId
				)
				successCount += 1
				print("   ✅ \(i)/10")
			} catch {
				print("   ❌ \(i)/10: Rate limited")
				break
			}
		}

		let duration = Date().timeIntervalSince(startTime)
		print(
			"📊 Success: \(successCount)/10 in \(String(format: "%.1f", duration))s"
		)
		print(
			"📊 Rate: \(String(format: "%.1f", Double(successCount)/duration)) requests/second"
		)
	}

	// MARK: - Private Test Methods

	private static func findBurstCapacity() async -> Int {
		var capacity = 0

		for i in 1...20 {
			let facilityId = testFacilityIds[i % testFacilityIds.count]

			do {
				_ = try await ParkingAPIService.shared.fetchFacility(
					id: facilityId
				)
				capacity = i
			} catch {
				break
			}
		}

		// Wait 10 seconds for rate limit to reset
		print("⏸️ Waiting 10s for rate limit reset...")
		try? await Task.sleep(nanoseconds: 10_000_000_000)

		return capacity
	}

	private static func findOptimalInterval(targetSuccessRate: Double) async
		-> TimeInterval
	{
		var low: TimeInterval = 0.1
		var high: TimeInterval = 5.0
		var optimal: TimeInterval = high

		print("🔍 Binary search for optimal interval...")

		while high - low > 0.1 {
			let mid = (low + high) / 2
			let successRate = await testInterval(mid, requestCount: 8)

			print(
				"   Testing \(String(format: "%.1f", mid))s: \(String(format: "%.0f", successRate * 100))% success"
			)

			if successRate >= targetSuccessRate {
				optimal = mid
				high = mid
			} else {
				low = mid + 0.1
			}
		}

		return optimal
	}

	private static func findOptimalConcurrency(interval: TimeInterval) async
		-> Int
	{
		print("🔄 Testing concurrency levels...")

		for concurrency in [1, 2, 3] {
			let successRate = await testConcurrency(
				concurrency,
				interval: interval
			)
			print(
				"   Concurrency \(concurrency): \(String(format: "%.0f", successRate * 100))% success"
			)

			if successRate < 0.9 {
				return max(1, concurrency - 1)
			}
		}

		return 1  // Conservative fallback
	}

	private static func testInterval(
		_ interval: TimeInterval,
		requestCount: Int
	) async -> Double {
		var successCount = 0

		for i in 0..<requestCount {
			let facilityId = testFacilityIds[i % testFacilityIds.count]

			do {
				_ = try await ParkingAPIService.shared.fetchFacility(
					id: facilityId
				)
				successCount += 1
			} catch {
				// Fail silently for testing
			}

			if i < requestCount - 1 {
				try? await Task.sleep(
					nanoseconds: UInt64(interval * 1_000_000_000)
				)
			}
		}

		return Double(successCount) / Double(requestCount)
	}

	private static func testConcurrency(
		_ concurrency: Int,
		interval: TimeInterval
	) async -> Double {
		let semaphore = AsyncSemaphore(value: concurrency)
		var successCount = 0
		let totalRequests = 6

		await withTaskGroup(of: Bool.self) { group in
			for i in 0..<totalRequests {
				group.addTask {
					await semaphore.wait()

					let facilityId = testFacilityIds[i % testFacilityIds.count]
					var success = false

					do {
						_ = try await ParkingAPIService.shared.fetchFacility(
							id: facilityId
						)
						success = true
					} catch {
						// Fail silently
					}

					try? await Task.sleep(
						nanoseconds: UInt64(interval * 1_000_000_000)
					)
					await semaphore.signal()

					return success
				}
			}

			for await success in group {
				if success { successCount += 1 }
			}
		}

		return Double(successCount) / Double(totalRequests)
	}
}

// Usage in your app for testing:
extension APIRateLimitTester {

	/// Add this to a debug menu or call manually
	static func runFullTest() async {
		print("🚀 Starting full API rate limit analysis...")

		await quickBurstTest()

		print(
			"""
			----------------------
			"""
		)

		let (interval, concurrency) = await findOptimalSettings()

		print("\n📋 RECOMMENDATION:")
		print("   minimumAPIInterval: \(interval)")
		print("   refreshConcurrencyLimit: \(concurrency)")
		print("   Expected success rate: >95%")
	}
}
