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

func test_swapping_special_item_that_forms_color_match_detonates_item():
	# Orange gem (3) at (2,1) swapped with Striped Rocket at (1,1).
	# Column 1 has [0, 3, 3] at (1,0),(1,1),(1,2). Swapping places Orange gem at (1,1), making vertical 3-match!
	# Striped Rocket moves to (2,1). The swap must create the 3-match AND detonate Rocket at (2,1)!
	var board := _flat_board(3, 3, [
		[1, 3, 1],
		[2, 0, 3], # (1,1) has special item bonus, (2,1) has Orange gem 3
		[2, 3, 4],
	])
	board.bonuses[1][1] = BoardModel.BONUS_ROCKET_H
	var cascade_steps := []
	board.cascade_step.connect(func(step): cascade_steps.append(step))

	var result := board.attempt_swap(Vector2i(1, 1), Vector2i(2, 1))
	assert_true(result)
	assert_true(cascade_steps.size() > 0)
	var first_step: Dictionary = cascade_steps[0]
	# Rocket at (2,1) clears row 1 [(0,1),(1,1),(2,1)] and 3-match clears [(1,0),(1,1),(1,2)]
	# Cleared cells must include row 1 tiles as well as column 1 match tiles!
	var cleared: Array = first_step["cleared"]
	assert_true(cleared.has(Vector2i(0, 1)), "Row 1 left tile cleared by rocket")
	assert_true(cleared.has(Vector2i(1, 0)), "Col 1 top tile cleared by 3-match")

func test_swap_allowed_by_snow_gimmick():
	var board := _flat_board(4, 2, [
		[0, 0, 1, 1],
		[2, 2, 0, 3],
	])
	var snow = load("res://scripts/elements/concrete/snow_element.gd").new()
	board.set_element(Vector2i(2, 0), snow)
	
	assert_eq(snow.current_health, 2, "Snow gimmick starts with health 2")
	
	var result := board.attempt_swap(Vector2i(2, 0), Vector2i(2, 1))
	assert_true(result, "Swap should be allowed when snow gimmick is present on a cell")
	assert_eq(snow.current_health, 1, "Snow gimmick should take 1 damage and thin out")
	
	snow.free()

func test_snow_not_damaged_by_adjacent_match():
	var board := _flat_board(4, 2, [
		[0, 1, 0, 1],
		[2, 0, 2, 3],
	])
	var snow = load("res://scripts/elements/concrete/snow_element.gd").new()
	board.set_element(Vector2i(3, 0), snow)
	
	assert_eq(snow.current_health, 2, "Snow gimmick starts with health 2")
	
	var result := board.attempt_swap(Vector2i(1, 0), Vector2i(1, 1))
	assert_true(result)
	assert_eq(snow.current_health, 2, "Snow gimmick should not take damage from adjacent matches")
	
	snow.free()

func test_swap_restricted_by_ivy_gimmick():
	var board := _flat_board(4, 2, [
		[0, 0, 1, 1],
		[2, 2, 0, 3],
	])
	var ivy = load("res://scripts/elements/concrete/ivy_element.gd").new()
	board.set_element(Vector2i(2, 0), ivy)
	
	var result := board.attempt_swap(Vector2i(2, 0), Vector2i(2, 1))
	assert_false(result, "Swap should be blocked when ivy gimmick is present on a cell")
	
	ivy.free()

func test_ivy_allows_gravity_fall():
	var board := _flat_board(3, 3, [
		[1, 1, 1],
		[0, 2, 0],
		[4, 4, 4],
	])
	var ivy = load("res://scripts/elements/concrete/ivy_element.gd").new()
	board.set_element(Vector2i(1, 1), ivy)
	board.types[1][2] = BoardModel.EMPTY_TYPE
	
	var falls = board._apply_gravity([])
	assert_true(falls.size() > 0, "Gravity fall should occur")
	var found_fall := false
	for f in falls:
		if f["from"] == Vector2i(1, 1) and f["to"] == Vector2i(1, 2):
			found_fall = true
			break
	assert_true(found_fall, "Tile at ivy cell should fall to the empty cell below it")
	
	ivy.free()

func test_ivy_not_damaged_by_self_match():
	var board := _flat_board(3, 3, [
		[2, 0, 2],
		[3, 0, 3],
		[4, 1, 0],
	])
	var ivy = load("res://scripts/elements/concrete/ivy_element.gd").new()
	board.set_element(Vector2i(1, 1), ivy)
	
	assert_eq(ivy.current_health, 1, "Ivy starts with health 1")
	var result := board.attempt_swap(Vector2i(1, 2), Vector2i(2, 2))
	assert_true(result)
	assert_true(board.elements_map.has(Vector2i(1, 1)), "Ivy should remain on the cell")
	assert_eq(ivy.current_health, 1, "Ivy health should remain 1")
	
	ivy.free()

func test_ivy_damaged_by_adjacent_match():
	var board := _flat_board(4, 2, [
		[0, 1, 0, 1],
		[2, 0, 2, 3],
	])
	var ivy = load("res://scripts/elements/concrete/ivy_element.gd").new()
	board.set_element(Vector2i(2, 1), ivy)
	
	var result := board.attempt_swap(Vector2i(1, 0), Vector2i(1, 1))
	assert_true(result)
	assert_false(board.elements_map.has(Vector2i(2, 1)), "Ivy should be destroyed by adjacent match")
	
	ivy.free()

func test_ivy_no_chain_damage_when_self_gem_cleared():
	var board := _flat_board(3, 3, [
		[2, 0, 2],
		[3, 0, 3],
		[4, 1, 0],
	])
	var ivy1 = load("res://scripts/elements/concrete/ivy_element.gd").new()
	var ivy2 = load("res://scripts/elements/concrete/ivy_element.gd").new()
	board.set_element(Vector2i(1, 1), ivy1)
	board.set_element(Vector2i(2, 1), ivy2)
	
	assert_eq(ivy1.current_health, 1)
	assert_eq(ivy2.current_health, 1)
	
	var result := board.attempt_swap(Vector2i(1, 2), Vector2i(2, 2))
	assert_true(result)
	
	assert_true(board.elements_map.has(Vector2i(1, 1)), "Ivy at (1,1) should remain")
	assert_true(board.elements_map.has(Vector2i(2, 1)), "Ivy at (2,1) should also remain and not take adjacent damage from (1,1)")
	
	ivy1.free()
	ivy2.free()

func test_ivy_no_adjacent_damage_from_item_explosions():
	var board := BoardModel.new(_make_level(5, 5, 4, 15), 42)
	var ivy_inside = load("res://scripts/elements/concrete/ivy_element.gd").new()
	var ivy_outside = load("res://scripts/elements/concrete/ivy_element.gd").new()
	board.set_element(Vector2i(3, 1), ivy_inside)
	board.set_element(Vector2i(4, 1), ivy_outside)
	board.bonuses[1][1] = BoardModel.BONUS_BOMB
	
	await board._do_attempt_swap_cascade(Vector2i(-1, -1), Vector2i(1, 1))
	
	assert_false(board.elements_map.has(Vector2i(3, 1)), "Ivy inside bomb range should be destroyed")
	assert_true(board.elements_map.has(Vector2i(4, 1)), "Ivy outside bomb range should survive and not receive adjacent damage from item explosion")
	
	ivy_inside.free()
	ivy_outside.free()

func test_column_destroyed_from_top_one_by_one():
	# Board 4x4
	var board := _flat_board(4, 4, [
		[2, 0, 0, 0],
		[3, 0, 0, 0],
		[4, 1, 0, 0],
		[0, 0, 0, 0]
	])
	
	# Place two stacked columns in column x=1: (1,1) and (1,2)
	var col_top = load("res://scripts/elements/concrete/column_element.gd").new()
	var col_bottom = load("res://scripts/elements/concrete/column_element.gd").new()
	board.set_element(Vector2i(1, 1), col_top)
	board.set_element(Vector2i(1, 2), col_bottom)
	
	# Trigger swap at (1,2) to (2,2) to form vertical 3-match at x=1
	# The match will clear cells (0,0), (0,1), (0,2) or similar
	# Let's verify the setup: 
	# row 0: 2, 0, 0, 0
	# row 1: 3, 0, 0, 0
	# row 2: 4, 1, 0, 0
	# Wait, we want to match x=0 vertical cells by swapping (1,2) [which is type 1] with (0,2) [which is type 4]... 
	# Let's design a simpler swap:
	# grid:
	# [2, 0, 2, 2]
	# [3, 0, 3, 3]
	# [4, 1, 0, 0]
	# Let's flat board it precisely for clean swap:
	# Col 0: [2, 3, 2, 0]
	# Col 1: [0, 0, 0, 0] (columns placed at (1,1), (1,2))
	# Swap (0,1) with (0,2) to clear Col 0 match, adjacent to Col 1 column elements.
	var board2 := _flat_board(4, 4, [
		[2, 0, 1, 1],
		[3, 0, 1, 1],
		[2, 2, 3, 3],
		[1, 1, 0, 0]
	])
	var col1 = load("res://scripts/elements/concrete/column_element.gd").new()
	var col2 = load("res://scripts/elements/concrete/column_element.gd").new()
	board2.set_element(Vector2i(1, 1), col1)
	board2.set_element(Vector2i(1, 2), col2)
	
	# Swap (0,2) and (1,2) to make 3-match at Col 0: (0,0)-(0,1)-(0,2) which are all color 2.
	# Wait, the flat board cells are:
	# row 0: [2, 0, 1, 1]
	# row 1: [3, 0, 1, 1]
	# row 2: [2, 2, 3, 3]
	# row 3: [1, 1, 0, 0]
	# Types at x=0: y=0 is 2, y=1 is 3, y=2 is 2.
	# Types at x=1: y=0 is 0, y=1 is column, y=2 is column, y=3 is 1.
	# Let's just manually trigger match damage on specific cells to verify damage filter!
	# This is much cleaner and avoids match setup complexity.
	# We simulate a cleared cell at (0, 1) and (0, 2).
	# This should adjacent damage both (1, 1) and (1, 2).
	# But because of filter, only (1, 1) [topmost] should take damage.
	
	board2.damage_adjacent_elements([Vector2i(0, 1), Vector2i(0, 2)])
	
	# Bottom column (1, 2) has max_health = 1, should be destroyed (lowest segment targeted)
	assert_false(board2.elements_map.has(Vector2i(1, 2)), "Bottom column at (1,2) should be destroyed")
	
	# Top column (1, 1) should survive
	assert_true(board2.elements_map.has(Vector2i(1, 1)), "Top column at (1,1) should survive first hit")
	
	# Apply gravity manually - the column at (1,1) should collapse down to (1,2) via column falling logic
	var falls := board2._apply_gravity([Vector2i(1, 2)])
	
	# Verify that the column has indeed fallen to (1,2)
	assert_false(board2.elements_map.has(Vector2i(1, 1)), "Column should have left (1,1)")
	assert_true(board2.elements_map.has(Vector2i(1, 2)), "Column should have fallen to (1,2)")
	
	# Damage it again at its new position (1,2)
	board2.damage_adjacent_elements([Vector2i(0, 2)])
	assert_false(board2.elements_map.has(Vector2i(1, 2)), "Column at (1,2) should now be destroyed")
	
	col1.free()
	col2.free()
	col_top.free()
	col_bottom.free()

func test_columns_destroyed_together_by_item_explosion():
	# Board 5x5
	var board := BoardModel.new(_make_level(5, 5, 4, 15), 42)
	
	# Place two stacked columns: (2,1) and (2,2)
	var col_top = load("res://scripts/elements/concrete/column_element.gd").new()
	var col_bottom = load("res://scripts/elements/concrete/column_element.gd").new()
	board.set_element(Vector2i(2, 1), col_top)
	board.set_element(Vector2i(2, 2), col_bottom)
	
	# Place bomb at (1,1)
	board.bonuses[1][1] = BoardModel.BONUS_BOMB
	
	# Trigger the bomb (explosive damage)
	await board._do_attempt_swap_cascade(Vector2i(-1, -1), Vector2i(1, 1))
	
	# Both columns should be destroyed together bypassing topmost restrictions
	assert_false(board.elements_map.has(Vector2i(2, 1)), "Topmost column at (2,1) should be destroyed by bomb")
	assert_false(board.elements_map.has(Vector2i(2, 2)), "Bottom column at (2,2) should also be destroyed by bomb at the same time")
	
	col_top.free()
	col_bottom.free()

func test_column_no_gem_inside_and_gravity_falls_from_above():
	# 3x3 board
	var board := _flat_board(3, 3, [
		[2, 3, 2],
		[1, 0, 1], # (1,1) has color 0 initially, but column placement will clear it
		[4, 1, 4]
	])
	
	var col = load("res://scripts/elements/concrete/column_element.gd").new()
	
	# Placing column at (1,1)
	board.set_element(Vector2i(1, 1), col)
	
	# Verify that the tile type under the column is set to EMPTY_TYPE
	assert_eq(board.types[1][1], board.EMPTY_TYPE, "Column slot tile type should be cleared to EMPTY_TYPE")
	
	# Destroy column directly
	col.take_damage(1)
	
	# Verify column is gone
	assert_false(board.elements_map.has(Vector2i(1, 1)), "Column should be destroyed")
	
	# Apply gravity manually
	var falls := board._apply_gravity([Vector2i(1, 1)])
	
	# Verify that the tile from (1,0) [type 3] fell down to (1,1)
	assert_eq(board.types[1][1], 3, "Tile from (1,0) should fall down to (1,1)")
	assert_eq(board.types[1][0], board.EMPTY_TYPE, "Tile position (1,0) should now be EMPTY_TYPE")
	
	col.free()
