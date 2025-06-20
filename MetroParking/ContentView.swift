//
//  ContentView.swift
//  MetroParking
//
//  Created by Tom Kwok on 18/5/2025.
//

import SwiftUI

struct ContentView: View {
	@State private var isLoading = false
	@State private var facilities: [FacilityID: FacilityName] = [:]
	@State private var errorMessage: String?
	
	var body: some View {
		NavigationView {
			VStack {
					// Test button
				Button(action: fetchFacilities) {
					HStack {
						if isLoading {
							ProgressView()
								.scaleEffect(0.8)
						}
						Text(isLoading ? "Loading..." : "Load Facilities")
					}
					.foregroundColor(.white)
					.padding()
					.background(Color.blue)
					.cornerRadius(10)
				}
				.disabled(isLoading)
				.padding()
				
					// Error message
				if let error = errorMessage {
					Text("Error: \(error)")
						.foregroundColor(.red)
						.padding()
				}
				
					// Simple list showing dictionary data
				if !facilities.isEmpty {
					Text("Found \(facilities.count) facilities:")
						.font(.headline)
						.padding()
					
					List(facilities.sorted(by: { $0.key < $1.key }), id: \.key) { facilityId, facilityName in
						VStack(alignment: .leading) {
							Text(facilityName)
								.font(.headline)
								.foregroundColor(facilityName.contains("Cherrybrook") ? .green : .primary)
							Text("ID: \(facilityId)")
								.font(.caption)
								.foregroundColor(.secondary)
						}
						.padding(.vertical, 2)
					}
				} else if !isLoading {
					Text("Tap the button to load facilities")
						.foregroundColor(.secondary)
						.padding()
					
					Spacer()
				}
			}
			.navigationTitle("Facilities Test")
		}
	}
	
	private func fetchFacilities() {
		Task {
			isLoading = true
			errorMessage = nil
			
			do {
				print("🔍 Testing API configuration...")
				Configuration.printConfiguration()
				
				print("🌐 Calling API...")
				let result = try await ParkingAPIService.shared.fetchAllFacilities()
				
				await MainActor.run {
					self.facilities = result
					print("✅ Success! Got \(result.count) facilities")
					
						// Show first few in console
					for (id, name) in result.prefix(3) {
						print("- \(id): \(name)")
					}
					
						// Look for Cherrybrook
					if let cherrybrookEntry = result.first(where: { $0.value.contains("Cherrybrook") }) {
						print("🌳 Found Cherrybrook: ID \(cherrybrookEntry.key) = \(cherrybrookEntry.value)")
					}
				}
				
			} catch {
				await MainActor.run {
					self.errorMessage = error.localizedDescription
					print("❌ Error: \(error)")
				}
			}
			
			isLoading = false
		}
	}
}

#Preview {
	ContentView()
}
