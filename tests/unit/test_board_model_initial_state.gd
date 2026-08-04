extends GutTest

func _make_level(w: int, h: int, types: int) -> LevelData:
	var level := LevelData.new()
	level.grid_width = w
	level.grid_height = h
	level.tile_type_count = types
	level.move_limit = 20
	level.objective = 1000
	return level

func test_initial_board_never_has_a_match():
	for seed_value in range(20):
		var board := BoardModel.new(_make_level(8, 8, 6), seed_value)
		assert_eq(board.find_matches().size(), 0, "seed %d produced an initial match" % seed_value)
