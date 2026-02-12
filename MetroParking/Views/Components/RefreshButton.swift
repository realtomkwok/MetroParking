//
//  RefreshButton.swift
//  MetroParking
//
//  Created by Tom Kwok on 1/2/2026.
//

import SwiftUI

struct RefreshButton: View {
	@Environment(FacilityManager.self) private var facilityDataMgr

	enum Scope {
		case single(ParkingFacility)
		case all
	}

	let scope: Scope

	private var isActive: Bool {
		facilityDataMgr.isRefreshing
	}

	private var isDisabled: Bool {
		switch scope {
			case .single(
				let facility
			): return facility.refreshStatus.timeSinceLastUpdate < 1
			case .all: return facilityDataMgr.isRefreshing
		}
	}

	var body: some View {
		Button {
			Task {
				switch scope {
					case .single(let facility): await facilityDataMgr.loadFacility(
						facility,
						forced: true
					)
					case .all: await facilityDataMgr.performLoad(forced: true)
				}
			}
		} label: {
			Label {
				Text("action.button.refresh")
			} icon: {
				Image(systemName: "arrow.clockwise")
					.symbolEffect(
						.rotate.clockwise.byLayer,
						options: .repeat(.periodic(delay: 0.3)),
						isActive: isActive
					)
			}
		}
		.disabled(isActive)
		.accessibilityLabel(.actionButtonRefresh)
	}
}
