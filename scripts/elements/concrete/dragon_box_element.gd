# res://scripts/elements/concrete/dragon_box_element.gd
class_name DragonBoxElement
extends "res://scripts/elements/layered_element.gd"

signal nest_relocated(element: DragonBoxElement, new_grid_pos: Vector2i)

func _init() -> void:
	element_id = "dragon_box"
	max_health = 3
	is_obstacle = true
	allows_falling = false

func take_damage(amount: int = 1) -> void:
	super.take_damage(amount)
	if current_health > 0:
		relocate_nest()

func relocate_nest() -> void:
	# Signal to board controller to move nest to adjacent available cell
	nest_relocated.emit(self, grid_position)
