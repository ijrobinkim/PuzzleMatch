# res://scripts/elements/concrete/birdhouse_element.gd
class_name BirdhouseElement
extends "res://scripts/elements/spawner_element.gd"

var is_closed: bool = false

func _init() -> void:
	element_id = "birdhouse"
	item_to_spawn = "bird"
	spawn_count = 1
	max_health = 9999
	current_health = 9999
	is_obstacle = true
	allows_falling = false
	allows_adjacent_damage = true

func take_damage(amount: int = 1) -> void:
	if is_closed:
		return
	element_damaged.emit(self, current_health)
	spawn_items()

func close_birdhouse() -> void:
	is_closed = true
	allows_adjacent_damage = false
	_update_visuals()

func _update_visuals() -> void:
	super._update_visuals()
	if _hp_label:
		_hp_label.visible = false
	if _bg_rect:
		_bg_rect.color = Color(0.35, 0.35, 0.4) if is_closed else Color(0.85, 0.5, 0.2)
	if _icon_label:
		_icon_label.text = "닫힘" if is_closed else "새집"
