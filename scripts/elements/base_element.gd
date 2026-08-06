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

func _ready() -> void:
	current_health = max_health

func take_damage(amount: int = 1) -> void:
	current_health -= amount
	element_damaged.emit(self, current_health)
	if current_health <= 0:
		destroy()

func destroy() -> void:
	element_destroyed.emit(self)
	queue_free()
