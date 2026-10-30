class_name CityData
## Static layout data shared by the CityBuilder, JobManager, PhoneUI and the mini-map,
## so every system agrees on where things are in Nova Aetheris.
##
## Grid: 5x5 blocks, block centres at i * BLOCK_PITCH for i in -2..2.
## Roads run along x or z = +-26, +-78 and the outer ring at +-137.
## Districts: The Heights (NE, i >= 1 & j <= -1), Neon Docks (SW), Core Plaza (0,0).

const BLOCK_PITCH := 52.0
const BLOCK_SIZE := 40.0
const CITY_HALF := 150.0

const GATE_POSITION := Vector3(0, 0, -146)

## Vehicles the Garage app sells. "aether_compact" is owned from the start (the car parked
## beside the player at spawn). Paint feeds VehicleController so each model reads differently.
const VEHICLES: Array[Dictionary] = [
	{"id": "aether_compact", "name": "Aether Compact", "price": 0, "paint": Color(0.09, 0.08, 0.12),
		"desc": "Your starter runabout. Nimble, cheap to fix."},
	{"id": "docks_hauler", "name": "Docks Hauler", "price": 1900, "paint": Color(0.6, 0.42, 0.1),
		"desc": "Freight-yard pickup. Shrugs off kerbs and crates."},
	{"id": "vanta_gt", "name": "Vanta GT", "price": 3200, "paint": Color(0.35, 0.06, 0.1),
		"desc": "Low-slung coupe in oxblood. Built for the ring road."},
	{"id": "aurora_limo", "name": "Aurora Limo", "price": 5400, "paint": Color(0.82, 0.84, 0.9),
		"desc": "Executive shuttle. The VIP jobs expect to see it."},
]

## Non-player phone contacts. Rook is the valet & mechanic from the design document.
const CONTACTS: Array[Dictionary] = [
	{"id": "mechanic", "name": "Rook Hale", "role": "Valet & Mechanic", "tag": "VALET",
		"greeting": "Hey, how can I help you, or what do you want?"},
]
const PLAYER_SPAWN := Vector3(4, 0.8, 12)
const VEHICLE_SPAWN := Vector3(-8, 0.6, 26)  # parked on the Core ring road, facing +X

const JOBS: Array[Dictionary] = [
	{
		"id": "courier_docks",
		"title": "Courier Run",
		"client": "Neon Docks Freight",
		"desc": "Collect a sealed crate at the Docks freight yard and deliver it to the Heights lobby.",
		"credits": 450, "renown": 120,
		"stages": [
			{"pos": Vector3(-78, 0, 104), "label": "Collect the crate at the Docks freight yard"},
			{"pos": Vector3(78, 0, -104), "label": "Deliver the crate to the Heights lobby"},
		],
	},
	{
		"id": "patrol_core",
		"title": "Perimeter Sweep",
		"client": "City Watch",
		"desc": "Check three watch beacons around the Core. A vehicle is recommended.",
		"credits": 300, "renown": 150,
		"stages": [
			{"pos": Vector3(26, 0, 26), "label": "Reach watch beacon A"},
			{"pos": Vector3(-26, 0, -78), "label": "Reach watch beacon B"},
			{"pos": Vector3(78, 0, 26), "label": "Reach watch beacon C"},
		],
	},
	{
		"id": "shuttle_vip",
		"title": "VIP Shuttle",
		"client": "Aurora Holdings",
		"desc": "Pick up an executive at Core station and drive them to the Heights terrace.",
		"credits": 600, "renown": 200,
		"stages": [
			{"pos": Vector3(26, 0, -26), "label": "Pick up the executive at Core station"},
			{"pos": Vector3(104, 0, -78), "label": "Drop off at the Heights terrace"},
		],
	},
	{
		"id": "relay_scan",
		"title": "Relay Diagnostics",
		"client": "Aetheris Grid",
		"desc": "Run diagnostics on two failing comms relays in the western wards.",
		"credits": 380, "renown": 140,
		"stages": [
			{"pos": Vector3(-78, 0, -26), "label": "Diagnose relay West-1"},
			{"pos": Vector3(-78, 0, 52), "label": "Diagnose relay West-2"},
		],
	},
]

const PROPERTIES: Array[Dictionary] = [
	{"id": "heights_plot_07", "name": "Ridge Plot 7", "district": "The Heights", "price": 950,
		"perk": "Empty plot. +5% job credits.", "position": Vector3(90, 0, -120), "size": Vector3(7, 0.6, 7), "style": "plot"},
	{"id": "heights_villa_01", "name": "Skyline Villa", "district": "The Heights", "price": 1800,
		"perk": "Garage access. +5% job credits.", "position": Vector3(90, 0, -90), "size": Vector3(8, 5, 8), "style": "villa"},
	{"id": "heights_loft_02", "name": "Obsidian Loft", "district": "The Heights", "price": 2400,
		"perk": "Rooftop vantage. +5% job credits.", "position": Vector3(104, 0, -90), "size": Vector3(7, 7, 7), "style": "loft"},
	{"id": "heights_penthouse_03", "name": "Aurora Penthouse", "district": "The Heights", "price": 6500,
		"perk": "Private lift. +5% job credits.", "position": Vector3(118, 0, -90), "size": Vector3(8, 11, 8), "style": "penthouse"},
]

## Armory catalogue for the Spire store. required_rank gates the two-step purchase rule.
const GEAR: Array[Dictionary] = [
	{"id": "obsidian_edge", "name": "Obsidian Edge", "tier": "Mythic", "class": "Swordsman",
		"desc": "Volcanic glass greatsword. +40% strike damage, parry window +0.1s.",
		"required_rank": "C", "price_credits": 4200, "price_points": 900},
	{"id": "voidpiercer", "name": "Voidpiercer", "tier": "Legendary", "class": "Sniper",
		"desc": "Rail-assisted long rifle. Zero bullet drop inside 120m, +1 magazine.",
		"required_rank": "C", "price_credits": 3600, "price_points": 760},
	{"id": "ashen_plating", "name": "Ashen Plating", "tier": "Rare", "class": "Any",
		"desc": "Reinforced chest rig. +25 max health.",
		"required_rank": "D", "price_credits": 800, "price_points": 180},
	{"id": "spire_sigil", "name": "Spire Sigil", "tier": "Legendary", "class": "Any",
		"desc": "Cosmetic emblem. Marks you as a Rank C operative in Nova Aetheris.",
		"required_rank": "C", "price_credits": 1500, "price_points": 320},
]
