//
//  ParkingListCardView.swift
//  MetroParking
//
//  Created by Tom Kwok on 26/6/2025.
//

import SwiftUI

struct ParkingListCardView: View {
	
	@Environment(\.modelContext) private var modelContext
	
	let facility: ParkingFacility
	// TODO: Replace value with real distance
	let distance = Measurement(value: 5.2, unit: UnitLength.kilometers)
	
	// TODO: Update indicator
	
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
								.frame(minWidth: 20, minHeight: 20)
								.fontWeight(.medium)
							Text("\(distance.formatted()) away")
						}
						.font(.callout)
						.foregroundStyle(Color(.secondaryLabel))
						
						HStack(alignment: .center) {
							Image(systemName: "circlebadge.fill")
								.symbolEffect(.pulse.byLayer, options: .repeat(.continuous))
								.frame(minWidth: 20, minHeight: 20)
							Text(facility.lastUpdated.formatted(.relative(presentation: .numeric, unitsStyle: .narrow)))
								.textCase(.uppercase)
							
						}
						.font(.callout)
						.foregroundStyle(Color(.secondaryLabel))
					}
				}
				
				Spacer(minLength: 48)
				
				VStack(alignment: .trailing) {
					
					VStack(alignment: .center, spacing: 0) {
						Text("\(facility.currentAvailableSpots)")
							.font(.largeTitle)
							.fontDesign(.rounded)
							.foregroundStyle(Color(.label))
							.contentTransition(.numericText(value: Double(facility.currentAvailableSpots)))
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
						.foregroundStyle(.white)
						.blendMode(.hardLight)
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
