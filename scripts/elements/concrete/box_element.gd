# res://scripts/elements/concrete/box_element.gd
class_name BoxElement
extends "res://scripts/elements/layered_element.gd"

func _init() -> void:
	element_id = "box"
	max_health = 1
	is_obstacle = true
	allows_falling = false
