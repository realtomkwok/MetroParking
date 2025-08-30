//
//  RateLimiter.swift
//  MetroParking
//
//  Created by Tom Kwok on 29/8/2025.
//

import Foundation

class RateLimiter {
    private var lastRequestedTime: Date = .distantPast
    private var minInterval: TimeInterval

    init(minInterval: TimeInterval = 0.3) {
        self.minInterval = minInterval
    }

    func waitIfNeeded() async {
        let elapsed = Date().timeIntervalSince(lastRequestedTime)
        if elapsed < minInterval {
            try ? await Task.sleep(
                nanoseconds: UInt64((minInterval - elapsed) * 1_000_000_000)
            )
        }
        lastRequestedTime = Date()
    }
}
