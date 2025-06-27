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
		
			// Show name if selected
			if isSelected {
				Text(facility.displayName)
					.font(.caption)
					.fontWeight(.medium)
					.padding(.horizontal, 8)
					.padding(.vertical, 4)
					.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
					.fixedSize()
			}
		}
		.scaleEffect(isSelected ? 1.2 : 1.0)
		.animation(.spring(response: 0.3), value: isSelected)
	}
}
