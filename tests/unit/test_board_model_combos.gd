extends GutTest

func _make_level(w: int, h: int, types: int) -> LevelData:
	var level := LevelData.new()
	level.grid_width = w
	level.grid_height = h
	level.tile_type_count = types
	level.move_limit = 20
	level.objective = 10000
	return level

func _flat_board(w: int, h: int, rows: Array) -> BoardModel:
	var board := BoardModel.new(_make_level(w, h, 6), 1)
	for x in w:
		for y in h:
			board.types[x][y] = rows[y][x]
			board.bonuses[x][y] = BoardModel.BONUS_NONE
	return board

func test_rocket_rocket_combo():
	var board := _flat_board(4, 4, [
		[0, 1, 2, 3],
		[1, 2, 3, 0],
		[2, 3, 0, 1],
		[3, 0, 1, 2],
	])
	board.bonuses[1][1] = BoardModel.BONUS_ROCKET_H
	board.bonuses[2][1] = BoardModel.BONUS_ROCKET_V
	var ok := board.attempt_swap(Vector2i(1, 1), Vector2i(2, 1))
	assert_true(ok)
	# Moves consumed
	assert_eq(board.moves_remaining, 19)

func test_rocket_bomb_combo():
	var board := _flat_board(5, 5, [
		[0, 1, 2, 3, 4],
		[1, 2, 3, 4, 0],
		[2, 3, 0, 1, 2],
		[3, 4, 1, 2, 3],
		[4, 0, 2, 3, 4],
	])
	board.bonuses[2][2] = BoardModel.BONUS_ROCKET_H
	board.bonuses[3][2] = BoardModel.BONUS_BOMB
	var ok := board.attempt_swap(Vector2i(2, 2), Vector2i(3, 2))
	assert_true(ok)

func test_bomb_bomb_combo():
	var board := _flat_board(6, 6, [
		[0, 1, 2, 3, 4, 5],
		[1, 2, 3, 4, 5, 0],
		[2, 3, 0, 1, 2, 3],
		[3, 4, 1, 2, 3, 4],
		[4, 5, 2, 3, 4, 5],
		[5, 0, 3, 4, 5, 0],
	])
	board.bonuses[2][2] = BoardModel.BONUS_BOMB
	board.bonuses[3][2] = BoardModel.BONUS_BOMB
	var ok := board.attempt_swap(Vector2i(2, 2), Vector2i(3, 2))
	assert_true(ok)

func test_electro_ball_electro_ball_combo():
	var board := _flat_board(4, 4, [
		[0, 1, 2, 3],
		[1, 2, 3, 0],
		[2, 3, 0, 1],
		[3, 0, 1, 2],
	])
	board.bonuses[1][1] = BoardModel.BONUS_ELECTRO_BALL
	board.bonuses[2][1] = BoardModel.BONUS_ELECTRO_BALL
	var ok := board.attempt_swap(Vector2i(1, 1), Vector2i(2, 1))
	assert_true(ok)

func test_electro_ball_color_swap():
	var board := _flat_board(4, 4, [
		[0, 0, 2, 3],
		[1, 0, 3, 0],
		[2, 3, 0, 1],
		[3, 0, 1, 2],
	])
	board.bonuses[1][1] = BoardModel.BONUS_ELECTRO_BALL
	# Swap Electro Ball at (1,1) with color 0 at (2,1)
	var ok := board.attempt_swap(Vector2i(1, 1), Vector2i(2, 1))
	assert_true(ok)

func test_single_special_tap_activation():
	var board := _flat_board(4, 4, [
		[0, 1, 2, 3],
		[1, 2, 3, 0],
		[2, 3, 0, 1],
		[3, 0, 1, 2],
	])
	board.bonuses[1][1] = BoardModel.BONUS_BOMB
	var activated := board.activate_special_tile(Vector2i(1, 1))
	assert_true(activated)
	assert_eq(board.moves_remaining, 19)
