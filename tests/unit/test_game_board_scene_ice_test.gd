# tests/unit/test_game_board_scene_ice_test.gd
extends GutTest

func test_game_board_scene_ice_test_instantiation_and_snow_setup():
	var scene: PackedScene = load("res://scenes/screens/game_board_scene_ice_test.tscn")
	assert_not_null(scene, "game_board_scene_ice_test.tscn scene should exist")
	var screen = scene.instantiate()
	assert_not_null(screen, "screen instance should be created")
	add_child(screen)
	
	# Verify board view & model
	assert_not_null(screen._board_view, "board_view node should exist")
	assert_not_null(screen._board_view.model, "board model should be initialized")
	
	# Verify top half (y=0..3) filled with snow (24 snow total)
	var snow_count := 0
	var empty_tile_count := 0
	for x in 8:
		for y in 4:
			var cell := Vector2i(x, y)
			var elem = screen._board_view.model.get_element(cell)
			if elem != null and elem.element_id == "snow":
				snow_count += 1
			if screen._board_view.model.get_tile_type(cell) >= 0:
				empty_tile_count += 1
	assert_eq(snow_count, 24, "Top 4 rows (24 cells) should be pre-filled with snow elements")
	assert_eq(empty_tile_count, 32, "Top 4 rows should have normal tile type (>=0) under snow")
	
	# Verify target objectives
	assert_eq(screen._board_view.model.target_objectives_remaining.get("snow", 0), 24, "Snow objective target should be 24")
	
	screen.free()
