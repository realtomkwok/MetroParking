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
    
    init() {
        setupConfiguration()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
				.modelContainer(sharedModelContainer)
				.onAppear {
					setupRefreshManager()
				}
        }
    }
	
    private func setupConfiguration() {
        do {
            try Configuration.validateConfiguration()
            #if DEBUG
            Configuration.printConfiguration()
            #endif
        } catch {
            print("❌ Configuration error: \(error)")
            // In production, you might want to show an error screen instead of crashing
            #if DEBUG
            fatalError("Configuration validation failed: \(error)")
            #endif
        }
    }
    
	private func setupRefreshManager() {
		let context = sharedModelContainer.mainContext
		
		Task { @MainActor in
			FacilityRefreshManager.shared.setModelContext(context)
		}
	}
}
