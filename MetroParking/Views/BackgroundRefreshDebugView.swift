//
//  BackgroundRefreshDebugView.swift
//  MetroParking
//
//  Created by Claude Code on 31/12/2025.
//
//  Debug view for monitoring background refresh activity on physical devices.
//  Shows scheduled tasks, last execution times, and allows manual triggering.

import BackgroundTasks
import SwiftUI
import OSLog

#if DEBUG
struct BackgroundRefreshDebugView: View {
	@State private var scheduledTasks: [BGTaskRequest] = []
	@State private var lastAppRefresh: Date?
	@State private var lastProcessingTask: Date?
	@State private var refreshLog: [String] = []
	@State private var isSimulator: Bool = false

	var body: some View {
		List {
			// Device Info
			Section("Device Status") {
				HStack {
					Text("Environment")
					Spacer()
					Text(isSimulator ? "Simulator" : "Physical Device")
						.foregroundStyle(isSimulator ? .red : .green)
				}

				if isSimulator {
					Label {
						Text("Background tasks require a physical device")
					} icon: {
						Image(systemName: "exclamationmark.triangle.fill")
							.foregroundStyle(.orange)
					}
					.font(.caption)
				}
			}

			// Scheduled Tasks
			Section("Scheduled Background Tasks") {
				if scheduledTasks.isEmpty {
					Text("No tasks scheduled")
						.foregroundStyle(.secondary)
				} else {
					ForEach(scheduledTasks, id: \.identifier) { task in
						VStack(alignment: .leading, spacing: 4) {
							Text(task.identifier)
								.font(.system(.caption, design: .monospaced))

							if let earliest = task.earliestBeginDate {
								Text("Scheduled for: \(earliest.formatted())")
									.font(.caption2)
									.foregroundStyle(.secondary)

								let timeUntil = earliest.timeIntervalSinceNow
								if timeUntil > 0 {
									Text("In \(formatTimeInterval(timeUntil))")
										.font(.caption2)
										.foregroundStyle(.blue)
								} else {
									Text("Due now")
										.font(.caption2)
										.foregroundStyle(.green)
								}
							}
						}
						.padding(.vertical, 4)
					}
				}

				Button("Refresh Task List") {
					loadScheduledTasks()
				}
			}

			// Last Execution Times
			Section("Last Execution") {
				HStack {
					Text("App Refresh")
					Spacer()
					if let date = lastAppRefresh {
						Text(date.formatted(.relative(presentation: .named)))
							.foregroundStyle(.secondary)
					} else {
						Text("Never")
							.foregroundStyle(.tertiary)
					}
				}

				HStack {
					Text("Processing Task")
					Spacer()
					if let date = lastProcessingTask {
						Text(date.formatted(.relative(presentation: .named)))
							.foregroundStyle(.secondary)
					} else {
						Text("Never")
							.foregroundStyle(.tertiary)
					}
				}
			}

			// Manual Controls
			Section("Manual Controls") {
				Button("Schedule App Refresh") {
					BackgroundTaskManager.shared.scheduleAppRefresh()
					addLog("Scheduled app refresh task")

					// Reload task list after short delay
					Task {
						try? await Task.sleep(for: .milliseconds(500))
						loadScheduledTasks()
					}
				}

				Button("Schedule Processing Task") {
					BackgroundTaskManager.shared.scheduleProcessingTask()
					addLog("Scheduled processing task")

					// Reload task list after short delay
					Task {
						try? await Task.sleep(for: .milliseconds(500))
						loadScheduledTasks()
					}
				}

				Button("Cancel All Tasks", role: .destructive) {
					BackgroundTaskManager.shared.cancelAllTasks()
					addLog("Cancelled all background tasks")

					// Reload task list after short delay
					Task {
						try? await Task.sleep(for: .milliseconds(500))
						loadScheduledTasks()
					}
				}
			}

			// Testing on Simulator
			if isSimulator {
				Section("Testing on Simulator") {
					Text("Background tasks don't run on simulator. Use Xcode to simulate:")
						.font(.caption)
						.foregroundStyle(.secondary)

					VStack(alignment: .leading, spacing: 8) {
						Text("1. Run app on device")
						Text("2. Put app in background")
						Text("3. In Xcode, go to Debug → Simulate Background Tasks → App Refresh")
						Text("4. Or use: e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@\"com.tomkwok.MetroParking.refresh\"]")
					}
					.font(.caption2)
					.foregroundStyle(.secondary)
				}
			}

			// Activity Log
			Section("Activity Log") {
				if refreshLog.isEmpty {
					Text("No activity yet")
						.foregroundStyle(.secondary)
				} else {
					ForEach(Array(refreshLog.enumerated().reversed()), id: \.offset) { _, log in
						Text(log)
							.font(.caption)
							.foregroundStyle(.secondary)
					}
				}

				if !refreshLog.isEmpty {
					Button("Clear Log") {
						refreshLog.removeAll()
					}
				}
			}

			// Instructions
			Section("How to Test Background Refresh") {
				VStack(alignment: .leading, spacing: 12) {
					InstructionRow(
						number: "1",
						title: "Set up widget",
						description: "Add MetroParking widget to home screen"
					)

					InstructionRow(
						number: "2",
						title: "Enable background refresh",
						description: "Settings → General → Background App Refresh → ON"
					)

					InstructionRow(
						number: "3",
						title: "Put app in background",
						description: "Press home button or swipe up"
					)

					InstructionRow(
						number: "4",
						title: "Wait 15-30 minutes",
						description: "iOS will execute background tasks when system resources allow"
					)

					InstructionRow(
						number: "5",
						title: "Check widget",
						description: "Widget should show updated data even when app is not open"
					)
				}
			}
		}
		.navigationTitle("Background Refresh")
		.navigationBarTitleDisplayMode(.inline)
		.onAppear {
			checkIfSimulator()
			loadScheduledTasks()
			loadLastExecutionTimes()
		}
	}

	// MARK: - Helper Views

	private struct InstructionRow: View {
		let number: String
		let title: String
		let description: String

		var body: some View {
			HStack(alignment: .top, spacing: 12) {
				Text(number)
					.font(.system(.title3, design: .rounded))
					.fontWeight(.bold)
					.foregroundStyle(.blue)
					.frame(width: 30)

				VStack(alignment: .leading, spacing: 4) {
					Text(title)
						.font(.subheadline)
						.fontWeight(.medium)
					Text(description)
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}
		}
	}

	// MARK: - Helper Methods

	private func checkIfSimulator() {
		#if targetEnvironment(simulator)
		isSimulator = true
		#else
		isSimulator = false
		#endif
	}

	private func loadScheduledTasks() {
		BGTaskScheduler.shared.getPendingTaskRequests { requests in
			DispatchQueue.main.async {
				self.scheduledTasks = requests
				addLog("Loaded \(requests.count) scheduled task(s)")
			}
		}
	}

	private func loadLastExecutionTimes() {
		// Load from UserDefaults if you track execution times
		// For now, these are placeholders
		lastAppRefresh = UserDefaults.standard.object(forKey: "lastAppRefresh") as? Date
		lastProcessingTask = UserDefaults.standard.object(forKey: "lastProcessingTask") as? Date
	}

	private func addLog(_ message: String) {
		let timestamp = Date().formatted(date: .omitted, time: .standard)
		refreshLog.append("[\(timestamp)] \(message)")

		// Keep only last 20 entries
		if refreshLog.count > 20 {
			refreshLog.removeFirst()
		}
	}

	private func formatTimeInterval(_ interval: TimeInterval) -> String {
		if interval < 60 {
			return "\(Int(interval))s"
		} else if interval < 3600 {
			return "\(Int(interval / 60))m"
		} else {
			let hours = Int(interval / 3600)
			let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
			return "\(hours)h \(minutes)m"
		}
	}
}

#Preview {
	NavigationStack {
		BackgroundRefreshDebugView()
	}
}
#endif
