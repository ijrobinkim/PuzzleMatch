# res://scripts/elements/base_element.gd
class_name BaseElement
extends Node2D

signal element_damaged(element: BaseElement, current_health: int)
signal element_destroyed(element: BaseElement)

@export var element_id: String = ""
@export var max_health: int = 1
@export var is_obstacle: bool = true
@export var allows_falling: bool = false

var current_health: int = 1
var grid_position: Vector2i = Vector2i.ZERO

var _bg_rect: ColorRect
var _icon_label: Label
var _hp_label: Label

func _ready() -> void:
	current_health = max_health
	_build_visual_nodes()
	_update_visuals()

func _build_visual_nodes() -> void:
	if has_node("BG"):
		_bg_rect = get_node("BG") as ColorRect
		_icon_label = get_node("Icon") as Label
		_hp_label = get_node("HP") as Label
		return

	_bg_rect = ColorRect.new()
	_bg_rect.name = "BG"
	_bg_rect.size = Vector2(100, 100)
	_bg_rect.position = Vector2(-50, -50)
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_rect)

	_icon_label = Label.new()
	_icon_label.name = "Icon"
	_icon_label.size = Vector2(100, 100)
	_icon_label.position = Vector2(-50, -50)
	_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_label.add_theme_font_size_override("font_size", 42)
	add_child(_icon_label)

	_hp_label = Label.new()
	_hp_label.name = "HP"
	_hp_label.size = Vector2(40, 30)
	_hp_label.position = Vector2(10, -45)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_label.add_theme_font_size_override("font_size", 20)
	_hp_label.add_theme_color_override("font_color", Color.YELLOW)
	add_child(_hp_label)

func take_damage(amount: int = 1) -> void:
	current_health -= amount
	element_damaged.emit(self, current_health)
	_update_visuals()
	
	if is_inside_tree() and get_tree() != null:
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.25, 1.25), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	if current_health <= 0:
		destroy()

func destroy() -> void:
	element_destroyed.emit(self)
	queue_free()

func _update_visuals() -> void:
	if _bg_rect:
		_bg_rect.color = _get_element_color()
	if _icon_label:
		_icon_label.text = _get_element_icon()
	if _hp_label:
		if max_health > 1 and current_health > 0:
			_hp_label.text = str(current_health)
			_hp_label.visible = true
		else:
			_hp_label.visible = false

func _get_element_color() -> Color:
	match element_id:
		"box": return Color(0.7, 0.45, 0.2)
		"snow": return Color(0.6, 0.85, 1.0)
		"ivy": return Color(0.1, 0.6, 0.2)
		"column": return Color(0.5, 0.5, 0.6)
		"birdhouse": return Color(0.85, 0.4, 0.15)
		"steam_bomb": return Color(0.2, 0.2, 0.3)
		"dragon_box": return Color(0.7, 0.2, 0.8)
		_: return Color(0.5, 0.5, 0.5)

func _get_element_icon() -> String:
	match element_id:
		"box": return "📦"
		"snow": return "❄️"
		"ivy": return "🌿"
		"column": return "🏛️"
		"birdhouse": return "🐦"
		"steam_bomb": return "💣"
		"dragon_box": return "🐉"
		_: return "❓"
