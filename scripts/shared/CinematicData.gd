class_name CinematicData
## Catalogue of named cinematic sequences for the Cinematic autoload. Positions are world
## coordinates of Nova Aetheris (CityData) unless they are String keys, which the playing
## scene resolves live (CityController resolves "player_back", "player_head", "gate", ...).
## Add a sequence here and any scene can run it with Cinematic.play_named("name").

const SEQUENCES := {
	# Opening of the game: fly in over the Spire gate, sweep The Heights, circle the Core
	# Plaza obelisk, then settle behind the player and hand the camera to gameplay.
	"city_intro": [
		{"type": "fly", "from": {"pos": Vector3(-40, 70, -260), "look": Vector3(0, 10, -146)},
			"to": {"pos": Vector3(24, 34, -190), "look": Vector3(0, 8, -146)},
			"duration": 6.0, "fov": 58, "title": "NOVA AETHERIS", "subtitle": "The living city. Arrive with nothing but your phone."},
		{"type": "fly", "from": {"pos": Vector3(200, 96, -200), "look": Vector3(85, 20, -85)},
			"to": {"pos": Vector3(168, 84, -40), "look": Vector3(80, 24, -80)},
			"duration": 6.0, "fov": 62, "title": "THE HEIGHTS", "subtitle": "Work. Earn. Rent, then build. Every rank unlocks more."},
		{"type": "orbit", "center": Vector3(0, 0, 0), "radius": 29.0, "height": 24.0, "look_height": 10.0,
			"from_angle": 200.0, "to_angle": 330.0, "duration": 6.5, "fov": 60,
			"title": "CORE PLAZA", "subtitle": "The city's heart. Jobs, contacts, and the road to The Spire."},
		{"type": "fly", "from": {"pos": Vector3(26, 16, 18), "look": Vector3(6, 4, 12)},
			"to": "player_back",
			"duration": 4.0, "fov": 70, "ease": "out", "title": "OBSIDIAN", "subtitle": "Fight. Grow. Rank up. Build your legacy."},
	],
	# Short transit when stepping into the Spire gate.
	"gate_transit": [
		{"type": "fly", "from": {"pos": Vector3(0, 6, -120), "look": Vector3(0, 8, -146)},
			"to": {"pos": Vector3(0, 8, -140), "look": Vector3(0, 9, -146)},
			"duration": 1.6, "fov": 70, "ease": "in", "title": "", "subtitle": "Transit to The Spire Ruins"},
	],
	# Match found: the camera rises over the player and points at the gate.
	"match_ready": [
		{"type": "fly", "from": "player_back", "to": "player_high",
			"duration": 2.6, "fov": 66, "ease": "out", "title": "MATCH READY",
			"subtitle": "Your match is ready. Follow the markers to your portal. Good luck!"},
	],
	# Battle start inside the Spire: sweep the arena, then settle behind the fighter.
	"battle_intro": [
		{"type": "orbit", "center": Vector3(0, 0, 0), "radius": 58.0, "height": 26.0, "look_height": 8.0,
			"from_angle": 60.0, "to_angle": 110.0, "duration": 3.2, "fov": 62,
			"title": "THE SPIRE RUINS", "subtitle": "arena"},
		{"type": "fly", "from": {"pos": Vector3(0, 24, 90), "look": Vector3(0, 10, 0)}, "to": "player_back",
			"duration": 2.4, "fov": 70, "ease": "out", "title": "", "subtitle": "Same rank. Any class. No lock-on."},
	],
}
