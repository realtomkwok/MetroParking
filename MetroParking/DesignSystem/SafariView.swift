//
//  SafariView.swift
//  MetroParking
//
//  Created by Tom Kwok on 30/7/2025.
//

import SafariServices
import SwiftUI

extension URL {
  static func safe(_ string: String, fallback: String = "about:blank") -> URL {
    URL(string: string) ?? URL(string: fallback)!
  }
}

struct SafariView: UIViewControllerRepresentable {
  let url: URL

  func makeUIViewController(context: Context) -> SFSafariViewController {
    return SFSafariViewController(url: url)
  }

  func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
    // No updates needed
  }
}
