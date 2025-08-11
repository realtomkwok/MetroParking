//
//  FormatHourHelper.swift
//  MetroParking
//
//  Created by Tom Kwok on 10/8/2025.
//

import Foundation

extension Date {
	static func formatHour(_ hour: Int) -> String {
		let calendar = Calendar.current
		let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
		
		if #available(iOS 15.0, *) {
			return date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
		} else {
			let formatter = DateFormatter()
			formatter.dateStyle = .none
			formatter.timeStyle = .short
			return formatter.string(from: date)
		}
	}
}
