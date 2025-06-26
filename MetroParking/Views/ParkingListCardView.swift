//
//  ParkingListCardView.swift
//  MetroParking
//
//  Created by Tom Kwok on 26/6/2025.
//

import SwiftUI

struct ParkingListCardView: View {
	let facility: ParkingFacility
	// TODO: Replace value with real distance
	let distance = Measurement(value: 5.2, unit: UnitLength.kilometers)
	
	var body: some View {
		NavigationLink(destination: FacilityDetailView(facility: facility)) {
			HStack(alignment: .top) {
				VStack(alignment: .leading) {
					VStack(alignment: .leading, spacing: 8) {
						Text("\(facility.displayName)")
							.font(.title2)
							.multilineTextAlignment(.leading)
							.lineLimit(2)
							.foregroundStyle(Color(.label))
					}
					
					Spacer(minLength: 32)
					
					VStack(alignment: .leading, spacing: 8) {
						HStack(alignment: .center) {
							Image(systemName: "point.bottomleft.filled.forward.to.point.topright.scurvepath")
							Text("\(distance.formatted()) away")
						}
						.foregroundStyle(Color(.secondaryLabel))
						
						// TODO: Update Indicator
						HStack {
							Image(systemName: "circlebadge.fill")
							Text("Live")
								.textCase(.uppercase)
						}
						.foregroundStyle(Color(.tertiaryLabel))
					}
				}
				
				Spacer(minLength: 48)
				
				VStack(alignment: .trailing) {
					VStack(alignment: .center, spacing: 0) {
						Text("\(facility.currentAvailableSpots)")
							.font(.largeTitle)
							.fontDesign(.rounded)
							.foregroundStyle(Color(.label))
						Text("spaces")
							.foregroundStyle(Color(.secondaryLabel))
					}
					
					Spacer()
					
					Text("\(facility.availablityStatus.text)")
						.font(.subheadline)
						.fontWeight(.semibold)
						.fontDesign(.rounded)
						.textCase(.uppercase)
						.padding(.horizontal, 8)
						.padding(.vertical, 4)
						.foregroundStyle(Color(.label))
						.background(facility.availablityStatus.color)
						.clipShape(RoundedRectangle(cornerRadius: 999))
				}
				


			}
			.buttonStyle(.plain)
			.frame(maxHeight: 160)
			.padding(20)
			.background(.thinMaterial)
			.clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
		}
	}
}

#Preview(traits: .sizeThatFitsLayout) {
	ParkingListCardView(facility: PreviewHelper.almostFullFacility())
}
