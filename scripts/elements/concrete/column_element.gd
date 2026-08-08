# res://scripts/elements/concrete/column_element.gd
class_name ColumnElement
extends "res://scripts/elements/base_element.gd"

func _init() -> void:
	element_id = "column"
	max_health = 1
	is_obstacle = true
	allows_falling = false
	# Royal Kingdom design: a column ("Ice Bar" equivalent) is a fixed
	# obstacle destructible only by a special item explosion hitting its own
	# cell directly (rocket/bomb/spinner blast), never by an ordinary
	# adjacent match.
	allows_adjacent_damage = false
