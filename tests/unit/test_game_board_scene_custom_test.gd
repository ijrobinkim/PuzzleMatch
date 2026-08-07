# tests/unit/test_game_board_scene_custom_test.gd
extends GutTest

func test_game_board_scene_custom_test_gimmick_selection_and_deploy():
	var scene: PackedScene = load("res://scenes/screens/game_board_scene_custom_test.tscn")
	assert_not_null(scene, "game_board_scene_custom_test.tscn scene should exist")
	var screen = scene.instantiate()
	assert_not_null(screen, "screen instance should be created")
	add_child(screen)

	# Verify UI Nodes
	assert_not_null(screen._box_check, "box_check node should exist")
	assert_not_null(screen._snow_check, "snow_check node should exist")
	assert_not_null(screen._board_view, "board_view node should exist")
	assert_not_null(screen._board_view.model, "board model should be initialized")

	# Mock selecting Box and Snow gimmicks
	screen._box_check.button_pressed = true
	screen._snow_check.button_pressed = true

	# Call deploy handler
	screen._on_deploy_pressed()

	# Verify objectives and placement
	var model = screen._board_view.model
	assert_not_null(model, "board model should be recreated on deploy")
	
	# Verify target objectives
	assert_eq(model.target_objectives_remaining.get("box", 0), 4, "Box objective should be 4")
	assert_eq(model.target_objectives_remaining.get("snow", 0), 4, "Snow objective should be 4")

	# Count elements
	var box_count := 0
	var snow_count := 0
	for cell in model.elements_map.keys():
		var elem = model.get_element(cell)
		if elem != null:
			if elem.element_id == "box":
				box_count += 1
			elif elem.element_id == "snow":
				snow_count += 1

	assert_eq(box_count, 4, "Should have exactly 4 box elements on board")
	assert_eq(snow_count, 4, "Should have exactly 4 snow elements on board")

	# Verify Damage All functionality
	var total_hp_before := 0
	for cell in model.elements_map.keys():
		var elem = model.get_element(cell)
		if elem != null:
			total_hp_before += elem.current_health

	# Trigger damage all
	screen._on_damage_all_pressed()

	var total_hp_after := 0
	for cell in model.elements_map.keys():
		var elem = model.get_element(cell)
		if elem != null:
			total_hp_after += elem.current_health

	assert_eq(total_hp_after, total_hp_before - 8, "All 8 active gimmicks should take 1 damage each")

	screen.free()
