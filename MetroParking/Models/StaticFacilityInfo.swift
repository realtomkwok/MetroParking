//
//  FacilityInfo.swift
//  MetroParking
//
//  Created by Tom Kwok on 21/6/2025.
//

import Foundation

extension ParkingFacility {

	static let staticFacilityData: [ParkingFacility] = [
		ParkingFacility(
			facilityId: "6",
			name: "Park&Ride - Gordon Henry St (north)",
			suburb: "Gordon",
			address: "Henry Street",
			latitude: -33.757065,
			longitude: 151.154662,
			totalSpaces: 213
		),
		ParkingFacility(
			facilityId: "7",
			name: "Park&Ride - Kiama",
			suburb: "Kiama",
			address: "Bong Bong Street",
			latitude: -34.673122,
			longitude: 150.854546,
			totalSpaces: 42
		),
		ParkingFacility(
			facilityId: "8",
			name: "Park&Ride - Gosford",
			suburb: "Gosford",
			address: "Showground Road",
			latitude: -33.42526471,
			longitude: 151.340236,
			totalSpaces: 1059
		),
		ParkingFacility(
			facilityId: "9",
			name: "Park&Ride - Revesby",
			suburb: "Revesby",
			address: "The River Road",
			latitude: -33.95107517,
			longitude: 151.0168491,
			totalSpaces: 864
		),
		ParkingFacility(
			facilityId: "10",
			name: "Park&Ride - Warriewood",
			suburb: "Warriewood",
			address: "Pittwater Road",
			latitude: -33.696887,
			longitude: 151.302143,
			totalSpaces: 233
		),
		ParkingFacility(
			facilityId: "11",
			name: "Park&Ride - Narrabeen",
			suburb: "Narrabeen",
			address: "Pittwater Road",
			latitude: -33.714364,
			longitude: 151.29699,
			totalSpaces: 46
		),
		ParkingFacility(
			facilityId: "12",
			name: "Park&Ride - Mona Vale",
			suburb: "Mona Vale",
			address: "Golf Avenue",
			latitude: -33.677567,
			longitude: 151.306512,
			totalSpaces: 68
		),
		ParkingFacility(
			facilityId: "13",
			name: "Park&Ride - Dee Why",
			suburb: "Dee Why",
			address: "40 Kingsway",
			latitude: -33.750302,
			longitude: 151.286717,
			totalSpaces: 121
		),
		ParkingFacility(
			facilityId: "14",
			name: "Park&Ride - West Ryde",
			suburb: "West Ryde",
			address: "Ryedale Road",
			latitude: -33.805993,
			longitude: 151.091248,
			totalSpaces: 151
		),
		ParkingFacility(
			facilityId: "15",
			name: "Park&Ride - Sutherland",
			suburb: "Sutherland",
			address: "East Parade",
			latitude: -34.02955,
			longitude: 151.058409,
			totalSpaces: 373
		),
		ParkingFacility(
			facilityId: "16",
			name: "Park&Ride - Leppington",
			suburb: "Leppington",
			address: "199A Rickard Road",
			latitude: -33.953826,
			longitude: 150.806971,
			totalSpaces: 1660
		),
		ParkingFacility(
			facilityId: "17",
			name: "Park&Ride - Edmondson Park (south)",
			suburb: "Edmondson Park",
			address: "MacDonald Road",
			latitude: -33.969476,
			longitude: 150.856259,
			totalSpaces: 1431
		),
		ParkingFacility(
			facilityId: "18",
			name: "Park&Ride - St Marys",
			suburb: "St Marys",
			address: "Harris Street",
			latitude: -33.761546,
			longitude: 150.776314,
			totalSpaces: 684
		),
		ParkingFacility(
			facilityId: "19",
			name: "Park&Ride - Campbelltown Farrow Rd (north)",
			suburb: "Campbelltown",
			address: "Farrow Road",
			latitude: -34.062279,
			longitude: 150.815283,
			totalSpaces: 68
		),
		ParkingFacility(
			facilityId: "20",
			name: "Park&Ride - Campbelltown Hurley St",
			suburb: "Campbelltown",
			address: "Hurley Street",
			latitude: -34.065798,
			longitude: 150.812432,
			totalSpaces: 118
		),
		ParkingFacility(
			facilityId: "21",
			name: "Park&Ride - Penrith (at-grade)",
			suburb: "Penrith",
			address: "Combewood Avenue",
			latitude: -33.748043,
			longitude: 150.69444,
			totalSpaces: 229
		),
		ParkingFacility(
			facilityId: "22",
			name: "Park&Ride - Penrith (multi-level)",
			suburb: "Penrith",
			address: "Combewood Avenue",
			latitude: -33.748452,
			longitude: 150.695171,
			totalSpaces: 1129
		),
		ParkingFacility(
			facilityId: "23",
			name: "Park&Ride - Warwick Farm",
			suburb: "Warwick Farm",
			address: "Remembrance Avenue",
			latitude: -33.913767,
			longitude: 150.934409,
			totalSpaces: 906
		),
		ParkingFacility(
			facilityId: "24",
			name: "Park&Ride - Schofields",
			suburb: "Schofields",
			address: "Calder Street",
			latitude: -33.703674,
			longitude: 150.870861,
			totalSpaces: 700
		),
		ParkingFacility(
			facilityId: "25",
			name: "Park&Ride - Hornsby",
			suburb: "Hornsby",
			address: "Jersey Street",
			latitude: -33.701352,
			longitude: 151.098004,
			totalSpaces: 145
		),
		ParkingFacility(
			facilityId: "26",
			name: "Park&Ride - Tallawong P1",
			suburb: "Tallawong",
			address: "Conferta Avenue",
			latitude: -33.69304704,
			longitude: 150.9052577,
			totalSpaces: 123
		),
		ParkingFacility(
			facilityId: "27",
			name: "Park&Ride - Tallawong P2",
			suburb: "Tallawong",
			address: "Aristida Street",
			latitude: -33.692987,
			longitude: 150.9043098,
			totalSpaces: 455
		),
		ParkingFacility(
			facilityId: "28",
			name: "Park&Ride - Tallawong P3",
			suburb: "Tallawong",
			address: "Conferta Avenue",
			latitude: -33.693832,
			longitude: 150.903874,
			totalSpaces: 397
		),
		ParkingFacility(
			facilityId: "29",
			name: "Park&Ride - Kellyville (north)",
			suburb: "Kellyville",
			address: "Derrobarry Street",
			latitude: -33.711156,
			longitude: 150.934364,
			totalSpaces: 351
		),
		ParkingFacility(
			facilityId: "30",
			name: "Park&Ride - Kellyville (south)",
			suburb: "Kellyville",
			address: "Guragura Street",
			latitude: -33.71498982,
			longitude: 150.9363451,
			totalSpaces: 964
		),
		ParkingFacility(
			facilityId: "31",
			name: "Park&Ride - Bella Vista",
			suburb: "Bella Vista",
			address: "Byles Place",
			latitude: -33.727438,
			longitude: 150.941761,
			totalSpaces: 774
		),
		ParkingFacility(
			facilityId: "32",
			name: "Park&Ride - Hills Showground",
			suburb: "Castle Hill",
			address: "De Clambe Drive",
			latitude: -33.727735,
			longitude: 150.98505,
			totalSpaces: 584
		),
		ParkingFacility(
			facilityId: "33",
			name: "Park&Ride - Cherrybrook",
			suburb: "Cherrybrook",
			address: "Bradfield Parade",
			latitude: -33.737374,
			longitude: 151.033431,
			totalSpaces: 384
		),
		ParkingFacility(
			facilityId: "34",
			name: "Park&Ride - Lindfield Village Green",
			suburb: "Lindfield",
			address: "Tryon Road",
			latitude: -33.77449,
			longitude: 151.170549,
			totalSpaces: 94
		),
		ParkingFacility(
			facilityId: "35",
			name: "Park&Ride - Beverly Hills",
			suburb: "Beverly Hills",
			address: "2-2A Edgbaston Road",
			latitude: -33.949744,
			longitude: 151.0801,
			totalSpaces: 200
		),
		ParkingFacility(
			facilityId: "36",
			name: "Park&Ride - Emu Plains",
			suburb: "Emu Plains",
			address: "176 Old Bathurst Rd",
			latitude: -33.745527,
			longitude: 150.66987,
			totalSpaces: 750
		),
		ParkingFacility(
			facilityId: "37",
			name: "Park&Ride - Riverwood",
			suburb: "Riverwood",
			address: "12-16 Webb St",
			latitude: -33.952727,
			longitude: 151.050035,
			totalSpaces: 135
		),
		ParkingFacility(
			facilityId: "486",
			name: "Park&Ride - Ashfield",
			suburb: "Ashfield",
			address: "Brown Street",
			latitude: -33.888104,
			longitude: 151.126577,
			totalSpaces: 228
		),
		ParkingFacility(
			facilityId: "487",
			name: "Park&Ride - Kogarah",
			suburb: "Kogarah",
			address: "2 Railway Street",
			latitude: -33.96369941,
			longitude: 151.1319494,
			totalSpaces: 259
		),
		ParkingFacility(
			facilityId: "488",
			name: "Park&Ride - Seven Hills",
			suburb: "Seven Hills",
			address: "Terminus Road",
			latitude: -33.77304548,
			longitude: 150.9367514,
			totalSpaces: 1613
		),

		ParkingFacility(
			facilityId: "489",
			name: "Park&Ride - Manly Vale",
			suburb: "Manly Vale",
			address: "84 Kenneth Road",
			latitude: -33.786536,
			longitude: 151.267221,
			totalSpaces: 142
		),

		ParkingFacility(
			facilityId: "490",
			name: "Park&Ride - Brookvale",
			suburb: "Brookvale",
			address: "612-624 Pittwater Road",
			latitude: -33.767366,
			longitude: 151.269667,
			totalSpaces: 246
		),

		ParkingFacility(
			facilityId: "38",
			name: "Park&Ride - North Rocks",
			suburb: "North Rocks",
			address: "Barclay Rd",
			latitude: -33.765539,
			longitude: 151.014131,
			totalSpaces: 139
		),

		ParkingFacility(
			facilityId: "39",
			name: "Park&Ride - Edmonson Park (north)",
			suburb: "Edmondson Park",
			address: "Gula Court",
			latitude: -33.9691,
			longitude: 150.8616,
			totalSpaces: 917
		)
	]

	static func getAllStaticFacilities() -> [ParkingFacility] {
		return staticFacilityData
	}
}
