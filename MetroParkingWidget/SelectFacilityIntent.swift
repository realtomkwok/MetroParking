//
//  SelectFacilityIntent.swift
//  MetroParking
//
//  Created by Tom Kwok on 17/12/2025.
//

import AppIntents
import Foundation

struct SelectFacilityIntent: WidgetConfigurationIntent {

	static var title: LocalizedStringResource = "Select Facility"
	static var description = IntentDescription("Select the parking facility to display on the widget")

	@Parameter(title: "Parking Facility")
	var facility: FacilityEntity?

	init(facility: FacilityEntity? = nil) {
		self.facility = facility
	}

	init() {
		self.facility = nil
	}
}
