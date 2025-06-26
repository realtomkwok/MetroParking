//
//  ParkingDetailView.swift
//  MetroParking
//
//  Created by Tom Kwok on 26/6/2025.
//

import SwiftUI
import SwiftData

struct FacilityDetailView: View {
	let facility: ParkingFacility
	@Environment(\.modelContext) private var modelContext
	
	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text(facility.name)
				.font(.largeTitle)
				.fontWeight(.bold)
			
			Text("\(facility.suburb), \(facility.address)")
				.font(.subheadline)
				.foregroundColor(.secondary)
			
			Text("Total Spaces: \(facility.totalSpaces)")
				.font(.headline)
			
			if let lastVisited = facility.lastVisited {
				Text("Last visited: \(lastVisited, format: .dateTime)")
					.font(.caption)
					.foregroundColor(.secondary)
			}
			
			Spacer()
		}
		.padding()
		.navigationTitle("Facility Details")
		.navigationBarTitleDisplayMode(.inline)
		.onAppear {
			facility.markAsVisited()
			try? modelContext.save()
		}
	}
}

#Preview {
	FacilityDetailView(facility: PreviewHelper.availableFacility())
}
