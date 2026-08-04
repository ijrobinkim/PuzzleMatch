extends GutTest

func _make_level(w: int, h: int, types: int) -> LevelData:
	var level := LevelData.new()
	level.grid_width = w
	level.grid_height = h
	level.tile_type_count = types
	level.move_limit = 20
	level.objective = 1000000
	return level

func test_latin_square_has_no_valid_move():
	# 3x3 Latin square: each row and column is a permutation of {0,1,2}.
	# No single adjacent swap can create a run of 3 (would require changing
	# a permutation-row/column from e.g. [a,b,c] to [a,a,c], which needs
	# two cells to match, but we can only swap one).
	var board := BoardModel.new(_make_level(3, 3, 6), 1)
	board.types[0][0] = 0; board.types[1][0] = 1; board.types[2][0] = 2
	board.types[0][1] = 1; board.types[1][1] = 2; board.types[2][1] = 0
	board.types[0][2] = 2; board.types[1][2] = 0; board.types[2][2] = 1
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
