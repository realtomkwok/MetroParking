//
//  FormatHourHelper.swift
//  MetroParking
//
//  Created by Tom Kwok on 10/8/2025.
//

import Foundation

enum TimeFormatStyle {
	/// Travel time styles
	case abbreviated
	/// "5 min", "1h 30m"
	case short
	/// "5 min", "1 hr, 30 min"
	case full
	/// "5 minutes", "1 hour, 30 minutes"
	case compact
	/// "5m", "1:30"
	case contextual
	/// Formatting based on duration

	/// Hour/clock time styles
	case hourOnly
	/// "9 AM", "14:00"
	case timeShort
	/// "9:30 AM", "14:30"
	case timeMedium
	/// "9:30:00 AM", "14:30:00"

	/// Relative time styles
	case relative
	/// "in 5 minutes", "2 hours ago"
	case relativeShort
	/// "5m", "2h ago"

	var dateComponentsUnitsStyle: DateComponentsFormatter.UnitsStyle {
		switch self {
		case .abbreviated, .contextual:
			return .abbreviated
		case .short: return .short
		case .full: return .full
		case .compact: return .positional
		case .relativeShort: return .abbreviated
		default:
			return .abbreviated
		}
	}
}

class TimeFormatter {

	static let shared = TimeFormatter()

	/// Private Formatters (cached for performance)
	private let dateComponentsFormatter: DateComponentsFormatter
	private let dateFormatter: DateFormatter
	private let relativeDateFormatter: RelativeDateTimeFormatter

	private init() {
		self.dateComponentsFormatter = DateComponentsFormatter()
		self.dateFormatter = DateFormatter()
		self.relativeDateFormatter = RelativeDateTimeFormatter()
	}

	func formatTravelTime(
		_ timeInterval: TimeInterval,
		style: TimeFormatStyle = .abbreviated,
		includeSeconds: Bool = false
	) -> String {

		switch style {
		case .compact:
			return formatCompactDuration(timeInterval)

		case .contextual:
			return formatContextualDuration(timeInterval)

		case .relative, .relativeShort:
			return formatRelativeDuration(timeInterval, style: style)

		default:
			return formatStandardDuration(
				timeInterval,
				style: style,
				includeSeconds: includeSeconds
			)
		}
	}

	/// Hour Formatting
	func formatHour(_ hour: Int, style: TimeFormatStyle = .hourOnly) -> String {
		let calendar = Calendar.current
		let date =
			calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date())
			?? Date()

		switch style {
		case .hourOnly:
			if #available(iOS 15.0, *) {
				return date.formatted(
					.dateTime.hour(.defaultDigits(amPM: .abbreviated))
				)
			} else {
				dateFormatter.dateStyle = .none
				dateFormatter.timeStyle = .short
				let timeString = dateFormatter.string(from: date)
				// Extract just the hour part
				return String(timeString.prefix(while: { $0 != ":" }))
					+ (timeString.contains("AM") || timeString.contains("PM")
						? (timeString.contains("AM") ? " AM" : " PM") : "")
			}

		case .timeShort:
			if #available(iOS 15.0, *) {
				return date.formatted(
					.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute()
				)
			} else {
				dateFormatter.dateStyle = .none
				dateFormatter.timeStyle = .short
				return dateFormatter.string(from: date)
			}

		case .timeMedium:
			if #available(iOS 15.0, *) {
				return date.formatted(
					.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute()
						.second()
				)
			} else {
				dateFormatter.dateStyle = .none
				dateFormatter.timeStyle = .medium
				return dateFormatter.string(from: date)
			}

		default:
			return formatHour(hour, style: .hourOnly)
		}
	}

	/// Relative time formatting
	func formatRelativeTime(
		from date: Date,
		to referenceDate: Date = Date(),
		style: TimeFormatStyle = .relative
	) -> String {

		switch style {
		case .relativeShort:
			relativeDateFormatter.unitsStyle = .abbreviated
		default:
			relativeDateFormatter.unitsStyle = .full
		}

		return relativeDateFormatter.localizedString(
			for: date,
			relativeTo: referenceDate
		)
	}

	/// Frequently-used methods
	/// Format time until/since with automatic direction
	func formatTimeForNow(_ date: Date, style: TimeFormatStyle = .relative)
		-> String
	{
		return formatRelativeTime(from: date, style: style)
	}

	/// Format age of data (always positive, "ago" format
	func formatAge(since date: Date, style: TimeFormatStyle = .abbreviated)
		-> String
	{
		let formatter = RelativeDateTimeFormatter()
		formatter.locale = Locale.current
		formatter.unitsStyle = style == .relativeShort ? .abbreviated : .full

		return formatter.localizedString(for: date, relativeTo: Date())
	}

	/// Format future of data, e.g. ETA (always positive, "in" format)
	func formatETA(
		in timeInterval: TimeInterval,
		style: TimeFormatStyle = .abbreviated
	) -> String {
		let futureDate = Date().addingTimeInterval(timeInterval)
		let formatter = RelativeDateTimeFormatter()
		formatter.locale = Locale.current
		formatter.unitsStyle = style == .relativeShort ? .abbreviated : .full

		return formatter.localizedString(for: futureDate, relativeTo: Date())
	}
}

/// Private methods
extension TimeFormatter {

	private func formatStandardDuration(
		_ timeInterval: TimeInterval,
		style: TimeFormatStyle,
		includeSeconds: Bool
	) -> String {
		let allowedUnits: NSCalendar.Unit

		if includeSeconds && timeInterval < 60 {
			allowedUnits = [.hour, .minute, .second]
		} else if timeInterval < 60 {
			/// Less than 1 minute
			allowedUnits = [.second]
			dateComponentsFormatter.allowedUnits = allowedUnits
			dateComponentsFormatter.unitsStyle = style.dateComponentsUnitsStyle
			return dateComponentsFormatter.string(from: timeInterval)
				?? String(localized: "time.lessThanMinute")
		} else {
			allowedUnits = [.hour, .minute]
		}

		dateComponentsFormatter.allowedUnits = allowedUnits
		dateComponentsFormatter.unitsStyle = style.dateComponentsUnitsStyle
		dateComponentsFormatter.maximumUnitCount = includeSeconds ? 3 : 2

		/// If failed
		return dateComponentsFormatter.string(from: timeInterval)
			?? String(localized: "time.unknown")
	}

	private func formatCompactDuration(_ timeInterval: TimeInterval)
		-> String
	{
		dateComponentsFormatter.allowedUnits = [.hour, .minute]
		dateComponentsFormatter.unitsStyle = .positional
		dateComponentsFormatter.zeroFormattingBehavior = .dropLeading

		/// If failed
		return dateComponentsFormatter.string(from: timeInterval)
			?? String(localized: "time.zeroDuration")
	}

	private func formatContextualDuration(_ timeInterval: TimeInterval)
		-> String
	{
		/// Less than an hour
		if timeInterval < 3600 {
			dateComponentsFormatter.allowedUnits = [.minute]
			dateComponentsFormatter.unitsStyle = .abbreviated
		} else {
			dateComponentsFormatter.allowedUnits = [.hour, .minute]
			dateComponentsFormatter.unitsStyle = .abbreviated
			dateComponentsFormatter.maximumUnitCount = 2
		}

		/// If failed
		return dateComponentsFormatter.string(from: timeInterval)
			?? String(localized: "time.unknown")
	}

	private func formatRelativeDuration(
		_ timeInterval: TimeInterval,
		style: TimeFormatStyle
	) -> String {
		let futureDate = Date().addingTimeInterval(timeInterval)
		return formatRelativeTime(from: futureDate, style: style)
	}
}

extension TimeFormatter {

	/// Multiple format variants at once
	func formatTravelTimeVariants(_ timeInterval: TimeInterval) -> (
		abbreviated: String,
		short: String,
		full: String,
		compact: String
	) {
		return (
			abbreviated: formatTravelTime(timeInterval, style: .abbreviated),
			short: formatTravelTime(timeInterval, style: .short),
			full: formatTravelTime(timeInterval, style: .full),
			compact: formatTravelTime(timeInterval, style: .compact)
		)
	}

	/// Adaptive formatting based on available space
	func formatTravelTimeAdaptive(
		_ timeInterval: TimeInterval,
		maxWidth: CGFloat
	) -> String {
		switch maxWidth {
		case ..<60: return formatTravelTime(timeInterval, style: .compact)
		case ..<100: return formatTravelTime(timeInterval, style: .abbreviated)
		default: return formatTravelTime(timeInterval, style: .short)
		}
	}
}

/// Quick static access for common formatting
extension TimeFormatter {

	static func hour(_ hour: Int) -> String {
		return shared.formatHour(hour)
	}

	static func travelTime(
		_ timeInterval: TimeInterval,
		style: TimeFormatStyle = .abbreviated
	) -> String {
		return shared.formatTravelTime(timeInterval, style: style)
	}

	static func age(since date: Date) -> String {
		return shared.formatAge(since: date)
	}

	static func eta(in timeInterval: TimeInterval) -> String {
		return shared.formatETA(in: timeInterval)
	}

	static func relativeTime(from date: Date) -> String {
		return shared.formatRelativeTime(from: date)
	}
}


protocol TimeFormattable {
	var timeInterval: TimeInterval { get }
}

extension TimeFormattable {
	func formatted(style: TimeFormatStyle = .abbreviated) -> String {
		return TimeFormatter.shared.formatTravelTime(timeInterval, style: style)
	}
}
