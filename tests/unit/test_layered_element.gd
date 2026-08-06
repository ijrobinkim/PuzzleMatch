# tests/unit/test_layered_element.gd
extends GutTest

func test_layered_element_layers():
	var element = load("res://scripts/elements/layered_element.gd").new()
	element.max_health = 3
	element._ready()
	
	assert_eq(element.current_layer, 3)
	element.take_damage(1)
	assert_eq(element.current_layer, 2)
	assert_eq(element.current_health, 2)
	
	element.free()
