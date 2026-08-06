# tests/unit/test_steam_bomb_element.gd
extends GutTest

func test_steam_bomb_countdown():
	var bomb = load("res://scripts/elements/concrete/steam_bomb_element.gd").new()
	bomb.turns_remaining = 3
	bomb.max_health = 1
	bomb._ready()
	
	watch_signals(bomb)
	bomb.on_turn_passed()
	assert_eq(bomb.turns_remaining, 2)
	assert_signal_emitted(bomb, "countdown_updated")
	
	bomb.on_turn_passed()
	bomb.on_turn_passed()
	assert_signal_emitted(bomb, "bomb_exploded")
	
	bomb.free()
