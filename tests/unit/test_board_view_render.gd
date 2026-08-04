# tests/unit/test_board_view_render.gd
extends GutTest

func test_start_level_renders_one_tile_per_cell():
	var view: BoardView = preload("res://scenes/board/board_view.tscn").instantiate()
	add_child_autofree(view)
	var level := LevelData.new()
	level.grid_width = 4
	level.grid_height = 4
	level.tile_type_count = 6
	level.move_limit = 20
	level.objective = 1000
	view.start_level(level)
	var visible_tiles := 0
	for child in view.get_children():
		if child is Tile and child.visible:
			visible_tiles += 1
	assert_eq(visible_tiles, 16)

func test_rendered_tile_type_matches_model():
	var view: BoardView = preload("res://scenes/board/board_view.tscn").instantiate()
	add_child_autofree(view)
	var level := LevelData.new()
	level.grid_width = 3
	level.grid_height = 3
	level.tile_type_count = 6
	level.move_limit = 20
	level.objective = 1000
	view.start_level(level)
	for child in view.get_children():
		if child is Tile and child.visible:
			assert_eq(child.tile_type, view.model.get_tile_type(child.cell))
