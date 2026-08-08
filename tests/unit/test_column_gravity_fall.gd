extends GutTest

func _make_level(w: int, h: int) -> LevelData:
	var level := LevelData.new()
	level.grid_width = w
	level.grid_height = h
	level.tile_type_count = 6
	level.move_limit = 20
	level.objective = 1000000
	return level

func test_single_column_falls_into_empty_cell_below():
	var board := BoardModel.new(_make_level(3, 4), 1)
	for x in 3:
		for y in 4:
			board.types[x][y] = 0
			board.bonuses[x][y] = BoardModel.BONUS_NONE

	var col = load("res://scripts/elements/concrete/column_element.gd").new()
	board.set_element(Vector2i(1, 1), col)
	board._apply_gravity([Vector2i(1, 2)])
	assert_false(board.elements_map.has(Vector2i(1, 1)), "column should have left (1,1)")
	assert_true(board.elements_map.has(Vector2i(1, 2)), "column should now be at (1,2)")

func test_view_animates_column_fall_after_destroy():
	var level := _make_level(3, 4)
	var board := BoardModel.new(level, 1)
	for x in 3:
		for y in 4:
			board.types[x][y] = 0
			board.bonuses[x][y] = BoardModel.BONUS_NONE

	var col_top = load("res://scripts/elements/concrete/column_element.gd").new()
	var col_bottom = load("res://scripts/elements/concrete/column_element.gd").new()
	board.set_element(Vector2i(1, 1), col_top)
	board.set_element(Vector2i(1, 2), col_bottom)

	var view_scene: PackedScene = load("res://scenes/board/board_view.tscn")
	var view: BoardView = view_scene.instantiate()
	add_child(view)
	view.setup(board, level)
	await wait_frames(2)

	assert_true(view._element_nodes.has(Vector2i(1, 1)), "view should have col_top node at (1,1) initially")
	assert_true(view._element_nodes.has(Vector2i(1, 2)), "view should have col_bottom node at (1,2) initially")

	# Simulate col_bottom being destroyed (as a special-item explosion would).
	board.elements_map.erase(Vector2i(1, 2))
	board.types[1][2] = BoardModel.EMPTY_TYPE
	var falls = board._apply_gravity([])
	assert_false(board.elements_map.has(Vector2i(1, 1)), "model: top column should have left (1,1)")
	assert_true(board.elements_map.has(Vector2i(1, 2)), "model: top column should now be at (1,2)")

	view._on_cascade_step({
		"matches": [],
		"cleared": [],
		"bonuses": [],
		"falls": falls,
		"refills": [],
		"spinners": [],
		"rockets": [],
		"destroyed_elements": [col_bottom],
		"damaged_elements": [],
	})

	await wait_seconds(1.5)

	assert_false(view._element_nodes.has(Vector2i(1, 1)), "view: node should have left (1,1)")
	assert_true(view._element_nodes.has(Vector2i(1, 2)), "view: node should now be registered at (1,2)")
	if view._element_nodes.has(Vector2i(1, 2)):
		var expected_pos: Vector2 = Vector2(1.5, 2.5) * BoardView.CELL_SIZE
		assert_true(view._element_nodes[Vector2i(1, 2)].position.distance_to(expected_pos) < 5.0,
			"node visual position should match (1,2)")

func test_column_not_damaged_by_adjacent_normal_match():
	var board := BoardModel.new(_make_level(3, 2), 1)
	for x in 3:
		for y in 2:
			board.types[x][y] = 0
			board.bonuses[x][y] = BoardModel.BONUS_NONE

	var col = load("res://scripts/elements/concrete/column_element.gd").new()
	board.set_element(Vector2i(1, 0), col)

	# Adjacent normal-match damage from (0,0) must NOT affect the column —
	# Royal Kingdom design: only a direct special-item hit destroys it.
	board.damage_adjacent_elements([Vector2i(0, 0)], [Vector2i(0, 0)])
	assert_true(board.elements_map.has(Vector2i(1, 0)), "column must survive adjacent normal-match damage")

func test_column_destroyed_by_direct_special_item_hit():
	var board := BoardModel.new(_make_level(3, 2), 1)
	for x in 3:
		for y in 2:
			board.types[x][y] = 0
			board.bonuses[x][y] = BoardModel.BONUS_NONE

	var col = load("res://scripts/elements/concrete/column_element.gd").new()
	board.set_element(Vector2i(1, 0), col)

	# A blast cell that directly covers the column's own cell (e.g. a bomb
	# radius) is not a "normal match" cell, so self-damage still applies.
	board.damage_adjacent_elements([Vector2i(1, 0)], [])
	assert_false(board.elements_map.has(Vector2i(1, 0)), "column must be destroyed by a direct special-item hit")
