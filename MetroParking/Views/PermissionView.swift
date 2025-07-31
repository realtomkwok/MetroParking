//
//  PermissionView.swift
//  MetroParking
//
//  Created by Tom Kwok on 31/7/2025.
//

import SwiftUI

struct PermissionView: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject private var locationManager = LocationManager.shared

  @State private var isIconAnimating = true

  var body: some View {
    NavigationStack {
      VStack {
        VStack(alignment: .leading, spacing: 24) {
          Image(systemName: iconName)
            .font(.system(size: 60))
            .frame(width: 60, height: 60)
            .foregroundStyle(iconColor)
            .contentTransition(
              .symbolEffect(
                .replace.magic(fallback: .upUp.byLayer),
                options: .nonRepeating
              )
            )

          VStack(alignment: .leading, spacing: 8) {
            Text(titleText)
              .font(.title2)
              .fontWeight(.semibold)
              .multilineTextAlignment(.leading)

            Text(messageText)
              .font(.body)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.leading)

          }

        }
        .frame(maxWidth: .infinity)

        Spacer()

        Button(action: {
          locationManager.requestLocationPermission()
          Task {
            while locationManager.authorisationStatus == .notDetermined {
              try? await Task.sleep(nanoseconds: 500_000_000)
            }

            dismiss()
          }
        }) {
          Text(buttonText)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
      }
      .frame(maxWidth: .infinity)

      .padding()
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            dismiss()
          } label: {
            Label("Done", systemImage: "xmark")
              .fontWeight(.semibold)
              .frame(width: 20, height: 20)
              .foregroundStyle(.secondary)
          }
          .frame(width: 36, height: 36)
          .buttonBorderShape(.circle)
          .buttonStyle(.bordered)
          .foregroundStyle(.primary)
          .controlSize(.regular)
        }
      }
    }
    .onAppear {
      let animationDelay: UInt64 = 1_000_000_000

      Task {
        // Wait for 1 second
        try? await Task.sleep(nanoseconds: animationDelay)  // 1 second in nanoseconds

        // Trigger the animation by changing the state
        withAnimation(.snappy) {
          isIconAnimating = false
        }
      }
    }
  }

  // Dynamic content based on current permission status
  private var iconName: String {
    if isIconAnimating {
      return "location.app.fill"
    }

    switch locationManager.authorisationStatus {
    case .notDetermined:
      return "location.app"
    case .denied, .restricted:
      return "location.slash.fill"
    default:
      return "location.circle"
    }
  }

  private var iconColor: Color {
    switch locationManager.authorisationStatus {
    case .notDetermined:
      return .blue
    case .denied, .restricted:
      return .orange
    default:
      return .blue
    }
  }

  private var titleText: String {
    switch locationManager.authorisationStatus {
    case .notDetermined:
      return "Enable Location Access"
    case .denied, .restricted:
      return "Location Access Denied"
    default:
      return "Location Permission"
    }
  }

  private var messageText: String {
    switch locationManager.authorisationStatus {
    case .notDetermined:
      return
        "We'll show you the nearest parking facilities and provide better recommendations based on your location."
    case .denied, .restricted:
      return
        "Location access is currently disabled. Tap below to open Settings and allow location access for MetroParking."
    default:
      return "Location access helps improve your experience."
    }
  }

  private var buttonText: String {
    switch locationManager.authorisationStatus {
    case .notDetermined:
      return "Allow Location Access"
    case .denied, .restricted:
      return "Open Settings"
    default:
      return "OK"
    }
  }
}

#Preview {
  PermissionView()
    .modelContainer(PreviewHelper.previewContainer(withSamplePins: false))

}
