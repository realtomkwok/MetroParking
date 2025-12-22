//
//  APIUsageDebugView.swift
//  MetroParking
//
//  Debug view to monitor API usage and refresh status
//  Add to your settings or debug menu
//

import SwiftUI
import SwiftData

struct APIUsageDebugView: View {
    @Environment(FacilityManager.self) private var facilityManager
	@Query private var facilities: [ParkingFacility]
    
    @State private var selectedTier: RefreshTier? = nil
    
    // Computed property to sort facilities by last refreshed time
    private var sortedFacilities: [ParkingFacility] {
        facilities.sorted { $0.refreshStatus.lastRefreshed > $1.refreshStatus.lastRefreshed }
    }
    
    var body: some View {
        List {
            apiUsageSection
            refreshStatusSection
            cacheStatusSection
            recentRefreshesSection
        }
        .navigationTitle("API Usage Debug")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - View Components
    
    private var apiUsageSection: some View {
        Section("API Usage") {
            HStack {
                Text("Daily Usage")
                Spacer()
                Text("\(APIUsageMonitor.dailyUsage) / 60,000")
                    .foregroundStyle(.secondary)
            }
            
            ProgressView(value: Double(APIUsageMonitor.dailyUsage), 
                       total: 60000.0)
            .tint(usageColor)
            
            HStack {
                Text("Can Make Call")
                Spacer()
                Text(APIUsageMonitor.canMakeCall ? "✅ Yes" : "⚠️ Limit Reached")
                    .foregroundStyle(APIUsageMonitor.canMakeCall ? .green : .red)
            }
            
            Button("Reset Counter (Debug)") {
                APIUsageMonitor.resetCounter()
            }
            .foregroundStyle(.red)
        }
    }
    
    private var refreshStatusSection: some View {
        Section("Refresh Status") {
            HStack {
                Text("Is Refreshing")
                Spacer()
                Text(facilityManager.isRefreshing ? "🔄 Yes" : "⏸️ No")
            }
            
            HStack {
                Text("Last Refresh")
                Spacer()
                if let lastRefresh = facilityManager.lastRefreshTime {
                    Text(lastRefresh.formatted(.relative(presentation: .numeric)))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Never")
                        .foregroundStyle(.tertiary)
                }
            }
            
            HStack {
                Text("Progress")
                Spacer()
                Text(facilityManager.loadProgress.description)
                    .foregroundStyle(.secondary)
            }
            
            Button("Force Refresh Now") {
                Task {
                    await facilityManager.performLoad(forced: true)
                }
            }
        }
    }
    
    private var cacheStatusSection: some View {
        Section("Cache Status by Tier") {
            ForEach(RefreshTier.allCases, id: \.self) { tier in
                tierDisclosureGroup(for: tier)
            }
        }
    }
    
    private func tierDisclosureGroup(for tier: RefreshTier) -> some View {
        let tierFacilities = facilities.filter { $0.vacancy.tier == tier }
		let validCaches = tierFacilities.filter {
			$0.vacancy.isCacheValid
		}.count

        return DisclosureGroup {
            ForEach(tierFacilities, id: \.facilityId) { facility in
                facilityRow(for: facility)
            }
        } label: {
            HStack {
                Text(tierLabel(tier))
                    .font(.headline)
                
                Spacer()
                
                Text("\(validCaches)/\(tierFacilities.count) cached")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func facilityRow(for facility: ParkingFacility) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(facility.displayName.title)
                    .font(.body)
                Text(facility.displayName.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
				Text(facility.vacancy.isCacheValid ? "✅" : "⏰")
				Text(
					"\(facility.refreshStatus.lastRefreshed.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))))s ago"
				)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
    
    private var recentRefreshesSection: some View {
        Section("Recent Refreshes") {
            ForEach(sortedFacilities.prefix(10), id: \.facilityId) { facility in
                recentRefreshRow(for: facility)
            }
        }
    }
    
    private func recentRefreshRow(for facility: ParkingFacility) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(facility.displayName.title)
                    .font(.body)
                Text(facility.displayName.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
				Text(
					facility.refreshStatus
						.lastRefreshed
						.formatted(.relative(presentation: .numeric))
				)
                    .font(.caption)
                Text(tierBadge(facility.refreshTier))
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(tierColor(facility.refreshTier).opacity(0.2))
                    .foregroundStyle(tierColor(facility.refreshTier))
                    .clipShape(Capsule())
            }
        }
    }

	private var backgroundTaskSection: some View {
		Section("Background Tasks") {
			LabeledContent("Widget Budget Used") {
				Text("\(WidgetBudgetTracker.shared.reloadsInLast24Hours())/60 today")
			}

			LabeledContent("Last Widget Reload") {
				Text("\(WidgetBudgetTracker.shared.reloadsInLast24Hours())/60 today")
			}

			Button("Simulate App Refresh") {
				Task {
					await BackgroundTaskManager.shared.performQuickRefresh()
				}
			}
		}
	}

    private var usageColor: Color {
        let percentage = Double(APIUsageMonitor.dailyUsage) / 60000.0
        
        if percentage < 0.5 {
            return .green
        } else if percentage < 0.8 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func tierLabel(_ tier: RefreshTier) -> String {
        switch tier {
        case .critical: return "⭐️ Critical (2 min cache)"
        case .standard: return "📍 Standard (5 min cache)"
        case .background: return "⏱️ Background (15 min cache)"
        }
    }
    
    private func tierBadge(_ tier: RefreshTier) -> String {
        switch tier {
        case .critical: return "Critical"
        case .standard: return "Standard"
        case .background: return "Background"
        }
    }
    
    private func tierColor(_ tier: RefreshTier) -> Color {
        switch tier {
        case .critical: return .red
        case .standard: return .orange
        case .background: return .blue
        }
    }
}

#Preview {
    NavigationStack {
        APIUsageDebugView()
    }
	.environment(FacilityManager.shared)
	.environment(LookAroundManager.shared)
	.environment(ETAManager.shared)
	.modelContainer(.preview(includeSampleData: false))
}
