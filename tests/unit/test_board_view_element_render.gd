# tests/unit/test_board_view_element_render.gd
extends GutTest

func test_board_view_renders_elements():
	var level = LevelData.new()
	level.grid_width = 4
	level.grid_height = 4
	
	var board_model = BoardModel.new(level, 42)
	var box = BoxElement.new()
	box.grid_position = Vector2i(1, 1)
	board_model.set_element(Vector2i(1, 1), box)
	
	var view = BoardView.new()
	view.setup(board_model, level)
	
	assert_true(view.has_element_node_at(Vector2i(1, 1)))
	
	view.free()
