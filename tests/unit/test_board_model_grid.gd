extends GutTest

func _make_level(w: int, h: int, types: int) -> LevelData:
	var level := LevelData.new()
	level.grid_width = w
	level.grid_height = h
	level.tile_type_count = types
	level.move_limit = 20
	level.objective = 1000
	return level

func test_grid_has_correct_dimensions():
	var board := BoardModel.new(_make_level(5, 7, 6), 1)
	assert_eq(board.width, 5)
	assert_eq(board.height, 7)
	for x in 5:
		assert_eq(board.types[x].size(), 7)

func test_all_tile_types_are_in_range():
	var board := BoardModel.new(_make_level(8, 8, 6), 1)
	for x in 8:
		for y in 8:
			var t: int = board.get_tile_type(Vector2i(x, y))
			assert_true(t >= 0 and t < 6)

func test_is_in_bounds():
	var board := BoardModel.new(_make_level(4, 4, 6), 1)
	assert_true(board.is_in_bounds(Vector2i(0, 0)))
	assert_true(board.is_in_bounds(Vector2i(3, 3)))
	assert_false(board.is_in_bounds(Vector2i(4, 0)))
	assert_false(board.is_in_bounds(Vector2i(-1, 0)))
