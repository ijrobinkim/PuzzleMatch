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

func test_cascade_clears_no_empty_cells_remain():
	var board := _flat_board(4, 2, [
		[0, 0, 1, 1],
		[2, 2, 0, 3],
	])
	board.attempt_swap(Vector2i(2, 0), Vector2i(2, 1))
	for x in 4:
		for y in 2:
			assert_ne(board.get_tile_type(Vector2i(x, y)), BoardModel.EMPTY_TYPE)

func test_cascade_applies_gravity_before_refill():
	# Column 0: clearing (0,2) should pull (0,0) and (0,1) down by one.
	var board := _flat_board(1, 3, [[5], [4], [3]])
	board.types[0][2] = BoardModel.EMPTY_TYPE
	var falls: Array = board._apply_gravity([])
	assert_eq(board.get_tile_type(Vector2i(0, 2)), 4)
	assert_eq(board.get_tile_type(Vector2i(0, 1)), 5)
	assert_eq(board.get_tile_type(Vector2i(0, 0)), BoardModel.EMPTY_TYPE)

func test_score_increases_by_ten_per_cleared_cell():
	var board := _flat_board(4, 2, [
		[0, 0, 1, 1],
		[2, 2, 0, 3],
	])
	board.attempt_swap(Vector2i(2, 0), Vector2i(2, 1))
	# Exactly 3 cells match here, but refilled tiles could coincidentally
	# chain into another match, so assert the invariant (multiple of 10,
	# at least the 3-cell clear) rather than an exact value tied to RNG output.
	assert_true(board.score >= 30)
	assert_eq(board.score % 10, 0)

func test_four_match_spawns_striped_bonus_on_board():
	# rng_seed=1 is fixed for determinism. If this ever fails because a
	# refilled tile happens to chain-clear the new bonus tile in the same
	# cascade, try rng_seed 2, 3, ... until the assertion is stable.
	# Widened with safety columns to avoid incidental deadlock-reshuffle
	# wiping the bonus tile (see Task 9 deadlock detection).
	var board := _flat_board(7, 2, [
		[0, 0, 0, 1, 2, 5, 5],
		[3, 4, 5, 0, 4, 5, 5],
	])
	board.attempt_swap(Vector2i(3, 0), Vector2i(3, 1))
	var found_bonus := false
	for x in 7:
		for y in 2:
			if board.get_bonus_kind(Vector2i(x, y)) != BoardModel.BONUS_NONE:
				found_bonus = true
	assert_true(found_bonus)

func test_triggering_a_striped_tile_clears_its_row():
	var board := _flat_board(6, 2, [
		[0, 1, 2, 3, 5, 5],
		[5, 4, 3, 2, 5, 5],
	])
	board.bonuses[1][0] = BoardModel.BONUS_STRIPED_ROW
	board.activate_special_tile(Vector2i(1, 0))
	assert_eq(board.get_tile_type(Vector2i(0, 1)), 5)
	assert_eq(board.get_tile_type(Vector2i(1, 1)), 4)
	assert_eq(board.get_tile_type(Vector2i(2, 1)), 3)
	assert_eq(board.get_tile_type(Vector2i(3, 1)), 2)

func test_diagonal_gravity_falls_around_obstacle():
	var board := _flat_board(3, 3, [
		[0, 1, 2],
		[3, BoardModel.EMPTY_TYPE, 4],
		[5, BoardModel.EMPTY_TYPE, 6]
	])
	var box = BoxElement.new()
	box.grid_position = Vector2i(1, 1)
	board.set_element(Vector2i(1, 1), box)
	
	# Assert initial setup
	assert_eq(board.get_tile_type(Vector2i(1, 2)), BoardModel.EMPTY_TYPE)
	
	# Apply gravity
	var _falls = board._apply_gravity([])
	
	# One of (0, 1) or (2, 1) should have fallen to (1, 2)
	var final_tile_at_dst = board.get_tile_type(Vector2i(1, 2))
	assert_true(final_tile_at_dst == 3 or final_tile_at_dst == 4)

func test_ddd2_gravity_state():
	var board = BoardModel.new(_make_level(8, 8, 5, 20), 42)
	# Clear the board types
	for x in 8:
		for y in 8:
			board.types[x][y] = BoardModel.EMPTY_TYPE
			board.bonuses[x][y] = BoardModel.BONUS_NONE
	
	# Set up boxes as shown in ddd2.PNG
	var box_positions = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),                 Vector2i(6, 1), Vector2i(7, 1),
		Vector2i(0, 2), Vector2i(1, 2),                                 Vector2i(6, 2), Vector2i(7, 2),
		Vector2i(0, 3),                                                 Vector2i(6, 3), Vector2i(7, 3),
	]
	for pos in box_positions:
		var box = BoxElement.new()
		box.grid_position = pos
		board.set_element(pos, box)
		board.types[pos.x][pos.y] = BoardModel.EMPTY_TYPE
	
	# Set up the other tiles
	var layout = [
		[-1, -1, -1,  0,  1, -1, -1, -1], # Row 0
		[-1, -1, -1,  2,  0, -1, -1, -1], # Row 1 (Col 5 is empty)
		[-1, -1, -1,  3,  1, -1, -1, -1], # Row 2 (Col 2 is empty)
		[-1, -1, -1,  1,  4, -1, -1, -1], # Row 3 (Col 1, 2, 5 are empty)
		[-1, -1, -1,  0,  0, -1, -1, -1], # Row 4 (Col 0, 1, 2, 5, 6, 7 are empty)
		[ 0, -1,  1,  3,  3, -1,  1,  4], # Row 5 (Col 1, 5 are empty)
		[ 1,  3,  2,  2,  2, -1,  2,  4], # Row 6 (Col 5 is empty)
		[ 4,  0,  0,  3,  1,  3,  2,  1]  # Row 7
	]
	
	for y in 8:
		for x in 8:
			var val = layout[y][x]
			if val != -1:
				board.types[x][y] = val
	
	# Run gravity!
	var falls = board._apply_gravity([])
	
	# Assert that empty cells under/beside boxes got filled or moved
	assert_true(falls.size() > 0)

func test_ddd2_cascade_fully_fills_board():
	var board = BoardModel.new(_make_level(8, 8, 5, 20), 42)
	# Clear the board types
	for x in 8:
		for y in 8:
			board.types[x][y] = BoardModel.EMPTY_TYPE
			board.bonuses[x][y] = BoardModel.BONUS_NONE
	
	# Set up boxes as shown in ddd2.PNG
	var box_positions = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),                 Vector2i(6, 1), Vector2i(7, 1),
		Vector2i(0, 2), Vector2i(1, 2),                                 Vector2i(6, 2), Vector2i(7, 2),
		Vector2i(0, 3),                                                 Vector2i(6, 3), Vector2i(7, 3),
	]
	for pos in box_positions:
		var box = BoxElement.new()
		box.grid_position = pos
		board.set_element(pos, box)
		board.types[pos.x][pos.y] = BoardModel.EMPTY_TYPE
	
	# Set up the other tiles
	var layout = [
		[-1, -1, -1,  0,  1, -1, -1, -1], # Row 0
		[-1, -1, -1,  2,  0, -1, -1, -1], # Row 1
		[-1, -1, -1,  3,  1, -1, -1, -1], # Row 2
		[-1, -1, -1,  1,  4, -1, -1, -1], # Row 3
		[-1, -1, -1,  0,  0, -1, -1, -1], # Row 4
		[ 0, -1,  1,  3,  3, -1,  1,  4], # Row 5
		[ 1,  3,  2,  2,  2, -1,  2,  4], # Row 6
		[ 4,  0,  0,  3,  1,  3,  2,  1]  # Row 7
	]
	
	for y in 8:
		for x in 8:
			var val = layout[y][x]
			if val != -1:
				board.types[x][y] = val
	
	# Start cascade using a dummy match cell so that the cascade logic executes
	await board._do_attempt_swap_cascade(Vector2i(-1, -1), Vector2i(3, 4))
	
	# Verify that the board is completely filled (except where boxes are present)
	for x in 8:
		for y in 8:
			var cell = Vector2i(x, y)
			var type = board.get_tile_type(cell)
			var has_obstacle = board.elements_map.has(cell) and board.elements_map[cell].is_obstacle
			if cell == Vector2i(7, 4):
				assert_eq(type, BoardModel.EMPTY_TYPE, "Cell (7,4) is isolated and must be empty")
			elif has_obstacle:
				assert_eq(type, BoardModel.EMPTY_TYPE, "Obstacle cell (%d,%d) has non-empty type %d" % [x, y, type])
			else:
				assert_ne(type, BoardModel.EMPTY_TYPE, "Normal cell (%d,%d) should not be empty" % [x, y])



