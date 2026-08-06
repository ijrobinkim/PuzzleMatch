# tests/unit/test_game_board_screen_test.gd
extends GutTest

func test_game_board_screen_test_instantiation_and_box_setup():
	var scene: PackedScene = load("res://scenes/screens/game_board_screen_test.tscn")
	assert_not_null(scene, "game_board_screen_test.tscn scene should exist")
	var screen = scene.instantiate()
	assert_not_null(screen, "screen instance should be created")
	add_child(screen)
	
	# Verify board view & model
	assert_not_null(screen._board_view, "board_view node should exist")
	assert_not_null(screen._board_view.model, "board model should be initialized")
	
	# Verify top half (y=0..3) filled with boxes (32 boxes total)
	var box_count := 0
	for x in 8:
		for y in 4:
			var cell := Vector2i(x, y)
			var elem = screen._board_view.model.get_element(cell)
			if elem != null and elem.element_id == "box":
				box_count += 1
	assert_eq(box_count, 32, "Top 4 rows (32 cells) should be pre-filled with box elements")
	
	# Verify target objectives
	assert_eq(screen._board_view.model.target_objectives.get("box", 0), 32, "Box objective target should be 32")
	
	screen.free()
