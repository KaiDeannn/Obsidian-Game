class_name BattleData
## Static data for the battle system (design document: "Match Setup - Solo, Tournament and
## Clan Wars", "Class Zones", "Vision System"). BattleManager reads it; the phone's BATTLES
## app and the Spire match controller render it.

## Battlefield maps the system can pick from. The player and the opponent each state a
## preference; if they differ the system picks at random (the document's rule).
const MAPS: Array[Dictionary] = [
	{"id": "ruins", "name": "Ruins Arena", "desc": "War-torn plaza: the shattered spire, colonnade corridors, two high vantage decks."},
	{"id": "rooftop", "name": "Rooftop Arena", "desc": "Five roofs at different heights joined by ramps. Long sightlines, short cover."},
	{"id": "forest", "name": "Forest Arena", "desc": "Dense trunks and fallen logs. Short sightlines, ambush ground."},
]

const MODES := {
	"solo": {"name": "Solo Battle", "desc": "Challenge one opponent of exactly your rank. Die and the attempt restarts from the beginning.",
		"win_renown": 120, "win_points": 60, "loss_renown": 25, "loss_points": 0},
	"tournament": {"name": "Tournament", "desc": "Three rounds against opponents of your tier. Eliminated fighters spectate until the match ends.",
		"win_renown": 300, "win_points": 250, "loss_renown": 40, "loss_points": 20, "round_renown": 60, "round_points": 40, "rounds": 3},
	"clan_war": {"name": "Clan War", "desc": "Your clan against a rival clan at one rank tier, five a side. First to the kill target wins.",
		"win_renown": 250, "win_points": 180, "loss_renown": 40, "loss_points": 15, "kill_target": 8, "time_limit": 240.0},
}

## Every class in the design document, with the weapon category its vision dot reports.
const CLASSES: Array[Dictionary] = [
	{"name": "Swordsman", "weapon": "melee", "zone": "Central Plaza"},
	{"name": "Sniper", "weapon": "ranged", "zone": "High Spires"},
	{"name": "Ninja", "weapon": "thrown", "zone": "Shadow Corridors"},
	{"name": "Archer", "weapon": "ranged", "zone": "Mid-Tier Balconies"},
	{"name": "Assault", "weapon": "ranged", "zone": "Ramp Entrances"},
	{"name": "Engineer", "weapon": "explosive", "zone": "Chokepoints"},
]

## Vision-dot colour per weapon category (document: dots tell you the weapon category).
const WEAPON_COLORS := {
	"melee": Color(1.0, 0.33, 0.38),
	"ranged": Color(1.0, 0.72, 0.25),
	"thrown": Color(0.85, 0.4, 1.0),
	"explosive": Color(1.0, 0.5, 0.15),
}

const OPPONENT_NAMES := ["Vex Marlow", "Sable Quinn", "Dorian Ashe", "Kestrel Nyx", "Rook Tanaka", "Ivy Calder",
	"Oren Blackwood", "Mira Solis", "Jett Varga", "Lyra Thorne", "Castor Vale", "Nadia Krell"]

## Your clan roster for Clan Wars. Leaders may only pick members who are online and at the
## war's rank tier, up to five a side.
const CLAN := {"name": "Ashfall", "rival": "Ironveil"}
const CLAN_MEMBERS: Array[Dictionary] = [
	{"name": "Juno Hale", "class": "Sniper", "rank": "D", "online": true},
	{"name": "Teo Varga", "class": "Swordsman", "rank": "D", "online": true},
	{"name": "Ilse Moor", "class": "Sniper", "rank": "C", "online": true},
	{"name": "Bram Okafor", "class": "Assault", "rank": "D", "online": true},
	{"name": "Sera Lind", "class": "Ninja", "rank": "D", "online": false},
	{"name": "Kael Dusk", "class": "Engineer", "rank": "D", "online": true},
	{"name": "Wren Castell", "class": "Archer", "rank": "C", "online": true},
]

const MATCH_READY_MESSAGE := "Your match is ready. Follow the markers to your portal. Good luck!"


static func map_by_id(id: String) -> Dictionary:
	for m in MAPS:
		if m["id"] == id:
			return m
	return MAPS[0]


static func class_info(class_name_: String) -> Dictionary:
	for c in CLASSES:
		if c["name"] == class_name_:
			return c
	return CLASSES[0]
