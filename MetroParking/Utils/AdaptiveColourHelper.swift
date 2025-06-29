//
//  AdaptiveColourHelper.swift
//  MetroParking
//
//  Created by Tom Kwok on 29/6/2025.
//
// https://swiftandtips.com/adaptive-text-color-in-swiftui-based-on-background

import SwiftUI

extension Color {

  func luminance() -> Double {
    let uiColor = UIColor(self)

    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    uiColor.getRed(&red, green: &green, blue: &blue, alpha: nil)

    return 0.2126 * Double(red) + 0.7152 * Double(green) + 0.0722
      * Double(blue)

  }

  func isLight() -> Bool {
    return luminance() > 0.6
  }

  func adpatedTextColor() -> Color {
    return isLight() ? Color.black : Color.white
  }
}
