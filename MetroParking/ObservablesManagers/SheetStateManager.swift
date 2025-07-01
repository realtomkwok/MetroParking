//
//  SheetStateManager.swift
//  MetroParking
//
//  Created by Tom Kwok on 29/6/2025.
//

import SwiftData
import SwiftUI

enum SheetState: CaseIterable {
  case minimised  // When interacting with map
  case compact  // Initial/default state
  case expanded  // When viewing details
  case fullScreen  // For detailed views

  var detent: PresentationDetent {
    switch self {
    case .minimised:
      return .fraction(0.1)
    case .compact:
      return .fraction(0.4)
    case .expanded:
      return .medium
    case .fullScreen:
      return .large
    }
  }

  var height: CGFloat {
    switch self {
    case .minimised:
      return 0.1
    case .compact:
      return 0.4
    case .expanded:
      return 0.3
    case .fullScreen:
      return 1
    }
  }
}

@MainActor
class SheetStateManager: ObservableObject {

  @Published var sheetState: SheetState = .expanded
  @Published var currentDetent: PresentationDetent = .medium

  @Published var currentDetentHeight: CGFloat = 0.5

  @Published var showingFacilityDetail = false
  @Published var selectedFacilityForDetail: ParkingFacility?

  /// Set the height of sheet
  func setSheetState(_ newState: SheetState) {
    sheetState = newState

    withAnimation(.snappy(duration: 0.3)) {
      currentDetent = newState.detent
      currentDetentHeight = newState.height
    }
  }

  func showFacilityDetail(_ facility: ParkingFacility) {
    selectedFacilityForDetail = facility
    showingFacilityDetail = true
    setSheetState(.expanded)
  }

  func hideFacilityDetail() {
    selectedFacilityForDetail = nil
    showingFacilityDetail = false
  }
}
