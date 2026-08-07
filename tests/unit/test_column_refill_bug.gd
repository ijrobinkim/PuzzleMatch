extends GutTest

const BoardModel = preload("res://scripts/board/board_model.gd")
const BoardView = preload("res://scripts/board/board_view.gd")

func test_column_fall_refill_visibility():
	var model = BoardModel.new()
	model.width = 8
	model.height = 8
	model._rng.seed = 1234
	
	# Set up column at (2,0), (2,1), (2,2), (2,3)
	for y in range(4):
		model.types[2][y] = model.EMPTY_TYPE
		var factory = preload("res://scripts/managers/element_factory.gd").new()
		var col = factory.create_element("column")
		col.grid_position = Vector2i(2, y)
		model.elements_map[Vector2i(2, y)] = col
	
	# Destroy (2,3) to trigger fall
	model.elements_map.erase(Vector2i(2,3))
	
	# View setup
	var view = BoardView.new()
	view.model = model
	add_child(view)
	view._render_initial_board()
	
	# Let's manually trigger gravity and check the view's tile
	var falls = model._apply_gravity()
	var step = {
		"falls": falls,
		"refills": model._refill_empty_cells()
	}
	
	# We expect refill at (2,0)
	assert_eq(step["refills"][0]["pos"], Vector2i(2,0))
	
	# Run view cascade
	view._on_cascade_step(step)
	
	var tile = view._cell_to_tile[Vector2i(2,0)]
	print("Tile at (2,0): type=", tile.tile_type, " visible=", tile.visible, " pos=", tile.position, " scale=", tile.scale, " modulate=", tile.modulate, " a_tween=", tile._active_tween != null)
	if tile.sprite:
		print("Sprite frame=", tile.sprite.frame, " visible=", tile.sprite.visible)
