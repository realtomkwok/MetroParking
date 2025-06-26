//
//  FacilityInfo.swift
//  MetroParking
//
//  Created by Tom Kwok on 21/6/2025.
//

import Foundation

struct StaticFacilityInfo {
	let facilityId: String
	let name: String
	let suburb: String
	let address: String
	let latitude: Double
	let longitude: Double
	let totalSpaces: Int
	let tsn: String
	let tfnswFacilityId: String
}

extension ParkingFacility {
	
	static let staticFacilityData: [StaticFacilityInfo] = [
		StaticFacilityInfo(
			facilityId: "6",
			name: "Park&Ride - Gordon Henry St (north)",
			suburb: "Gordon",
			address: "Henry Street",
			latitude: -33.757065,
			longitude: 151.154662,
			totalSpaces: 213,
			tsn: "207210",
			tfnswFacilityId: "207210TPR001"
		),
		StaticFacilityInfo(
			facilityId: "7",
			name: "Park&Ride - Kiama",
			suburb: "Kiama",
			address: "Bong Bong Street",
			latitude: -34.673122,
			longitude: 150.854546,
			totalSpaces: 42,
			tsn: "253330",
			tfnswFacilityId: "253330TPR001"
		),
		StaticFacilityInfo(
			facilityId: "8",
			name: "Park&Ride - Gosford",
			suburb: "Gosford",
			address: "Showground Road",
			latitude: -33.42526471,
			longitude: 151.340236,
			totalSpaces: 1059,
			tsn: "225040",
			tfnswFacilityId: "225040TPR001"
		),
		StaticFacilityInfo(
			facilityId: "9",
			name: "Park&Ride - Revesby",
			suburb: "Revesby",
			address: "The River Road",
			latitude: -33.95107517,
			longitude: 151.0168491,
			totalSpaces: 864,
			tsn: "221210",
			tfnswFacilityId: "221210TPR001"
		),
		StaticFacilityInfo(
			facilityId: "10",
			name: "Park&Ride - Warriewood",
			suburb: "Warriewood",
			address: "Pittwater Road",
			latitude: -33.696887,
			longitude: 151.302143,
			totalSpaces: 233,
			tsn: "2101131",
			tfnswFacilityId: "2101131TPR001"
		),
		StaticFacilityInfo(
			facilityId: "11",
			name: "Park&Ride - Narrabeen",
			suburb: "Narrabeen",
			address: "Pittwater Road",
			latitude: -33.714364,
			longitude: 151.29699,
			totalSpaces: 46,
			tsn: "2101130",
			tfnswFacilityId: "2101130TPR001"
		),
		StaticFacilityInfo(
			facilityId: "12",
			name: "Park&Ride - Mona Vale",
			suburb: "Mona Vale",
			address: "Golf Avenue",
			latitude: -33.677567,
			longitude: 151.306512,
			totalSpaces: 68,
			tsn: "2103108",
			tfnswFacilityId: "2103108TPR001"
		),
		StaticFacilityInfo(
			facilityId: "13",
			name: "Park&Ride - Dee Why",
			suburb: "Dee Why",
			address: "40 Kingsway",
			latitude: -33.750302,
			longitude: 151.286717,
			totalSpaces: 121,
			tsn: "2099207",
			tfnswFacilityId: "2099207TPR001"
		),
		StaticFacilityInfo(
			facilityId: "14",
			name: "Park&Ride - West Ryde",
			suburb: "West Ryde",
			address: "Ryedale Road",
			latitude: -33.805993,
			longitude: 151.091248,
			totalSpaces: 151,
			tsn: "211420",
			tfnswFacilityId: "211420TPR001"
		),
		StaticFacilityInfo(
			facilityId: "15",
			name: "Park&Ride - Sutherland",
			suburb: "Sutherland",
			address: "East Parade",
			latitude: -34.02955,
			longitude: 151.058409,
			totalSpaces: 373,
			tsn: "223210",
			tfnswFacilityId: "223210TPR001"
		),
		StaticFacilityInfo(
			facilityId: "16",
			name: "Park&Ride - Leppington",
			suburb: "Leppington",
			address: "199A Rickard Road",
			latitude: -33.953826,
			longitude: 150.806971,
			totalSpaces: 1660,
			tsn: "217933",
			tfnswFacilityId: "217933TPR001"
		),
		StaticFacilityInfo(
			facilityId: "17",
			name: "Park&Ride - Edmondson Park (south)",
			suburb: "Edmondson Park",
			address: "MacDonald Road",
			latitude: -33.969476,
			longitude: 150.856259,
			totalSpaces: 1431,
			tsn: "217426",
			tfnswFacilityId: "217426TPR001"
		),
		StaticFacilityInfo(
			facilityId: "18",
			name: "Park&Ride - St Marys",
			suburb: "St Marys",
			address: "Harris Street",
			latitude: -33.761546,
			longitude: 150.776314,
			totalSpaces: 684,
			tsn: "276010",
			tfnswFacilityId: "276010TPR001"
		),
		StaticFacilityInfo(
			facilityId: "19",
			name: "Park&Ride - Campbelltown Farrow Rd (north)",
			suburb: "Campbelltown",
			address: "Farrow Road",
			latitude: -34.062279,
			longitude: 150.815283,
			totalSpaces: 68,
			tsn: "256020",
			tfnswFacilityId: "256020TPR001"
		),
		StaticFacilityInfo(
			facilityId: "20",
			name: "Park&Ride - Campbelltown Hurley St",
			suburb: "Campbelltown",
			address: "Hurley Street",
			latitude: -34.065798,
			longitude: 150.812432,
			totalSpaces: 118,
			tsn: "256020",
			tfnswFacilityId: "256020TPR002"
		),
		StaticFacilityInfo(
			facilityId: "21",
			name: "Park&Ride - Penrith (at-grade)",
			suburb: "Penrith",
			address: "Combewood Avenue",
			latitude: -33.748043,
			longitude: 150.69444,
			totalSpaces: 229,
			tsn: "275010",
			tfnswFacilityId: "275010TPR001"
		),
		StaticFacilityInfo(
			facilityId: "22",
			name: "Park&Ride - Penrith (multi-level)",
			suburb: "Penrith",
			address: "Combewood Avenue",
			latitude: -33.748452,
			longitude: 150.695171,
			totalSpaces: 1129,
			tsn: "275010",
			tfnswFacilityId: "275010TPR002"
		),
		StaticFacilityInfo(
			facilityId: "23",
			name: "Park&Ride - Warwick Farm",
			suburb: "Warwick Farm",
			address: "Remembrance Avenue",
			latitude: -33.913767,
			longitude: 150.934409,
			totalSpaces: 906,
			tsn: "217010",
			tfnswFacilityId: "217010TPR001"
		),
		StaticFacilityInfo(
			facilityId: "24",
			name: "Park&Ride - Schofields",
			suburb: "Schofields",
			address: "Calder Street",
			latitude: -33.703674,
			longitude: 150.870861,
			totalSpaces: 700,
			tsn: "276220",
			tfnswFacilityId: "276220TPR001"
		),
		StaticFacilityInfo(
			facilityId: "25",
			name: "Park&Ride - Hornsby",
			suburb: "Hornsby",
			address: "Jersey Street",
			latitude: -33.701352,
			longitude: 151.098004,
			totalSpaces: 145,
			tsn: "207720",
			tfnswFacilityId: "207720TPR001"
		),
		StaticFacilityInfo(
			facilityId: "26",
			name: "Park&Ride - Tallawong P1",
			suburb: "Tallawong",
			address: "Conferta Avenue",
			latitude: -33.69304704,
			longitude: 150.9052577,
			totalSpaces: 123,
			tsn: "2155384",
			tfnswFacilityId: "2155384TPR001"
		),
		StaticFacilityInfo(
			facilityId: "27",
			name: "Park&Ride - Tallawong P2",
			suburb: "Tallawong",
			address: "Aristida Street",
			latitude: -33.692987,
			longitude: 150.9043098,
			totalSpaces: 455,
			tsn: "2155384",
			tfnswFacilityId: "2155384TPR002"
		),
		StaticFacilityInfo(
			facilityId: "28",
			name: "Park&Ride - Tallawong P3",
			suburb: "Tallawong",
			address: "Conferta Avenue",
			latitude: -33.693832,
			longitude: 150.903874,
			totalSpaces: 397,
			tsn: "2155384",
			tfnswFacilityId: "2155384TPR003"
		),
		StaticFacilityInfo(
			facilityId: "29",
			name: "Park&Ride - Kellyville (north)",
			suburb: "Kellyville",
			address: "Derrobarry Street",
			latitude: -33.711156,
			longitude: 150.934364,
			totalSpaces: 351,
			tsn: "2155382",
			tfnswFacilityId: "2155382TPR001"
		),
		StaticFacilityInfo(
			facilityId: "30",
			name: "Park&Ride - Kellyville (south)",
			suburb: "Kellyville",
			address: "Guragura Street",
			latitude: -33.71498982,
			longitude: 150.9363451,
			totalSpaces: 964,
			tsn: "2155382",
			tfnswFacilityId: "2155382TPR002"
		),
		StaticFacilityInfo(
			facilityId: "31",
			name: "Park&Ride - Bella Vista",
			suburb: "Bella Vista",
			address: "Byles Place",
			latitude: -33.727438,
			longitude: 150.941761,
			totalSpaces: 774,
			tsn: "2153478",
			tfnswFacilityId: "2153478TPR001"
		),
		StaticFacilityInfo(
			facilityId: "32",
			name: "Park&Ride - Hills Showground",
			suburb: "Castle Hill",
			address: "De Clambe Drive",
			latitude: -33.727735,
			longitude: 150.98505,
			totalSpaces: 584,
			tsn: "2154392",
			tfnswFacilityId: "2154392TPR001"
		),
		StaticFacilityInfo(
			facilityId: "33",
			name: "Park&Ride - Cherrybrook",
			suburb: "Cherrybrook",
			address: "Bradfield Parade",
			latitude: -33.737374,
			longitude: 151.033431,
			totalSpaces: 384,
			tsn: "2126158",
			tfnswFacilityId: "2126158TPR001"
		),
		StaticFacilityInfo(
			facilityId: "34",
			name: "Park&Ride - Lindfield Village Green",
			suburb: "Lindfield",
			address: "Tryon Road",
			latitude: -33.77449,
			longitude: 151.170549,
			totalSpaces: 94,
			tsn: "207010",
			tfnswFacilityId: "207010TPR001"
		),
		StaticFacilityInfo(
			facilityId: "35",
			name: "Park&Ride - Beverly Hills",
			suburb: "Beverly Hills",
			address: "2-2A Edgbaston Road",
			latitude: -33.949744,
			longitude: 151.0801,
			totalSpaces: 200,
			tsn: "220910",
			tfnswFacilityId: "220910TPR001"
		),
		StaticFacilityInfo(
			facilityId: "36",
			name: "Park&Ride - Emu Plains",
			suburb: "Emu Plains",
			address: "176 Old Bathurst Rd",
			latitude: -33.745527,
			longitude: 150.66987,
			totalSpaces: 750,
			tsn: "275020",
			tfnswFacilityId: "275020TPR001"
		),
		StaticFacilityInfo(
			facilityId: "37",
			name: "Park&Ride - Riverwood",
			suburb: "Riverwood",
			address: "12-16 Webb St",
			latitude: -33.952727,
			longitude: 151.050035,
			totalSpaces: 135,
			tsn: "221010",
			tfnswFacilityId: "221010TPR001"
		),
	]
	
	static func getAllStaticFacilities() -> [StaticFacilityInfo] {
		return staticFacilityData
	}
	
	static func getFacilitiesSortedByDistance(from userLocation: (lat: Double, lon: Double)) -> [StaticFacilityInfo] {
		return staticFacilityData.sorted { facility1, facility2 in
			let dist1 = calculateDistance(
				from: userLocation,
				to: (facility1.latitude, facility1.longitude)
			)
			let dist2 = calculateDistance(
				from: userLocation,
				to: (facility2.latitude, facility2.longitude)
			)
			return dist1 < dist2
		}
	}
	
	private static func calculateDistance(from: (lat: Double, lon: Double), to: (lat: Double, lon: Double)) -> Double {
		let latDiff = from.lat - to.lat
		let lonDiff = from.lon - to.lon
		return sqrt(latDiff * latDiff + lonDiff * lonDiff)
	}
}
