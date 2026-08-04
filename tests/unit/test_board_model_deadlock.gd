extends GutTest

func _make_level(w: int, h: int, types: int) -> LevelData:
	var level := LevelData.new()
	level.grid_width = w
	level.grid_height = h
	level.tile_type_count = types
	level.move_limit = 20
	level.objective = 1000000
	return level

func test_checkerboard_of_two_colors_has_no_valid_move():
	var board := BoardModel.new(_make_level(4, 4, 6), 1)
	for x in 4:
		for y in 4:
			board.types[x][y] = (x + y) % 2
	assert_false(board.has_any_valid_move())

func test_grid_with_a_possible_match_has_a_valid_move():
	var board := BoardModel.new(_make_level(4, 1, 6), 1)
	board.types[0][0] = 0
	board.types[1][0] = 0
	board.types[2][0] = 1
	board.types[3][0] = 0
	assert_true(board.has_any_valid_move())

func test_reshuffle_produces_a_board_with_no_match_and_a_valid_move():
	var board := BoardModel.new(_make_level(6, 6, 6), 1)
	var watcher = watch_signals(board)
	board.reshuffle()
	assert_eq(board.find_matches().size(), 0)
	assert_true(board.has_any_valid_move())
	assert_signal_emitted(board, "board_reshuffled")
