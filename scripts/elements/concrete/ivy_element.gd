# res://scripts/elements/concrete/ivy_element.gd
class_name IvyElement
extends "res://scripts/elements/spreader_element.gd"

func _init() -> void:
	element_id = "ivy"
	max_health = 1
	is_obstacle = false
	allows_falling = true
	allows_self_damage = false
	allows_adjacent_damage = true
