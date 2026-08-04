extends GutTest

func _make_level(w: int, h: int, types: int, move_limit: int = 20, objective: int = 1000000) -> LevelData:
	var level := LevelData.new()
	level.grid_width = w
	level.grid_height = h
	level.tile_type_count = types
	level.move_limit = move_limit
	level.objective = objective
	return level

func _flat_board(w: int, h: int, rows: Array, move_limit: int = 20, objective: int = 1000000) -> BoardModel:
	var board := BoardModel.new(_make_level(w, h, 6, move_limit, objective), 1)
	for x in w:
		for y in h:
			board.types[x][y] = rows[y][x]
			board.bonuses[x][y] = BoardModel.BONUS_NONE
	return board

func test_accepted_swap_emits_swap_committed_with_the_swapped_cells():
	# Swapping (2,0) and (2,1) makes row 0 read [0,0,0,1] -> a match.
	var board := _flat_board(4, 2, [
		[0, 0, 1, 1],
		[2, 2, 0, 3],
	])
	var watcher = watch_signals(board)
	board.attempt_swap(Vector2i(2, 0), Vector2i(2, 1))
	assert_signal_emitted_with_parameters(board, "swap_committed", [Vector2i(2, 0), Vector2i(2, 1)])

func test_swap_that_creates_a_match_is_accepted_and_clears_cells():
	# Swapping (2,0) and (2,1) makes row 0 read [0,0,0,1] -> a match.
	var board := _flat_board(4, 2, [
		[0, 0, 1, 1],
		[2, 2, 0, 3],
	])
	var result := board.attempt_swap(Vector2i(2, 0), Vector2i(2, 1))
	assert_true(result)
	# Task 8 added gravity + refill to the cascade, so cleared cells no
	# longer stay EMPTY_TYPE after the swap resolves; they get refilled with
	# a valid tile type instead.
	var refilled_type: int = board.get_tile_type(Vector2i(0, 0))
	assert_true(refilled_type >= 0 and refilled_type < board.tile_type_count, "cell should have been refilled with a valid tile type, got %d" % refilled_type)
	assert_eq(board.moves_remaining, 19)

func test_swap_that_creates_no_match_is_rejected_and_reverted():
	var board := _flat_board(4, 2, [
		[0, 1, 2, 3],
		[1, 2, 3, 0],
	])
	var watcher = watch_signals(board)
	var result := board.attempt_swap(Vector2i(0, 0), Vector2i(1, 0))
	assert_false(result)
	assert_eq(board.get_tile_type(Vector2i(0, 0)), 0)
	assert_eq(board.get_tile_type(Vector2i(1, 0)), 1)
	assert_eq(board.moves_remaining, 20)
	assert_signal_emitted(board, "swap_rejected")

func test_non_adjacent_swap_is_rejected():
	var board := _flat_board(4, 2, [
		[0, 1, 2, 3],
		[1, 2, 3, 0],
	])
	var result := board.attempt_swap(Vector2i(0, 0), Vector2i(2, 0))
	assert_false(result)

func test_level_fails_when_moves_run_out_without_reaching_objective():
	var board := _flat_board(4, 2, [
		[0, 0, 1, 1],
		[2, 2, 0, 3],
	], 1, 1000000)
	var watcher = watch_signals(board)
	board.attempt_swap(Vector2i(2, 0), Vector2i(2, 1))
	assert_eq(board.moves_remaining, 0)
	assert_signal_emitted(board, "level_failed")
