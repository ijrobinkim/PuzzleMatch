extends SceneTree

const BoardModel = preload("res://scripts/board/board_model.gd")
const BoardView = preload("res://scripts/board/board_view.gd")

func _init():
	var model = BoardModel.new(null, 1234)
	model.width = 8
	model.height = 8
	
	# Set up column at (2,0), (2,1), (2,2), (2,3)
	var factory = preload("res://scripts/managers/element_factory.gd").new()
	for y in range(4):
		model.types[2][y] = model.EMPTY_TYPE
		var col = factory.create_element("column")
		col.grid_position = Vector2i(2, y)
		model.elements_map[Vector2i(2, y)] = col
	
	# Destroy (2,3) to trigger fall
	model.elements_map.erase(Vector2i(2,3))
	
	# View setup
	var view = BoardView.new()
	view.model = model
	
	# We need to add it to a tree so tweens can process
	var root_node = Node2D.new()
	root_node.add_child(view)
	
	view._render_initial_board()

	
	# Manual gravity
	var falls = model._apply_gravity([])
	var step = {
		"falls": falls,
		"refills": model._refill_empty_cells(),
		"cleared": [], "matches": [], "bonuses": [], "spinners": [], "rockets": []
	}
	
	view._on_cascade_step(step)
	
	var tile = view._cell_to_tile[Vector2i(2,0)]
	print("RESULT Tile at (2,0): type=", tile.tile_type, " visible=", tile.visible, " pos=", tile.position, " scale=", tile.scale, " modulate=", tile.modulate, " a_tween=", tile._active_tween != null)
	if tile.sprite:
		print("RESULT Sprite frame=", tile.sprite.frame, " visible=", tile.sprite.visible)
		
	quit()
