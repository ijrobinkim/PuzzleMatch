# tests/unit/test_dragon_box_element.gd
extends GutTest

func test_dragon_box_nest_stage_and_movement():
	var dragon_box = load("res://scripts/elements/concrete/dragon_box_element.gd").new()
	dragon_box.max_health = 3
	dragon_box._ready()
	
	watch_signals(dragon_box)
	dragon_box.take_damage(1)
	assert_signal_emitted(dragon_box, "nest_relocated")
	assert_eq(dragon_box.current_health, 2)
	
	dragon_box.free()
