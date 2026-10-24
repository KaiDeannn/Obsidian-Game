
extends Node

signal renown_changed(total_renown: int)
signal rank_changed(old_rank: String, new_rank: String)
signal rank_up_message(message: String, new_rank: String)

const RANKS: Array[Dictionary] = [
	{"name": "D", "renown": 0},
	{"name": "C", "renown": 100},
	{"name": "B", "renown": 300},
	{"name": "A", "renown": 700},
	{"name": "S", "renown": 1500}
]


const RANK_UP_TEXT: String = "Congratulations — you have advanced to your new rank! Your class has grown stronger. New opportunities are now available to you."


func _ready() -> void:
	Globalvar.current_rank = get_rank_for_renown(
		Globalvar.current_renown
	)


func get_rank_for_renown(amount: int) -> String:
	var result: String = "D"

	for rank_data in RANKS:
		if amount >= int(rank_data["renown"]):
			result = str(rank_data["name"])
		else:
			break

	return result


func add_renown(amount: int, source: String = "") -> void:
	if amount <= 0:
		return

	var old_rank: String = Globalvar.current_rank

	Globalvar.current_renown += amount

	var new_rank: String = get_rank_for_renown(
		Globalvar.current_renown
	)

	Globalvar.current_rank = new_rank

	print(
		"Renown +", amount,
		" | Total: ", Globalvar.current_renown,
		" | Source: ", source
	)

	renown_changed.emit(Globalvar.current_renown)

	if new_rank != old_rank:
		rank_changed.emit(old_rank, new_rank)
		rank_up_message.emit(RANK_UP_TEXT, new_rank)

		print("RANK UP: ", old_rank, " -> ", new_rank)


func get_rank_index(rank: String) -> int:
	for i in range(RANKS.size()):
		if str(RANKS[i]["name"]) == rank:
			return i

	return -1


func meets_rank(required_rank: String) -> bool:
	var player_rank_index: int = get_rank_index(
		Globalvar.current_rank
	)
	var required_rank_index: int = get_rank_index(
		required_rank
	)

	if required_rank_index == -1 or player_rank_index == -1:
		return false

	return player_rank_index >= required_rank_index


func get_next_rank() -> Dictionary:
	for rank_data in RANKS:
		if Globalvar.current_renown < int(rank_data["renown"]):
			return rank_data

	return {}


func get_renown_to_next_rank() -> int:
	var next_rank: Dictionary = get_next_rank()

	if next_rank.is_empty():
		return 0

	return maxi(
		0,
		int(next_rank["renown"]) - Globalvar.current_renown
	)


func get_rank_progress_text() -> String:
	var next_rank: Dictionary = get_next_rank()

	if next_rank.is_empty():
		return "Maximum Rank: S"

	return "%d Renown to Rank %s" % [
		get_renown_to_next_rank(),
		str(next_rank["name"])
	]
