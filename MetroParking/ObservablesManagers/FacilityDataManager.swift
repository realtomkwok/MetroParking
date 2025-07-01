//
//  FacilityDataManager.swift
//  MetroParking
//
//  Created by Tom Kwok on 21/6/2025.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
class FacilityDataManager: ObservableObject {

  @Published var isLoadingStaticData = false
  @Published var staticDataLoadTime: Date?

  private var modelContext: ModelContext?

  func setModelContext(_ context: ModelContext) {
    self.modelContext = context
    print("📊 FacilityDataManager connected to SwiftData")
  }

  /// ONLY handles loading static facility metadata into SwiftData
  func loadStaticFacilitiesIfNeeded() async {
    guard let context = modelContext else {
      print("❌ No ModelContext available")
      return
    }

    if await hasExistingFacilities() {
      print("✅ Facilities already loaded")
      return
    }

    guard !isLoadingStaticData else {
      print("⏩ Static data loading already in progress")
      return
    }

    print("📦 Loading static facility data...")
    isLoadingStaticData = true

    let staticFacilities = LocationManager.shared
      .sortStaticFacilitiesByDistance(
        ParkingFacility.getAllStaticFacilities()
      )

    print(
      "📦 Inserting \(staticFacilities.count) facilities into SwiftData..."
    )

    /// Insert facilities WITHOUT occupancy data
    for staticInfo in staticFacilities {
      let facility = ParkingFacility(from: staticInfo)
      context.insert(facility)
    }

    withAnimation(.snappy) {
      do {
        try context.save()
        print("💾 Saved \(staticFacilities.count) static facilities")
        staticDataLoadTime = Date()
      } catch {
        print("❌ Failed to save static facilities: \(error)")
      }
    }

    isLoadingStaticData = false
    print("✅ Static facility loading complete!")
  }

  func reloadStaticFacilities() async {
    await clearAllFacilities()
    await loadStaticFacilitiesIfNeeded()
  }

  func getFacilityStats() async -> FacilityStats {
    let allFacilities = await getAllFacilities()
    let withOccupancyData = allFacilities.filter {
      $0.isOccupancyCacheValid
    }

    return FacilityStats(
      totalCount: allFacilities.count,
      withOccupancyData: withOccupancyData.count,
      favouriteCount: allFacilities.filter { $0.isFavourite }.count
    )
  }

  func hasExistingFacilities() async -> Bool {
    guard let context = modelContext else { return false }

    let descriptor = FetchDescriptor<ParkingFacility>()

    do {
      let facilities = try context.fetch(descriptor)
      return !facilities.isEmpty
    } catch {
      print("❌ Failed to check existing facilities: \(error)")
      return false
    }
  }

  func getUserLocation() -> (lat: Double, lon: Double) {
    let userLoc = LocationManager.shared.userLocation
    return (lat: userLoc.latitude, lon: userLoc.longitude)  // Sydney CBD
  }

  private func getAllFacilities() async -> [ParkingFacility] {
    guard let context = modelContext else { return [] }

    let descriptor = FetchDescriptor<ParkingFacility>()
    do {
      return try context.fetch(descriptor)
    } catch {
      print("❌ Failed to fetch facilities: \(error)")
      return []
    }
  }

  func clearAllFacilities() async {
    guard let context = modelContext else { return }

    let descriptor = FetchDescriptor<ParkingFacility>()

    withAnimation(.spring) {
      do {
        let facilities = try context.fetch(descriptor)
        for facility in facilities {
          context.delete(facility)
        }
        try context.save()
        print("🗑️ Cleared all facilities")
      } catch {
        print("❌ Failed to clear facilities: \(error)")
      }
    }

  }
}

struct FacilityStats {
  let totalCount: Int
  let withOccupancyData: Int
  let favouriteCount: Int

  var occupancyDataPercentage: Double {
    return totalCount > 0
      ? Double(withOccupancyData) / Double(totalCount) * 100 : 0
  }

  var description: String {
    return
      "\(totalCount) facilities, \(withOccupancyData) with data (\(Int(occupancyDataPercentage))%), \(favouriteCount) favourites"
  }
}
