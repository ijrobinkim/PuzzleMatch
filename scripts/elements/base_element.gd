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
var font: Font = ThemeDB.fallback_font

func _ready() -> void:
	current_health = max_health
	queue_redraw()

func take_damage(amount: int = 1) -> void:
	current_health -= amount
	element_damaged.emit(self, current_health)
	queue_redraw()
	
	if is_inside_tree() and get_tree() != null:
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.2, 1.2), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	if current_health <= 0:
		destroy()

func destroy() -> void:
	element_destroyed.emit(self)
	queue_free()

func _draw() -> void:
	var rect := Rect2(-56, -56, 112, 112)
	var main_color := _get_element_color()
	var border_color := _get_element_border_color()
	var icon_text := _get_element_icon()

	# Draw background box
	draw_rect(rect, main_color, true)
	draw_rect(rect, border_color, false, 4.0)

	# Draw diagonal cross pattern for obstacles
	if is_obstacle:
		draw_line(Vector2(-56, -56), Vector2(56, 56), border_color * 0.7, 2.0)
		draw_line(Vector2(56, -56), Vector2(-56, 56), border_color * 0.7, 2.0)

	# Draw Icon Emoji Text
	if font:
		draw_string(font, Vector2(-20, 14), icon_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 36)

	# Draw Health Badge if max_health > 1
	if max_health > 1 and font:
		var badge_rect := Rect2(16, -50, 36, 28)
		draw_rect(badge_rect, Color(0, 0, 0, 0.75), true)
		draw_string(font, Vector2(20, -28), str(current_health), HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color.YELLOW)

func _get_element_color() -> Color:
	match element_id:
		"box": return Color(0.65, 0.45, 0.25, 0.95)
		"snow": return Color(0.75, 0.92, 1.0, 0.65)
		"ivy": return Color(0.15, 0.55, 0.2, 0.9)
		"column": return Color(0.5, 0.5, 0.55, 0.95)
		"birdhouse": return Color(0.8, 0.4, 0.2, 0.95)
		"steam_bomb": return Color(0.2, 0.2, 0.25, 0.95)
		"dragon_box": return Color(0.7, 0.2, 0.8, 0.95)
		_: return Color(0.6, 0.6, 0.6, 0.9)

func _get_element_border_color() -> Color:
	match element_id:
		"box": return Color(0.4, 0.25, 0.1)
		"snow": return Color(0.4, 0.8, 1.0)
		"ivy": return Color(0.05, 0.35, 0.1)
		"column": return Color(0.25, 0.25, 0.3)
		"birdhouse": return Color(0.5, 0.2, 0.05)
		"steam_bomb": return Color(1.0, 0.3, 0.2)
		"dragon_box": return Color(1.0, 0.85, 0.2)
		_: return Color(0.2, 0.2, 0.2)

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

