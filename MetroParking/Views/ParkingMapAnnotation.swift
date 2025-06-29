//
//  ParkingMapAnnotation.swift
//  MetroParking
//
//  Created by Tom Kwok on 27/6/2025.
//

import SwiftUI

struct ParkingMapAnnotation: View {
	let facility: ParkingFacility
	let isSelected: Bool
	
	var body: some View {
		VStack(spacing: 4) {
			ZStack {
				Circle()
					.fill(facility.availablityStatus.color.gradient)
					.frame(width: isSelected ? 32 : 24, height: isSelected ? 32 : 24)
					.overlay(
						Circle()
							.stroke(.white, lineWidth: isSelected ? 3 : 2)
					)
				
				Image(systemName: "parkingsign")
					.font(.system(size: isSelected ? 14 : 10, weight: .bold))
					.foregroundColor(.white)

			}
		}
		.scaleEffect(isSelected ? 1.2 : 1.0)
		.animation(.spring(response: 0.3), value: isSelected)
	}
}

#Preview {
	ParkingMapAnnotation(facility: PreviewHelper.almostFullFacility(), isSelected: true)
}
