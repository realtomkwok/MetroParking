//
//  InitSupabaseHelper.swift
//  MetroParking
//
//  Created by Tom Kwok on 4/8/2025.
//

import Supabase
import Foundation

let supabaseUrl = Configuration.supabaseUrl
let supabaseKey = Configuration.supabasePublishableKey

let supabase = SupabaseClient(
	supabaseURL: URL(string: "\(supabaseUrl)")!,
	supabaseKey: "\(supabaseKey)"
)
