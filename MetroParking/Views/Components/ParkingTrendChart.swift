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

	@State private var selectedDatePoint: HourlyPattern?
	@State private var dragLocation: CGPoint = .zero
	@State private var chartFrame: CGRect = .zero
	@State private var isInteracting: Bool = false

	var maxOccupancy: Double {
		guard !hourlyData.isEmpty else { return 1.0 }
		return hourlyData.map(\.avgOccupancyRate).max() ?? 1.0
	}

	var medianOccupancy: Double {
		guard !hourlyData.isEmpty else { return 0.5 }
		return hourlyData.reduce(0) {
			$0 + $1.avgOccupancyRate
		}
	}

	var averageOccupancy: Double {
		guard !hourlyData.isEmpty else { return 0.5 }

		let sum = hourlyData.reduce(0.0) { $0 + $1.avgOccupancyRate }
		return sum / Double(hourlyData.count)
	}

	var adaptiveGradient: LinearGradient {
		let max = maxOccupancy
		let avg = averageOccupancy

		let middleColour: Color = {
			let progress = avg

			if (0.45..<0.9).contains(avg) {
				return .yellow.mix(with: .red, by: progress - 0.45)
			} else {
				return .green.mix(with: .yellow, by: progress / 0.45)
			}
		}()

		// Determine end colour based on max occupancy
		let endColour: Color = {
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
			colors: [.green, middleColour, endColour],
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
			HStack {
				if !isInteracting,
					let currentData = hourlyData.first(where: {
						$0.hour == currentHour
					})
				{
					VStack(alignment: .leading) {
						Text("Current")
							.font(.subheadline)
							.fontWeight(.medium)
							.textCase(.uppercase)
							.foregroundStyle(.secondary)
						HStack(alignment: .lastTextBaseline, spacing: 2) {
							Text("\(Int(currentData.avgOccupancyRate * 100))")
								.font(.largeTitle)
							Text("%")
								.font(.headline)
								.fontWeight(.medium)
								.foregroundStyle(.secondary)
						}
					}
					Spacer()
				}
			}
			.frame(minHeight: 64)

			ZStack {
				Chart {
					ForEach(hourlyData, id: \.hour) { pattern in
						AreaMark(
							x: .value("Hour", pattern.hour),
							y: .value("Occupancy", pattern.avgOccupancyRate)
						)
						.foregroundStyle(adaptiveGradient.opacity(0.4))
						.interpolationMethod(.monotone)
					}

					ForEach(hourlyData, id: \.hour) { pattern in
						LineMark(
							x: .value("Hour", pattern.hour),
							y: .value("Occupancy", pattern.avgOccupancyRate)
						)
						.foregroundStyle(adaptiveGradient)
						.lineStyle(StrokeStyle(lineWidth: 3))
						.interpolationMethod(.monotone)
					}

					/// Selection indicator
					if let selected = selectedDatePoint {
						RuleMark(x: .value("Hour", selected.hour))
							.foregroundStyle(.separator)
							.lineStyle(StrokeStyle(lineWidth: 2))

						PointMark(
							x: .value("Hour", selected.hour),
							y: .value("Occupancy", selected.avgOccupancyRate)
						)
						.foregroundStyle(.ultraThinMaterial)
						.symbolSize(100)

					} else /// Show the current time indicator
					if let currentData = hourlyData.first(where: {
						$0.hour == currentHour
					}) {
						PointMark(
							x: .value("Hour", currentHour),
							y: .value("Occupancy", currentData.avgOccupancyRate)
						)
						.foregroundStyle(.thinMaterial)
						.symbolSize(80)

						PointMark(
							x: .value("Hour", currentHour),
							y: .value("Occupancy", currentData.avgOccupancyRate)
						)
						.foregroundStyle(.placeholder)
						.symbolSize(40)
					}
				}
				.frame(height: 200)
				.chartYScale(domain: 0...1.1)
				.chartXAxis {
					AxisMarks(values: [0, 6, 12, 18]) { value in
						AxisValueLabel {
							if let hour = value.as(Int.self) {
								Text(TimeFormatter.hour(hour))
									.font(.caption)
									.foregroundStyle(.primary)
							}
						}
					}
					AxisMarks(values: [0, 3, 6, 9, 12, 15, 18, 21]) { value in
						AxisGridLine()
					}
				}
				.chartYAxis {
					AxisMarks(values: [0, 0.5, 1]) { value in
						AxisValueLabel {
							if let occupancy = value.as(Double.self) {
								Text("\(Int(occupancy * 100))%")
									.font(.caption2)
									.foregroundStyle(.primary)
							}
						}
					}
					AxisMarks(values: [0, 0.25, 0.5, 0.75, 1]) { value in
						AxisGridLine()
					}
				}
				.chartGesture {
					chartProxy in
					DragGesture(minimumDistance: 0)
						.onChanged { value in
							isInteracting = true
							dragLocation = value.location

							/// Convert screen location to data point
							if let hour: Double = chartProxy.value(
								atX: value.location.x
							) {
								let nearestHour = Int(hour.rounded())
								selectedDatePoint = hourlyData.first {
									$0.hour == nearestHour
								}
							}
						}
						.onEnded { _ in
							withAnimation(.snappy(duration: 0.3)) {
								isInteracting = false
								selectedDatePoint = nil
							}
						}
				}
				.background(
					GeometryReader { proxy in
						Color.clear
							.onAppear {
								chartFrame = proxy.frame(in: .local)
							}
					}
				)

				if isInteracting, let selected = selectedDatePoint {
					ChartTooltipView(
						hour: selected.hour,
						occupancy: selected.avgOccupancyRate,
						occupancyStatus: selected.occupancyStatus
					)
					.position(
						x: max(20, min(dragLocation.x, chartFrame.width - 20)),
						y: chartFrame.minY - 40  // Offset above finger
					)
					.transition(.opacity.combined(with: .blurReplace))

				}

			}
		}
		.task {
			await dataService.fetchData(facilityId: facilityId)
		}
	}
}

struct ChartTooltipView: View {
	let hour: Int
	let occupancy: Double
	let occupancyStatus: String

	var body: some View {
		VStack(alignment: .leading) {
			Text(TimeFormatter.hour(hour))
				.font(.subheadline)
				.foregroundStyle(.secondary)

			HStack(alignment: .lastTextBaseline, spacing: 2) {
				Text("\(Int(occupancy * 100))")
					.font(.largeTitle)
				Text("%")
					.font(.headline)
					.foregroundStyle(.secondary)

			}
			Text(occupancyStatus)
				.font(.headline)
		}
		.frame(minWidth: 72, alignment: .leading)
		.padding(.horizontal, 12)
		.padding(.vertical, 8)
		.background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 24))
	}
}

#Preview {
	ParkingTrendChart(facilityId: "30")
		.frame(height: 200)
}
