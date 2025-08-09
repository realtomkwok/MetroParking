//
//  ParkingTrendChart.swift
//  MetroParking
//
//  Created by Tom Kwok on 4/8/2025.
//

import Charts
import SwiftUI

struct ParkingTrendChart: View {
	@StateObject private var dataService = ParkingTrendService()
	let facilityId: String

	var maxOccupancy: Double {
		guard !hourlyData.isEmpty else { return 1.0 }
		return hourlyData.map(\.avgOccupancyRate).max() ?? 1.0
	}

	var adaptiveGradient: LinearGradient {
		let max = maxOccupancy

		// Determine end colour based on max occupancy
		let endColor: Color = {
			let progress = max
			if progress < 0.45 {
				return .green.mix(with: .yellow, by: progress / 0.45)
			} else if progress < 0.90 {
				return .yellow.mix(with: .red, by: (progress - 0.45) / 0.45)
			} else {
				return .red.mix(with: .purple, by: (progress - 0.90) / 0.10)
			}
		}()

		return LinearGradient(
			colors: [.green, endColor],
			startPoint: .bottom,
			endPoint: .top
		)
	}

	var currentDayOfWeek: Int {
		Calendar.current.component(.weekday, from: Date())
	}

	/// Current hour for the indicator dot
	var currentHour: Int {
		Calendar.current.component(.hour, from: Date())
	}

	var hourlyData: [HourlyPattern] {
		let patterns = dataService.hourlyPatterns
		guard !patterns.isEmpty else { return [] }

		let groupedByHour = Dictionary(
			grouping: patterns,
			by: { $0.hour }
		)

		return (0..<24).map { hour in
			if let hourPatterns = groupedByHour[hour], !hourPatterns.isEmpty {
				let avgOccupancy =
					hourPatterns.reduce(0.0) { $0 + $1.avgOccupancyRate }
					/ Double(hourPatterns.count)
				let totalSamples = hourPatterns.reduce(0) {
					$0 + $1.sampleCount
				}

				return HourlyPattern(
					facilityId: facilityId,
					dayOfWeek: currentDayOfWeek,
					hour: hour,
					avgOccupancyRate: avgOccupancy,
					sampleCount: totalSamples
				)
			} else {
				// No data for this hour
				return HourlyPattern(
					facilityId: facilityId,
					dayOfWeek: currentDayOfWeek,
					hour: hour,
					avgOccupancyRate: 0.0,
					sampleCount: 0
				)
			}
		}
	}

	var body: some View {
		VStack {
			Chart {
				// Single AreaMark with unified gradient
				ForEach(hourlyData, id: \.hour) { pattern in
					AreaMark(
						x: .value("Hour", pattern.hour),
						y: .value("Occupancy", pattern.avgOccupancyRate)
					)
					.foregroundStyle(adaptiveGradient.opacity(0.6))
					.interpolationMethod(.catmullRom)
				}

				// Line with same gradient mask
				ForEach(hourlyData, id: \.hour) { pattern in
					LineMark(
						x: .value("Hour", pattern.hour),
						y: .value("Occupancy", pattern.avgOccupancyRate)
					)
					.foregroundStyle(adaptiveGradient)
					.lineStyle(StrokeStyle(lineWidth: 3))
					.interpolationMethod(.catmullRom)
				}

				// Current time indicator
				if let currentData = hourlyData.first(where: {
					$0.hour == currentHour
				}) {
					PointMark(
						x: .value("Hour", currentHour),
						y: .value("Occupancy", currentData.avgOccupancyRate)
					)
					.foregroundStyle(.thinMaterial)
					.symbolSize(80)
				}
			}
			.frame(height: 200)
			.chartYScale(domain: 0...1.1)
			.chartXAxis {
				AxisMarks(values: [0, 6, 12, 18]) { value in
					AxisValueLabel {
						if let hour = value.as(Int.self) {
							Text(formatHour(hour))
								.font(.caption)
								.foregroundStyle(.secondary)
						}
					}
				}
			}
			.chartYAxis {
				AxisMarks(values: [0, 0.2, 0.4, 0.6, 0.8, 1.0]) { value in
					AxisValueLabel {
						if let occupancy = value.as(Double.self) {
							Text("\(Int(occupancy * 100))%")
								.font(.caption2)
								.foregroundStyle(.secondary)
						}
					}
				}
			}
		}
		.task {
			await dataService.fetchData(facilityId: facilityId)
			print(hourlyData)
		}
	}
}

/// Helpers
extension ParkingTrendChart {

	private func formatHour(_ hour: Int) -> String {
		let formatter = DateFormatter()
		formatter.dateFormat = DateFormatter.dateFormat(
			fromTemplate: "j",
			options: 0,
			locale: Locale.current
		)

		let calendar = Calendar.current
		let date =
			calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date())
			?? Date()

		formatter.dateFormat = formatter.dateFormat?.replacingOccurrences(
			of: "mm",
			with: ""
		)
		.replacingOccurrences(of: ":ss", with: "")
		.trimmingCharacters(in: .punctuationCharacters)

		return formatter.string(from: date)
	}
}

#Preview {
	ParkingTrendChart(facilityId: "9")
}
