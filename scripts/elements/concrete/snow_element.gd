# res://scripts/elements/concrete/snow_element.gd
class_name SnowElement
extends "res://scripts/elements/base_element.gd"

func _init() -> void:
	element_id = "snow"
	max_health = 1
	is_obstacle = false
	allows_falling = true
