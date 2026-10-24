
extends Resource
class_name QuestData

@export var quest_id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""

@export_category("Objective")
@export var target: int = 1

@export_category("Rewards")
@export var renown_reward: int = 0
@export var credits_reward: int = 0
