extends "res://addons/gut/test.gd"

func test_action_queue_behavior() -> void:
	var board_view := BoardView.new()
	add_child(board_view)

	var level_data := LevelData.new()
	level_data.grid_width = 8
	level_data.grid_height = 8
	level_data.tile_type_count = 5
	level_data.move_limit = 20

	board_view.start_level(level_data)
	board_view._is_animating = true

	# Case 1: Normal non-destroying tiles perform swap immediately even when board is animating
	var swap_a := Vector2i(1, 1)
	var swap_b := Vector2i(1, 2)
	board_view._perform_user_swap(swap_a, swap_b)

	# Should execute immediately without needing to queue!
	assert_eq(board_view._pending_user_inputs.size(), 0, "Normal tiles swap immediately without queueing")

	# Case 2: Tiles currently being destroyed are enqueued
	var tile_a: Tile = board_view._cell_to_tile[swap_a]
	tile_a.is_destroying = true

	var swap_c := Vector2i(1, 1)
	var swap_d := Vector2i(1, 0)
	board_view._perform_user_swap(swap_c, swap_d)

	assert_eq(board_view._pending_user_inputs.size(), 1, "Destroying tiles enqueue swap for later execution")
	var queued: Dictionary = board_view._pending_user_inputs[0]
	assert_eq(queued.get("type"), "swap")
	assert_eq(queued.get("from"), swap_c)
	assert_eq(queued.get("to"), swap_d)

	board_view.queue_free()
