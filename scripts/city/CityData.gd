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

## Premium Shop: the Ninja Legendary & Mythic weapon collection, paid in Aether (premium currency).
const PREMIUM_CLASS := "Ninja"
const PREMIUM_RARITIES: Array[String] = ["All", "Rare", "Legendary", "Mythic"]
const PREMIUM_WEAPONS: Array[Dictionary] = [
	{"id": "phantom_flame", "kind": "dagger", "trait": "phantom", "trait_desc": "Weightless: strikes come out 30% faster.", "color": Color(1.0, 0.18, 0.12), "name": "The Phantom Flame", "rarity": "Rare", "damage_min": 40, "damage_max": 65, "price": 750, "limited": false,
		"image": "res://assets/premium/ninja/phantom_flame.jpg",
		"desc": "A blade made of nothing but flickering red light and smoke. No weight, no sound, only the glow. It's there until it isn't."},
	{"id": "prisma_guard", "kind": "dagger", "trait": "quickdraw", "trait_desc": "Compact dagger: 40% faster strikes and a longer lunge.", "color": Color(0.2, 0.85, 1.0), "name": "The Prisma-Guard", "rarity": "Legendary", "damage_min": 70, "damage_max": 85, "price": 1800, "limited": false, "note": "Will be modelled as a small ninja dagger.",
		"image": "res://assets/premium/ninja/prisma_guard.jpg",
		"desc": "A compact, geometric dark-alloy dagger lined with blinding cyan light. Small enough to hide in a fold of cloth, yet sharp enough to slip through defenses like a shard of frozen starlight."},
	{"id": "last_honour", "kind": "katana", "trait": "honour", "trait_desc": "Every takedown restores 25 health.", "color": Color(1.0, 0.85, 0.55), "name": "The Last Honour", "rarity": "Mythic", "damage_min": 100, "damage_max": 110, "price": 2600, "limited": true,
		"image": "res://assets/premium/ninja/last_honour.jpg",
		"desc": "Hand-forged steel etched with the words of its maker, a reminder that true strength comes from what you protect, not what you conquer."},
	{"id": "ember_guardian", "kind": "blade", "trait": "guardian", "trait_desc": "Blocking takes half the chip damage and the parry window is longer.", "color": Color(1.0, 0.55, 0.2), "name": "The Ember Guardian", "rarity": "Legendary", "damage_min": 54, "damage_max": 63, "price": 1450, "limited": false,
		"image": "res://assets/premium/ninja/ember_guardian.jpg",
		"desc": "Weathered iron and warm bronze, an ancient blade passed down through forgotten generations. It doesn't need to shine to be deadly."},
	{"id": "the_ruin", "kind": "star", "trait": "unbroken", "trait_desc": "Thrown. Pierces through up to three enemies in a line.", "color": Color(0.95, 0.9, 0.7), "name": "The Ruin", "rarity": "Mythic", "damage_min": 55, "damage_max": 65, "price": 1800, "limited": false,
		"image": "res://assets/premium/ninja/the_ruin.jpg",
		"desc": "Four points of blessed steel, etched with swirling ancient scrollwork. It catches the light even in deepest shadow, a promise that some things remain unbroken."},
	{"id": "ember_scythe", "kind": "triblade", "trait": "burning", "trait_desc": "Thrown. Targets burn for 3 x 8 damage afterwards.", "color": Color(1.0, 0.55, 0.1), "name": "The Ember-Scythe", "rarity": "Legendary", "damage_min": 48, "damage_max": 56, "price": 950, "limited": false,
		"image": "res://assets/premium/ninja/ember_scythe.jpg",
		"desc": "Three curved blades of dark obsidian, veins of molten gold glowing along every edge. Spins through the air like a falling star: silent, burning, and impossible to catch."},
	{"id": "the_crescent", "kind": "triblade", "trait": "returns", "trait_desc": "Thrown. Flies back to your hand and can hit on the way home.", "color": Color(0.45, 0.95, 0.9), "name": "The Crescent", "rarity": "Legendary", "damage_min": 45, "damage_max": 52, "price": 880, "limited": false,
		"image": "res://assets/premium/ninja/the_crescent.jpg",
		"desc": "Three graceful blades of pale steel and gold, inlaid with soft cyan light. Balanced and true, it always finds its mark, then returns to the hand like a whisper on the wind."},
	{"id": "thunder_chain", "kind": "chain", "trait": "storm", "trait_desc": "Sweeps every enemy within 4.5 m in a full circle.", "color": Color(0.35, 0.65, 1.0), "name": "The Thunder Chain", "rarity": "Legendary", "damage_min": 52, "damage_max": 60, "price": 1600, "limited": false,
		"image": "res://assets/premium/ninja/thunder_chain.jpg",
		"desc": "A flexible ring of linked axe-blades crackling with electric blue energy. Spins wide, strikes fast; the storm itself seems to turn where it swings."},
	{"id": "dragons_breath", "kind": "flame", "trait": "dragonfire", "trait_desc": "Every third strike breathes a flame wave 6 m ahead.", "color": Color(1.0, 0.25, 0.2), "name": "The Dragon's Breath", "rarity": "Mythic", "damage_min": 72, "damage_max": 85, "price": 3200, "limited": false,
		"image": "res://assets/premium/ninja/dragons_breath.jpg",
		"desc": "Jagged flame-shaped blade of silver and obsidian, etched with ancient red script. Hilt carved like a golden dragon's head: fierce, legendary, unyielding. Only one exists in Nova Aetheris."},
	{"id": "starlit_edge", "kind": "katana", "trait": "starlit", "trait_desc": "40% longer reach and a 25% chance to crit for double damage.", "color": Color(0.3, 0.9, 1.0), "name": "The Starlit Edge", "rarity": "Legendary", "damage_min": 58, "damage_max": 68, "price": 1800, "limited": false,
		"image": "res://assets/premium/ninja/starlit_edge.jpg",
		"desc": "Sleek black blade glowing with pure cyan light along its edge. It doesn't just cut, it feels like it passes through space itself. Quiet, precise, and impossibly sharp."},
	{"id": "starfall_dagger", "kind": "crystal", "trait": "pull", "trait_desc": "Hits pull the enemy toward you and stagger it.", "color": Color(0.85, 0.4, 1.0), "name": "The Starfall Dagger", "rarity": "Legendary", "damage_min": 36, "damage_max": 44, "price": 1100, "limited": false,
		"image": "res://assets/premium/ninja/starfall_dagger.jpg",
		"desc": "A blade of pale crystal holding swirling violet mist at its heart. Hilt blooms like a dark rose, soft pink light pulsing from within. It doesn't just cut; it feels like it pulls something loose."},
	{"id": "golden_razor", "kind": "razor", "trait": "razor", "trait_desc": "Thrown fast. Ricochets to a second enemy within 7 m.", "color": Color(1.0, 0.85, 0.3), "name": "The Golden Razor", "rarity": "Legendary", "damage_min": 38, "damage_max": 45, "price": 680, "limited": false,
		"image": "res://assets/premium/ninja/golden_razor.jpg",
		"desc": "Sharp, polished gold shaped like a jagged R: sleek, heavy, and catches the light like a mirror. It cuts before you even see it coming."},
]

static func premium_weapon(id: String) -> Dictionary:
	for w in PREMIUM_WEAPONS:
		if w["id"] == id:
			return w
	return {}

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
