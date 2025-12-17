//
//  MetroParkingWidgetBundle.swift
//  MetroParkingWidget
//
//  Created by Tom Kwok on 16/12/2025.
//

import WidgetKit
import SwiftUI

@main
struct MetroParkingWidgetBundle: WidgetBundle {
	var body: some Widget {
		FacilityWidget()
	}
}

#Preview("Small - Available", as: .systemSmall) {
	FacilityWidget()
} timeline: {
	FacilityEntry(
		date: Date(),
		facilityData: .sample(status: .available),
		isPlaceholder: false
	)
}


#Preview("Small - Almost Full", as: .systemSmall) {
	FacilityWidget()
} timeline: {
	FacilityEntry(
		date: Date(),
		facilityData: .sample(status: .almostFull),
		isPlaceholder: false
	)
}

#Preview("Small - Full", as: .systemSmall) {
	FacilityWidget()
} timeline: {
	FacilityEntry(
		date: Date(),
		facilityData: .sample(status: .full),
		isPlaceholder: false
	)
}

#Preview("Small - No data", as: .systemSmall) {
	FacilityWidget()
} timeline: {
	FacilityEntry(
		date: Date(),
		facilityData: .sample(status: .noData),
		isPlaceholder: false
	)
}
