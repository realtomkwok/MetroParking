//
//  RemovingPrefix.swift
//  MetroParking
//
//  Created by Tom Kwok on 26/6/2025.
//

extension String {
	func removePrefix(_ prefix: String) -> String {
		guard self.hasPrefix(prefix) else { return self }
		return String(self.dropFirst(prefix.count))
	}
}
