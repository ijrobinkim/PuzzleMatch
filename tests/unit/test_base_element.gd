# tests/unit/test_base_element.gd
extends GutTest

func test_base_element_damage_and_destruction():
	var element = load("res://scripts/elements/base_element.gd").new()
	element.max_health = 2
	element._ready()
	
	watch_signals(element)
	element.take_damage(1)
	assert_signal_emitted(element, "element_damaged")
	assert_eq(element.current_health, 1)
	
	element.take_damage(1)
	assert_signal_emitted(element, "element_destroyed")
	element.free()
