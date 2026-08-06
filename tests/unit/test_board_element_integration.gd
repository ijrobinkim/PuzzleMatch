# tests/unit/test_board_element_integration.gd
extends GutTest

func test_adjacent_match_damages_element():
	var level = LevelData.new()
	level.grid_width = 5
	level.grid_height = 5
	level.move_limit = 20
	level.objective = 100
	
	var board = BoardModel.new(level, 42)
	var box = BoxElement.new()
	box.grid_position = Vector2i(2, 2)
	board.set_element(Vector2i(2, 2), box)
	
	assert_not_null(board.get_element(Vector2i(2, 2)))
	
	# Damage element adjacent to (2, 1)
	board.damage_adjacent_elements([Vector2i(2, 1)])
	assert_null(board.get_element(Vector2i(2, 2))) # Box health was 1, destroyed
