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
		isPlaceholder: false,
		isStale: false,
		configuration: FocusedFacilityWidgetConfigs()
	)
}


#Preview("Small - Almost Full", as: .systemSmall) {
	FacilityWidget()
} timeline: {
	FacilityEntry(
		date: Date(),
		facilityData: .sample(status: .almostFull),
		isPlaceholder: false,
		isStale: false,
		configuration: FocusedFacilityWidgetConfigs()
	)
}

#Preview("Small - Full", as: .systemSmall) {
	FacilityWidget()
} timeline: {
	FacilityEntry(
		date: Date(),
		facilityData: .sample(status: .full),
		isPlaceholder: false,
		isStale: false,
		configuration: FocusedFacilityWidgetConfigs()
	)
}

#Preview("Small - No data", as: .systemSmall) {
	FacilityWidget()
} timeline: {
	FacilityEntry(
		date: Date(),
		facilityData: .sample(status: .noData),
		isPlaceholder: false,
		isStale: false,
		configuration: FocusedFacilityWidgetConfigs()
	)
}

#Preview("Small - Stale Data", as: .systemSmall) {
	FacilityWidget()
} timeline: {
	FacilityEntry(
		date: Date(),
		facilityData: .sample(status: .available),
		isPlaceholder: false,
		isStale: true,
		configuration: FocusedFacilityWidgetConfigs()
	)
}

#Preview("Empty State", as: .systemSmall) {
	FacilityWidget()
} timeline: {
	FacilityEntry(
		date: Date(),
		facilityData: nil,
		isPlaceholder: false,
		isStale: false,
		configuration: FocusedFacilityWidgetConfigs()
	)
}
