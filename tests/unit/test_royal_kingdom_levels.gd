# tests/unit/test_royal_kingdom_levels.gd
extends GutTest

func test_royal_kingdom_levels_loading():
	var level_1: LevelData = load("res://resources/levels/level_001.tres")
	assert_not_null(level_1)
	assert_eq(level_1.target_objectives.get("box", 0), 4)
	
	var level_4: LevelData = load("res://resources/levels/level_004.tres")
	assert_not_null(level_4)
	assert_true(level_4.target_objectives.has("snow"))
