# res://scripts/elements/layered_element.gd
class_name LayeredElement
extends BaseElement

signal layer_changed(element: LayeredElement, new_layer: int)

var current_layer: int:
	get:
		return current_health

func take_damage(amount: int = 1) -> void:
	super.take_damage(amount)
	if current_health > 0:
		layer_changed.emit(self, current_health)
