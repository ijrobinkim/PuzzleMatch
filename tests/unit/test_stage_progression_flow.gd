extends "res://addons/gut/test.gd"

func test_stage_progression_logic() -> void:
	var screen_scene: PackedScene = load("res://scenes/screens/game_board_screen.tscn")
	assert_not_null(screen_scene)

	var screen: Node2D = screen_scene.instantiate()
	add_child(screen)

	assert_eq(screen.current_stage_idx, 1, "Game should start at Stage 1")

	# Test next stage transition logic
	screen._on_next_level_requested()
	assert_eq(screen.current_stage_idx, 2, "Transition should advance to Stage 2")

	screen._on_next_level_requested()
	assert_eq(screen.current_stage_idx, 3, "Transition should advance to Stage 3")

	# Test jumping to final stage
	screen._load_stage(30)
	assert_eq(screen.current_stage_idx, 30, "Should load Stage 30 successfully")

	screen.queue_free()
