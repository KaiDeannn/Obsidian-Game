extends Node
## RankManager (autoload "RankManager")
## Owns Renown and the rank ladder D -> C -> B -> A -> S.
## Any system that awards Renown calls add_renown(); the ladder check is automatic
## and rank_advanced drives the global RankModal ("Congratulations - Advanced to Rank C").

signal renown_changed(renown: int, gained: int)
signal rank_advanced(new_rank: String, old_rank: String)

const RANKS: Array[String] = ["D", "C", "B", "A", "S"]
const THRESHOLDS: Array[int] = [0, 500, 1500, 3500, 7000]

var renown: int = 0
var rank_index: int = 0


func add_renown(amount: int) -> void:
	if amount <= 0:
		return
	renown += amount
	renown_changed.emit(renown, amount)
	_check_advancement()


func _check_advancement() -> void:
	while rank_index < RANKS.size() - 1 and renown >= THRESHOLDS[rank_index + 1]:
		var old := RANKS[rank_index]
		rank_index += 1
		rank_advanced.emit(RANKS[rank_index], old)


func rank_letter() -> String:
	return RANKS[rank_index]


func current_threshold() -> int:
	return THRESHOLDS[rank_index]


## -1 when the player already holds the top rank.
func next_threshold() -> int:
	if rank_index >= RANKS.size() - 1:
		return -1
	return THRESHOLDS[rank_index + 1]


func progress_ratio() -> float:
	var nxt := next_threshold()
	if nxt < 0:
		return 1.0
	var cur := current_threshold()
	return clampf(float(renown - cur) / float(nxt - cur), 0.0, 1.0)


func rank_index_of(letter: String) -> int:
	return RANKS.find(letter)


func meets_rank(required: String) -> bool:
	return rank_index >= rank_index_of(required)


func rank_color(letter: String) -> Color:
	match letter:
		"D": return Color(0.65, 0.68, 0.75)
		"C": return Color(0.21, 0.89, 1.0)
		"B": return Color(0.35, 1.0, 0.55)
		"A": return Color(1.0, 0.8, 0.3)
		"S": return Color(0.95, 0.4, 1.0)
	return Color.WHITE
