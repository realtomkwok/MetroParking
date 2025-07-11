//
//  MetroParkingApp.swift
//  MetroParking
//
//  Created by Tom Kwok on 18/5/2025.
//

import SwiftUI
import SwiftData

@main
struct MetroParkingApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
			ParkingFacility.self,
			ParkingZone.self,
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
				.modelContainer(sharedModelContainer)
				.onAppear {
					setupRefreshManager()
				}
        }
    }
	
	private func setupRefreshManager() {
		let context = sharedModelContainer.mainContext
		
		Task { @MainActor in
			FacilityRefreshManager.shared.setModelContext(context)
		}
	}
}
