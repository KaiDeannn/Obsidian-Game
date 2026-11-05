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
const VEHICLE_SPAWN := Vector3(-8, 0.6, 29)  # parked in the inner lane of the Core ring road, facing +X

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

## The Engineer Legendary & Mythic arsenal from the design document. `kind` picks how the
## weapon is used (launcher fires rounds, grenade is thrown, mine is placed) and `trait`
## picks the detonation (see Explosive.gd). Models: assets/weapons/engineer/<id>.glb.
const PREMIUM_CLASS := "Engineer"
const PREMIUM_RARITIES: Array[String] = ["All", "Legendary", "Mythic"]
const PREMIUM_WEAPONS: Array[Dictionary] = [
	{"id": "oathkeeper", "name": "Oathkeeper", "type": "Redcore Grenade Launcher", "rarity": "Mythic", "damage_min": 88, "damage_max": 100, "price": 2800, "limited": true,
		"kind": "launcher", "trait": "blast", "trait_desc": "Slow to fire. Each round arcs true and blasts a 5.5 m area.", "color": Color(1.0, 0.22, 0.15), "radius": 5.5, "cooldown": 1.8, "speed": 30.0, "gravity": 0.6, "burst": 1,
		"image": "res://assets/weapons/engineer/cards/oathkeeper.jpg",
		"desc": "Forged from deep-etched obsidian steel, glowing with molten crimson core. Slow to fire, but each round arcs true: it does not just hit, it claims the whole space. A weapon that demands respect."},
	{"id": "sol_orb", "name": "Sol-Orb", "type": "Solar Energy Grenade", "rarity": "Legendary", "damage_min": 78, "damage_max": 90, "price": 1550, "limited": false,
		"kind": "grenade", "trait": "burn", "trait_desc": "Bursts, then lingering embers keep burning the area for 3.6 s.", "color": Color(1.0, 0.7, 0.2), "radius": 4.5, "cooldown": 1.4,
		"image": "res://assets/weapons/engineer/cards/sol_orb.jpg",
		"desc": "A blazing sphere of pure captured starfire, wrapped in golden light that sears the air. When it bursts, it scatters lingering embers that keep burning long after the flash fades. Bright, intense, and impossible to ignore."},
	{"id": "frost_stasis", "name": "Frost-Stasis", "type": "Cryo-Grenade", "rarity": "Legendary", "damage_min": 30, "damage_max": 45, "price": 1450, "limited": false,
		"kind": "grenade", "trait": "freeze", "trait_desc": "Light damage. Everything caught in the flash is frozen for 3.5 s.", "color": Color(0.4, 0.9, 1.0), "radius": 5.0, "cooldown": 1.6, "freeze_time": 3.5,
		"image": "res://assets/weapons/engineer/cards/frost_stasis.jpg",
		"desc": "Pulsing with icy blue energy: when it bursts, everything caught in the flash slows to a halt. Buy yourself the seconds you need to turn the fight around."},
	{"id": "scarlet_fuse", "name": "Scarlet-Fuse", "type": "Timed-Detonation Grenade", "rarity": "Legendary", "damage_min": 72, "damage_max": 82, "price": 1550, "limited": false,
		"kind": "grenade", "trait": "concussion", "trait_desc": "Timed: the dial counts down 2.5 s, then a shockwave knocks enemies off their feet.", "color": Color(1.0, 0.2, 0.2), "radius": 4.5, "cooldown": 1.6, "fuse": 2.5,
		"image": "res://assets/weapons/engineer/cards/scarlet_fuse.jpg",
		"desc": "Heavy, solid metal casing with glowing red trim. Set your timer: the dial counts down, and then it delivers a sharp, focused shockwave that knocks enemies off their feet without shattering the walls around you."},
	{"id": "hellfire_mine", "name": "Hellfire-Mine", "type": "Proximity Explosive", "rarity": "Legendary", "damage_min": 75, "damage_max": 88, "price": 1450, "limited": false,
		"kind": "mine", "trait": "blast", "trait_desc": "Placed ahead of you. Arms in 1 s and bursts when an enemy steps within 2.8 m. Three at a time.", "color": Color(1.0, 0.5, 0.1), "radius": 5.0, "cooldown": 1.0, "trigger_radius": 2.8, "arm_time": 1.0, "max_active": 3,
		"image": "res://assets/weapons/engineer/cards/hellfire_mine.jpg",
		"desc": "When it opens, it glows like a miniature sun buried in the ground. Step too close, and the panels snap shut: boom. Perfect for watching your back while you move forward."},
	{"id": "void_orb", "name": "Void-Orb", "type": "Dark Energy Grenade", "rarity": "Legendary", "damage_min": 70, "damage_max": 80, "price": 1500, "limited": false,
		"kind": "grenade", "trait": "implosion", "trait_desc": "Pulls everything within 7 m inward, then crushes it.", "color": Color(0.7, 0.3, 1.0), "radius": 7.0, "cooldown": 1.7,
		"image": "res://assets/weapons/engineer/cards/void_orb.jpg",
		"desc": "A perfectly spherical device pulsing with violet light. It doesn't explode outward: it pulls inward, crushing everything caught in its dark field. Silent, sudden, and inescapable."},
	{"id": "sunstone", "name": "Sunstone", "type": "Crystal-Forged Grenade", "rarity": "Mythic", "damage_min": 90, "damage_max": 115, "price": 2600, "limited": true,
		"kind": "grenade", "trait": "shatter", "trait_desc": "Shatter burst over 8 m with a blinding flash. Deadly to stand near, you included.", "color": Color(1.0, 0.8, 0.5), "radius": 8.0, "cooldown": 2.4,
		"image": "res://assets/weapons/engineer/cards/sunstone.jpg",
		"desc": "Ancient crystal holding a fragment of a dying star. When it shatters, it releases blinding light and searing shockwaves. Beautiful to see, deadly to stand near, and everything around it disappears. One of a kind."},
	{"id": "cinder_canister", "name": "Cinder-Canister", "type": "High-Explosive Grenade", "rarity": "Legendary", "damage_min": 65, "damage_max": 75, "price": 1400, "limited": false,
		"kind": "grenade", "trait": "blast", "trait_desc": "Clean, dependable detonation. The fastest grenade to throw again.", "color": Color(1.0, 0.45, 0.15), "radius": 4.5, "cooldown": 1.1,
		"image": "res://assets/weapons/engineer/cards/cinder_canister.jpg",
		"desc": "Solid, reliable tech. Primed by the glowing ring: toss it, and it unleashes a clean, powerful detonation. Built for Nova Aetheris security forces: tough, dependable, no fancy tricks needed."},
	{"id": "sunblaze", "name": "Sunblaze", "type": "Compact Energy Grenade Launcher", "rarity": "Legendary", "damage_min": 42, "damage_max": 50, "price": 1450, "limited": false,
		"kind": "launcher", "trait": "blast", "trait_desc": "Three searing rounds in quick succession.", "color": Color(1.0, 0.55, 0.2), "radius": 2.8, "cooldown": 1.3, "speed": 38.0, "gravity": 0.25, "burst": 3,
		"image": "res://assets/weapons/engineer/cards/sunblaze.jpg",
		"desc": "Crisp, clean, and blazing fast. Launches small, searing energy grenades in quick succession. Light enough to carry, deadly enough to clear a room before they know what hit them."},
	{"id": "skyfall", "name": "Skyfall", "type": "Plasma Rocket Launcher", "rarity": "Legendary", "damage_min": 75, "damage_max": 85, "price": 1600, "limited": false,
		"kind": "launcher", "trait": "blast", "trait_desc": "A compressed-energy bolt that flies straight and detonates on impact with splash damage.", "color": Color(0.3, 0.85, 1.0), "radius": 4.5, "cooldown": 1.5, "speed": 46.0, "gravity": 0.0, "burst": 1,
		"image": "res://assets/weapons/engineer/cards/skyfall.jpg",
		"desc": "Sleek, futuristic, and devastating. Fires bolts of compressed energy that detonate on impact. Built for the battlefield: heavy, reliable, and leaves nowhere to hide."},
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
