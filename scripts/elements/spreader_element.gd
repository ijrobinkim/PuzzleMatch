# res://scripts/elements/spreader_element.gd
class_name SpreaderElement
extends BaseElement

signal element_spread(element: SpreaderElement, target_position: Vector2i)

func try_spread(available_positions: Array[Vector2i]) -> Vector2i:
	if available_positions.is_empty():
		return Vector2i(-1, -1)
	
	var target = available_positions.pick_random()
	element_spread.emit(self, target)
	return target
