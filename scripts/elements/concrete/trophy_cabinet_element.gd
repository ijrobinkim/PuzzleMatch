# res://scripts/elements/concrete/trophy_cabinet_element.gd
class_name TrophyCabinetElement
extends "res://scripts/elements/base_element.gd"

func _init() -> void:
	element_id = "trophy_cabinet"
	max_health = 11
	current_health = 11
	is_obstacle = true
	allows_falling = false
	allows_adjacent_damage = true

func _build_visual_nodes() -> void:
	super._build_visual_nodes()
	# 2x2 multi-cell scaling (256x256 pixels for 128 CELL_SIZE)
	if _bg_rect:
		_bg_rect.size = Vector2(256, 256)
		_bg_rect.position = Vector2(-128, -128)
	if _icon_label:
		_icon_label.size = Vector2(256, 256)
		_icon_label.position = Vector2(-128, -128)
		_icon_label.add_theme_font_size_override("font_size", 64)

func _update_visuals() -> void:
	super._update_visuals()
	if _hp_label:
		_hp_label.visible = false
	if _bg_rect:
		_bg_rect.color = Color(0.3, 0.25, 0.45) if current_health == 11 else Color(0.85, 0.65, 0.15)
	if _icon_label:
		if current_health >= 11:
			_icon_label.text = "🚪🔒"
		else:
			_icon_label.text = "🏆 %d" % current_health
