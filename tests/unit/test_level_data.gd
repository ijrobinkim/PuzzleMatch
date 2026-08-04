extends GutTest

func test_level_001_has_expected_values():
	var level: LevelData = load("res://resources/levels/level_001.tres")
	assert_eq(level.level_id, "level_001")
	assert_eq(level.grid_width, 8)
	assert_eq(level.grid_height, 8)
	assert_eq(level.tile_type_count, 6)
	assert_eq(level.move_limit, 20)
	assert_eq(level.objective, 1000)
