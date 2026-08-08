extends SceneTree

const BoardModel = preload("res://scripts/board/board_model.gd")
const BoardView = preload("res://scripts/board/board_view.gd")

func _init():
	print("Starting replay...")
	var level_data = Object.new()
	level_data.set_script(GDScript.new())
	var script = level_data.get_script()
	script.source_code = "extends Object\nvar grid_width = 8\nvar grid_height = 8"
	script.reload()
	var model = BoardModel.new(level_data, 1234)
	model.width = 8
	model.height = 8
	
	# Initial grid
	var grid = [
		[3, 2, 3, 4, -1, 1, 2, 2],
		[0, 2, 2, 3, -1, 4, 0, 4],
		[4, 1, 2, 3, -1, 0, 4, 3],
		[3, 4, 3, 4, -1, 4, 1, 0],
		[1, 4, 2, 1, -1, 1, 1, 2],
		[0, 3, 4, 3, -1, 3, 0, 4],
		[4, 3, 1, 4, -1, 2, 3, 4],
		[2, 4, 2, 3, -1, 1, 0, 0]
	]
	for x in range(8):
		for y in range(8):
			model.types[x][y] = grid[y][x]
			
	var view = BoardView.new()
	view.model = model
	var root_node = Node2D.new()
	root_node.add_child(view)
	view._render_initial_board()
	
	# Step 1: (1,5) <-> (2,5)
	var step1 = {"cleared": [Vector2i(1,3), Vector2i(1,4), Vector2i(1,5)], "falls": [{"from": Vector2i(1,2), "to": Vector2i(1,5)}, {"from": Vector2i(1,1), "to": Vector2i(1,4)}, {"from": Vector2i(1,0), "to": Vector2i(1,3)}], "refills": [{"pos": Vector2i(1,2), "type": 2}, {"pos": Vector2i(1,1), "type": 0}, {"pos": Vector2i(1,0), "type": 2}]}
	view._on_cascade_step(step1)
	
	var step2 = {"cleared": [Vector2i(1,2), Vector2i(1,3), Vector2i(1,4)], "falls": [{"from": Vector2i(1,1), "to": Vector2i(1,4)}, {"from": Vector2i(1,0), "to": Vector2i(1,3)}], "refills": [{"pos": Vector2i(1,2), "type": 3}, {"pos": Vector2i(1,1), "type": 4}, {"pos": Vector2i(1,0), "type": 1}]}
	view._on_cascade_step(step2)
	
	var step3 = {"cleared": [Vector2i(3,1), Vector2i(3,2), Vector2i(3,3)], "falls": [{"from": Vector2i(4,2), "to": Vector2i(4,3)}, {"from": Vector2i(4,1), "to": Vector2i(4,2)}, {"from": Vector2i(3,0), "to": Vector2i(3,3)}, {"from": Vector2i(4,0), "to": Vector2i(4,1)}], "refills": [{"pos": Vector2i(3,2), "type": 0}, {"pos": Vector2i(3,1), "type": 0}, {"pos": Vector2i(3,0), "type": 3}, {"pos": Vector2i(4,0), "type": 2}]}
	view._on_cascade_step(step3)
	
	var step4 = {"cleared": [Vector2i(5,1), Vector2i(5,2), Vector2i(5,3)], "falls": [{"from": Vector2i(4,2), "to": Vector2i(4,3)}, {"from": Vector2i(4,1), "to": Vector2i(4,2)}, {"from": Vector2i(4,0), "to": Vector2i(4,1)}, {"from": Vector2i(5,0), "to": Vector2i(5,3)}], "refills": [{"pos": Vector2i(4,0), "type": 3}, {"pos": Vector2i(5,2), "type": 3}, {"pos": Vector2i(5,1), "type": 0}, {"pos": Vector2i(5,0), "type": 1}]}
	view._on_cascade_step(step4)
	
	var step5 = {"cleared": [Vector2i(2,0), Vector2i(3,0), Vector2i(4,0), Vector2i(5,3), Vector2i(6,3), Vector2i(6,4)], "falls": [{"from": Vector2i(4,3), "to": Vector2i(4,4)}, {"from": Vector2i(4,2), "to": Vector2i(4,3)}, {"from": Vector2i(5,2), "to": Vector2i(5,3)}, {"from": Vector2i(6,2), "to": Vector2i(6,4)}, {"from": Vector2i(4,1), "to": Vector2i(4,2)}, {"from": Vector2i(5,1), "to": Vector2i(5,2)}, {"from": Vector2i(6,1), "to": Vector2i(6,3)}, {"from": Vector2i(5,0), "to": Vector2i(5,1)}, {"from": Vector2i(6,0), "to": Vector2i(6,2)}], "refills": [{"pos": Vector2i(2,0), "type": 1}, {"pos": Vector2i(3,0), "type": 3}, {"pos": Vector2i(4,1), "type": 3}, {"pos": Vector2i(4,0), "type": 1}, {"pos": Vector2i(5,0), "type": 1}, {"pos": Vector2i(6,1), "type": 4}, {"pos": Vector2i(6,0), "type": 0}]}
	view._on_cascade_step(step5)
	
	var step6 = {"cleared": [Vector2i(6,3), Vector2i(6,4), Vector2i(6,5)], "falls": [{"from": Vector2i(6,2), "to": Vector2i(6,5)}, {"from": Vector2i(6,1), "to": Vector2i(6,4)}, {"from": Vector2i(6,0), "to": Vector2i(6,3)}], "refills": [{"pos": Vector2i(6,2), "type": 2}, {"pos": Vector2i(6,1), "type": 0}, {"pos": Vector2i(6,0), "type": 4}]}
	view._on_cascade_step(step6)
	
	var step7 = {"cleared": [Vector2i(5,3), Vector2i(6,3), Vector2i(7,3)], "falls": [{"from": Vector2i(4,2), "to": Vector2i(4,3)}, {"from": Vector2i(5,2), "to": Vector2i(5,3)}, {"from": Vector2i(6,2), "to": Vector2i(6,3)}, {"from": Vector2i(7,2), "to": Vector2i(7,3)}, {"from": Vector2i(4,1), "to": Vector2i(4,2)}, {"from": Vector2i(5,1), "to": Vector2i(5,2)}, {"from": Vector2i(6,1), "to": Vector2i(6,2)}, {"from": Vector2i(7,1), "to": Vector2i(7,2)}, {"from": Vector2i(4,0), "to": Vector2i(4,1)}, {"from": Vector2i(5,0), "to": Vector2i(5,1)}, {"from": Vector2i(6,0), "to": Vector2i(6,1)}, {"from": Vector2i(7,0), "to": Vector2i(7,1)}], "refills": [{"pos": Vector2i(4,0), "type": 0}, {"pos": Vector2i(5,0), "type": 4}, {"pos": Vector2i(6,0), "type": 1}, {"pos": Vector2i(7,0), "type": 2}]}
	view._on_cascade_step(step7)
	
	for pos in [Vector2i(4,0), Vector2i(5,0), Vector2i(4,1), Vector2i(5,1)]:
		var tile = view._cell_to_tile.get(pos)
		if tile:
			print("TILE at ", pos, ": type=", tile.tile_type, " visible=", tile.visible, " pos=", tile.position)
		else:
			print("TILE at ", pos, ": NULL")
		
	quit()
