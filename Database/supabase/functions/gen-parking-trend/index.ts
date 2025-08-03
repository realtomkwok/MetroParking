// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2.53.0"

// Interfaces
interface ParkingAPIResponse {
		tsn: string;
		time: string;
		spots: string;
		zones: [
				{
						spots: string;
						zone_id: string;
						occupancy: ParkingOccupancy;
				},
		];
		ParkId: string;
		location: {
				suburb: string;
				address: string;
				latitude: string;
				longitude: string;
		};
		occupancy: ParkingOccupancy;
		MessageDate: string;
		facility_id: string;
		facility_name: string;
		tfnsw_facility_id: string;
}

interface ParkingOccupancy {
		loop?: string;
		total: string;
		monthlies?: string;
		open_gate?: string;
		transients?: string;
}

interface HourlyPattern {
		facility_id: string;
		day_of_week: number;
		hour: number;
		avg_occupancy_rate: number;
		sample_count: number;
}

interface FacilityInsights {
		facility_id: string
		peak_hours: number[]
		best_times: number[]
		busiest_days: number[]
}

// Helper functions
/*
 Sanitise the incoming response so it complies with our type definition
 */
function sanitiseRawResponse(data: ParkingAPIResponse[] | any[]): ParkingAPIResponse[] {
		return data.filter((snapshot) => {
				// Filter out invalid snapshots
				const totalSpots = parseInt(snapshot.spots) || 0
				const occupiedSpots = parseInt(snapshot.occupancy?.total || "0")
				
				return (
						snapshot.facility_id &&
						snapshot.MessageDate &&
						totalSpots > 0 &&
						occupiedSpots >= 0 &&
						occupiedSpots <= totalSpots * 1.1 // Allow 10% over-capacity. Not sure if that's necessary
				)
		}).map((snapshot) => ( {
				...snapshot,
				spots: snapshot.spots,
				occupancy: {
						total: Math.max(0, parseInt(snapshot.occupancy.total)).toString(),
				},
		} ))
}


Deno.serve(async (req) => {
		const supabase = createClient(
				Deno.env.get("SUPABASE_URL")!,
				Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
		)
		
		const { facility_id, days = 14 } = await req.json() // Getting 2-week data
		
		try {
				if (!facility_id) {
						return new Response(JSON.stringify({ error: "`facility_id` required" }), {
								status: 400,
						})
				}
				
				console.log(`Processing insights for facility ${facility_id}`)
				
				// Update cache status to `pending`
				await updateCacheStatus(supabase, facility_id, "pending", days)
				
				// Fetch historical data from API
				const historicalData = await fetchHistoricalData(facility_id, days)
				console.log(`Fetched ${historicalData.length} historical records`)
				
				if (historicalData.length > 0) {
						await ensureFacilityExists(supabase, historicalData[0])
				}
				
				await supabase
						.from("processing_logs")
						.insert({
								facility_id: facility_id,
								status: "data-fetched",
								snapshot_count: historicalData.length,
								timestamp: new Date().toISOString(),
						})
				
				// Process hourly patterns
				const hourlyPatterns = getHourlyPatterns(historicalData)
				await storeHourlyPatterns(supabase, hourlyPatterns)
				
				// Generate insights
				const insights = generateInsights(hourlyPatterns)
				await storeInsights(supabase, insights)
				
				// Update cache status to 'complete'
				await updateCacheStatus(supabase, facility_id, "complete")
				
				return new Response(JSON.stringify({
						success: true,
						facility_id,
						snapshotProcessed: historicalData.length,
						insights,
				}))
		} catch (e) {
				await supabase
						.from("processing_logs")
						.insert({
								facility_id: facility_id,
								status: "error",
								error_message: e,
								timestamp: new Date().toISOString(),
						})
				
				return new Response(JSON.stringify({
						error: e.message,
						facility_id,
				}), { status: 500 })
		}
		
		async function updateCacheStatus(
				supabase: SupabaseClient,
				facilityId: string,
				status: string,
				days?: number,
		) {
				const updateData: any = {
						facility_id: facilityId,
						status,
						last_api_fetch: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
						days_cached: days,
				}
				
				if (days) {
						updateData.days_cached = days
						updateData.next_update_due = new Date(
								Date.now() + 7 * 24 * 60 * 60 * 1000,
						).toISOString()
				}
				
				await supabase
						.from("api_cache_status")
						.upsert(updateData)
		}
		
		
		/*
		 Batch-fetch snapshots for the given facility
		 */
		async function fetchHistoricalData(
				facility_id: string,
				days: number,
				batchSize: number = 3,
		): Promise<ParkingAPIResponse[]> {
				const baseUrl = Deno.env.get("TFNSW_API_BASE_URL")!
				const apiKey = Deno.env.get("TFNSW_API_KEY")!
				
				const dates = Array.from({ length: days }, (_, i) => {
						const date = new Date()
						date.setDate(date.getDate() - i)
						return date.toISOString().split("T")[0] // For the date part
				})
				
				const allData: ParkingAPIResponse[] = []
				
				for (let i = 0; i < dates.length; i += batchSize) {
						const batch = dates.slice(i, i + batchSize)
						
						const promises = batch.map(async (dateString) => {
								try {
										const res = await fetch(
												`${baseUrl}/carpark/history?facility=${facility_id}&eventdate=${dateString}`,
												{
														headers: {
																"Authorization": `apikey ${apiKey}`,
																"Accept": "application/json",
														},
												},
										)
										
										if (res.ok) {
												const dayData = await res.json()
												return sanitiseRawResponse(dayData)
										}
										return []
								} catch (e) {
										console.error(
												`Failed to fetch data for ${dateString} for facility ${facility_id}`,
												e,
										)
										return []
								}
						})
						
						const batchResults = await Promise.all(promises)
						allData.push(...batchResults.flat())
						
						// Respect rate limits
						if (i + batchSize < dates.length) {
								await new Promise((resolve) => setTimeout(resolve, 1000)) // Wait 1 sec
						}
				}
				
				return allData
		}
		
		/* Process hourly patterns */
		function getHourlyPatterns(data: ParkingAPIResponse[]): HourlyPattern[] {
				const patterns = new Map<string, { rates: number[], count: number }>()
				
				for (const snapshot of data) {
						const date = new Date(snapshot.MessageDate)
						const dayOfWeek = date.getDay() + 1       // 1=Sunday, 7=Saturday
						const hour = date.getHours()
						
						const totalSpots = parseInt(snapshot.spots) || 0
						const occupiedSpots = parseInt(snapshot.occupancy.total || "0")
						const occupancyRate
											= totalSpots > 0
								? occupiedSpots / totalSpots
								: 0
						
						const key = `${snapshot.facility_id}-${dayOfWeek}-${hour}`
						
						if (!patterns.has(key)) {
								patterns.set(key, { rates: [], count: 0 })
						}
						
						const pattern = patterns.get(key)!
						pattern.rates.push(occupancyRate)
						pattern.count++
				}
				
				// Calculate averages
				const hourlyPatterns: HourlyPattern[] = []
				
				for (const [key, pattern] of patterns) {
						const [facility_id, dayOfWeek, hour] = key.split("-")
						const avgRate = pattern.rates.reduce((sum, rate) => sum + rate, 0) / pattern.rates.length
						
						hourlyPatterns.push({
								facility_id: facility_id,
								day_of_week: parseInt(dayOfWeek),
								hour: parseInt(hour),
								avg_occupancy_rate: Math.round(avgRate * 1000) / 1000,
								sample_count: pattern.count,
						})
				}
				
				return hourlyPatterns
		}
		
		/* Generate insights */
		function generateInsights(patterns: HourlyPattern[]): FacilityInsights {
				const facility_id = patterns[0].facility_id
				
				// Calculate average rates by hour across all days
				const hourlyAvg = new Map<number, number>()
				for (let hour = 0; hour < 24; hour++) {
						const hourlyPattern = patterns.filter(p => p.hour === hour)
						if (hourlyPattern.length > 0) {
								const avgRate = hourlyPattern.reduce((sum, p) => sum + p.avg_occupancy_rate, 0) / hourlyPattern.length
								hourlyAvg.set(hour, avgRate)
						}
				}
				
				// Find peak hours (top 3 busiest, the highest occupancy)
				const peakHours = Array.from(hourlyAvg.entries())
						.sort((a, b) => b[1] - a[1])      // ?
						.slice(0, 3)
						.map(([hour]) => hour)
						.sort((a, b) => a - b)      // ?
				
				// Find best times (the lowest occupancy during business hours 6-22)
				const bestHours = Array.from(hourlyAvg.entries())
						.filter(([hour]) => hour >= 6 && hour <= 22)
						.sort((a, b) => a[1] - b[1])
						.slice(0, 3)
						.map(([hour]) => hour)
						.sort((a, b) => a - b)
				
				// Find the busiest days
				const dailyAverages = new Map<number, number>()
				for (let day = 1; day <= 7; day++) {
						const dayPatterns = patterns.filter(p => p.day_of_week === day)
						if (dayPatterns.length > 0) {
								const avgRate = dayPatterns.reduce((sum, p) => sum + p.avg_occupancy_rate, 0) / dayPatterns.length
								dailyAverages.set(day, avgRate)
						}
				}
				
				const busiestDays = Array.from(dailyAverages.entries())
						.sort((a, b) => b[1] - a[1])
						.slice(0, 3)
						.map(([day]) => day)
						.sort((a, b) => a - b)
				
				return {
						facility_id: facility_id,
						peak_hours: peakHours,
						best_times: bestHours,
						busiest_days: busiestDays,
				}
		}
		
		async function storeHourlyPatterns(supabase: SupabaseClient, patterns: HourlyPattern[]) {
				if (patterns.length === 0) return
				
				const facilityId = patterns[0].facility_id
				
				// Clear existing patterns for this facility
				await supabase
						.from("hourly_patterns")
						.delete()
						.eq("facility_id", facilityId)
				
				// Insert new patterns
				const { error } = await supabase
						.from("hourly_patterns")
						.insert(patterns)
				
				if (error) {
						throw new Error(`Failed to store hourly patterns: ${error.message}`)
				}
		}
		
		async function storeInsights(supabase: SupabaseClient, insights: FacilityInsights) {
				const { error } = await supabase
						.from("facility_insights")
						.upsert(insights)
				
				if (error) {
						throw new Error(`Failed to store insights: ${error.message}`)
				}
		}
		
		async function ensureFacilityExists(supabase: SupabaseClient, facilityData: ParkingAPIResponse) {
				// Validate required fields
				if (!facilityData.facility_id || !facilityData.facility_name) {
						throw new Error("Missing required facility data")
				}
				
				const facilityInfo = {
						facility_id: facilityData.facility_id,
						name: facilityData.facility_name,
						suburb: facilityData.location?.suburb || "Unknown",
						address: facilityData.location?.address || "Unknown",
						latitude: facilityData.location?.latitude ? parseFloat(facilityData.location.latitude) : 0,
						longitude: facilityData.location?.longitude ? parseFloat(facilityData.location.longitude) : 0,
						total_spots: parseInt(facilityData.spots) || 0,
						tsn: facilityData.tsn || "",
						tfnsw_facility_id: facilityData.tfnsw_facility_id || "",
						last_pattern_update: new Date().toISOString(),
				}
				
				const { error } = await supabase
						.from("facilities")
						.upsert(facilityInfo)
				
				if (error) {
						throw new Error(`Failed to store facility: ${error.message}`)
				}
		}
})