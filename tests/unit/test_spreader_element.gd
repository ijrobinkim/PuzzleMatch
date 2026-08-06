# tests/unit/test_spreader_element.gd
extends GutTest

func test_spreader_element_spread():
	var element = load("res://scripts/elements/spreader_element.gd").new()
	element.max_health = 1
	element._ready()
	
	watch_signals(element)
	var targets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
	var chosen = element.try_spread(targets)
	assert_signal_emitted(element, "element_spread")
	assert_true(chosen in targets)
	
	element.free()
