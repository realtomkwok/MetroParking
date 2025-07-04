struct ParkingLocation: Codable {
	let suburb: String
	let address: String
	let latitude: Double
	let longitude: Double
	
	init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.suburb = try container.decode(String.self, forKey: .suburb)
		self.address = try container.decode(String.self, forKey: .address)
		
		// 
		
		self.latitude = try container.decode(Double.self, forKey: .latitude)
		self.longitude = try container.decode(Double.self, forKey: .longitude)
	}
}
