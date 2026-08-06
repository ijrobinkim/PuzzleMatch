# tests/unit/test_board_funconomy_objectives.gd
extends GutTest

func test_target_objectives_completion():
	var level = LevelData.new()
	level.grid_width = 4
	level.grid_height = 4
	level.move_limit = 10
	level.target_objectives = {"box": 1}
	
	var board = BoardModel.new(level, 42)
	var box = BoxElement.new()
	box.element_id = "box"
	box.grid_position = Vector2i(1, 1)
	board.set_element(Vector2i(1, 1), box)
	
	assert_false(board.is_objective_completed())
	
	# Damage element adjacent to (1, 0)
	board.damage_adjacent_elements([Vector2i(1, 0)])
	
	assert_true(board.is_objective_completed())
