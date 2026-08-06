# res://scripts/elements/concrete/birdhouse_element.gd
class_name BirdhouseElement
extends "res://scripts/elements/spawner_element.gd"

func _init() -> void:
	element_id = "birdhouse"
	item_to_spawn = "bird"
	spawn_count = 1
	max_health = 2
	is_obstacle = true
	allows_falling = false
