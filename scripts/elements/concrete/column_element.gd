# res://scripts/elements/concrete/column_element.gd
class_name ColumnElement
extends "res://scripts/elements/base_element.gd"

func _init() -> void:
	element_id = "column"
	max_health = 1
	is_obstacle = true
	allows_falling = false
