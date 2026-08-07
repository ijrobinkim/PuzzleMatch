# res://scripts/elements/concrete/snow_element.gd
class_name SnowElement
extends "res://scripts/elements/layered_element.gd"

func _init() -> void:
	element_id = "snow"
	max_health = 2
	current_health = 2
	is_obstacle = false
	allows_falling = true
	allows_adjacent_damage = false

func _update_visuals() -> void:
	super._update_visuals()
	if _bg_rect:
		var alpha: float = 1.0 if current_health >= 2 else 0.4
		_bg_rect.color.a = alpha
	if _icon_label:
		_icon_label.modulate.a = 1.0 if current_health >= 2 else 0.5
