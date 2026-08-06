# res://scripts/elements/concrete/steam_bomb_element.gd
class_name SteamBombElement
extends "res://scripts/elements/base_element.gd"

signal countdown_updated(element: SteamBombElement, turns_remaining: int)
signal bomb_exploded(element: SteamBombElement)

@export var turns_remaining: int = 5

func _init() -> void:
	element_id = "steam_bomb"
	max_health = 1
	is_obstacle = true
	allows_falling = false

func on_turn_passed() -> void:
	if current_health <= 0:
		return
	turns_remaining -= 1
	countdown_updated.emit(self, turns_remaining)
	if turns_remaining <= 0:
		explode()

func explode() -> void:
	bomb_exploded.emit(self)
	destroy()
