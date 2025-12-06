//
//  FacilityDetailView.swift
//  MetroParking
//
//  Created by Tom Kwok on 5/12/2025.
//

import SwiftUI
import Foundation

struct FacilityDetailView: View {
	var facility: ParkingFacility

	var body: some View {
		Text(facility.displayName)
	}
}

#Preview("Available Facility") {
	FacilityDetailView(facility: PreviewHelper.availableFacility())
		.modelContainer(PreviewHelper.previewContainer(withSamplePins: true))
}

#Preview("Almost Full Facility") {
	FacilityDetailView(facility: PreviewHelper.almostFullFacility())
		.modelContainer(PreviewHelper.previewContainer(withSamplePins: true))
}

#Preview("Full Facility") {
	FacilityDetailView(facility: PreviewHelper.fullFacility())
		.modelContainer(PreviewHelper.previewContainer(withSamplePins: true))
}

#Preview("No Data Facility") {
	FacilityDetailView(facility: PreviewHelper.noDataFacility())
		.modelContainer(PreviewHelper.previewContainer(withSamplePins: true))
}
