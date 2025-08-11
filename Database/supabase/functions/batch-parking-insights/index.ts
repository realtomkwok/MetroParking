// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "npm:@supabase/supabase-js@2.53.0"

const FACILITIES = [
		"6",
		"7",
		"8",
		"9",
		"10",
		"11",
		"12",
		"13",
		"14",
		"15",
		"16",
		"17",
		"18",
		"19",
		"20",
		"21",
		"22",
		"23",
		"24",
		"25",
		"26",
		"27",
		"28",
		"29",
		"30",
		"31",
		"32",
		"33",
		"34",
		"35",
		"36",
		"37",
		"486",
		"487",
		"488",
		"489",
		"490",
]

async function processWithTimeout(facilityId: string, timeoutMs = 60000) {
		const controller = new AbortController()
		const timeoutId = setTimeout(() => controller.abort(), timeoutMs)
		
		try {
				const response = await fetch(`${Deno.env.get("SUPABASE_URL")}/functions/v1/gen-parking-trend`, {
						method: "POST",
						headers: {
								"Authorization": `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`,
								"Content-Type": "application/json",
						},
						body: JSON.stringify({ facility_id: facilityId, days: 30, batchSize: 5 }),
						signal: controller.signal,
				})
				
				clearTimeout(timeoutId)
				return await response.json()
		} catch (error) {
				clearTimeout(timeoutId)
				if (error.name === "AbortError") {
						throw new Error("Request timed out")
				}
				throw error
		}
}


Deno.serve(async (req) => {
		const supabase = createClient(
				Deno.env.get("SUPABASE_URL")!,
				Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
		)
		
		const results = []
		const startTime = Date.now()
		const MAX_RUNTIME = 8.5 * 60 * 1000 // 8.5 minutes (under 9min limit)
		
		for (const facilityId of FACILITIES) {
				if (Date.now() - startTime > MAX_RUNTIME) {
						results.push({ facilityId, success: false, error: "Batch timeout" })
						break
				}
				
				try {
						const result = await processWithTimeout(facilityId, 20000) // 20 seconds per facility
						results.push({ facilityId, success: true, result })
				} catch (error) {
						results.push({ facilityId, success: false, error: error.message })
				}
				
				await new Promise(resolve => setTimeout(resolve, 500))
		}
		
		return new Response(JSON.stringify({ results }))
})
