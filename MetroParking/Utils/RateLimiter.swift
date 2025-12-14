//
//  RateLimiter.swift
//  MetroParking
//
//  Created by Tom Kwok on 29/8/2025.
//

import Foundation
import OSLog

/// Thread-safe rate limiter using actor for concurrent API calls
actor RateLimiter {
    private var lastRequestedTime: Date = .distantPast
    private let minInterval: TimeInterval

    init(minInterval: TimeInterval = 0.5) {
        self.minInterval = minInterval
    }

    /// Wait if needed to respect rate limit, then mark request time
    func waitIfNeeded() async {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastRequestedTime)
        
        if elapsed < minInterval {
            let waitTime = minInterval - elapsed
            Logger.api.debug("Rate limit: waiting \(String(format: "%.2f", waitTime))s")
            
            try? await Task.sleep(
                nanoseconds: UInt64(waitTime * 1_000_000_000)
            )
        }
        
        lastRequestedTime = Date()
    }
    
    /// Reset rate limiter state (useful for testing)
    func reset() {
        lastRequestedTime = .distantPast
    }
}
