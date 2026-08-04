extends GutTest

func _make_level(w: int, h: int, types: int) -> LevelData:
	var level := LevelData.new()
	level.grid_width = w
	level.grid_height = h
	level.tile_type_count = types
	level.move_limit = 20
	level.objective = 1000
	return level

func _flat_board(w: int, h: int, rows: Array) -> BoardModel:
	# rows[y] is an Array of ints, top row first.
	var board := BoardModel.new(_make_level(w, h, 6), 1)
	for x in w:
		for y in h:
			board.types[x][y] = rows[y][x]
			board.bonuses[x][y] = BoardModel.BONUS_NONE
	return board

func test_no_match_on_varied_grid():
	var board := _flat_board(4, 4, [
		[0, 1, 2, 3],
		[1, 2, 3, 0],
		[2, 3, 0, 1],
		[3, 0, 1, 2],
	])
	assert_eq(board.find_matches().size(), 0)

func test_horizontal_three_match_has_no_bonus():
	var board := _flat_board(4, 1, [[0, 0, 0, 1]])
	var matches := board.find_matches()
	assert_eq(matches.size(), 1)
	assert_eq(matches[0]["bonus_kind"], BoardModel.BONUS_NONE)
	assert_eq(matches[0]["cells"].size(), 3)

func test_horizontal_four_match_creates_rocket_h():
	var board := _flat_board(5, 1, [[0, 0, 0, 0, 1]])
	var matches := board.find_matches()
	assert_eq(matches.size(), 1)
	assert_eq(matches[0]["bonus_kind"], BoardModel.BONUS_ROCKET_H)

func test_vertical_four_match_creates_rocket_v():
	var board := _flat_board(1, 5, [[0], [0], [0], [0], [1]])
	var matches := board.find_matches()
	assert_eq(matches.size(), 1)
	assert_eq(matches[0]["bonus_kind"], BoardModel.BONUS_ROCKET_V)

func test_two_by_two_square_creates_spinner():
	var board := _flat_board(3, 3, [
		[0, 0, 1],
		[0, 0, 2],
		[3, 4, 5],
	])
	var matches := board.find_matches()
	assert_eq(matches.size(), 1)
	assert_eq(matches[0]["bonus_kind"], BoardModel.BONUS_SPINNER)

func test_l_shape_match_creates_bomb():
	# Horizontal run of 3 at y=2, vertical run of 3 at x=0, sharing cell (0,2).
	var board := _flat_board(3, 3, [
		[0, 1, 2],
		[0, 3, 4],
		[0, 0, 0],
	])
	var matches := board.find_matches()
	assert_eq(matches.size(), 1)
	assert_eq(matches[0]["bonus_kind"], BoardModel.BONUS_BOMB)
	assert_eq(matches[0]["bonus_pos"], Vector2i(0, 2))

func test_five_in_a_line_creates_electro_ball():
	var board := _flat_board(5, 1, [[0, 0, 0, 0, 0]])
	var matches := board.find_matches()
	assert_eq(matches.size(), 1)
	assert_eq(matches[0]["bonus_kind"], BoardModel.BONUS_ELECTRO_BALL)
