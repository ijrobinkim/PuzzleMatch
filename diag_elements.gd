# Diagnostic script to trace element creation and board state
# Run from Godot editor: File > Quick Open > paste path
extends SceneTree

func _init():
	print("=== DIAGNOSTIC START ===")
	
	# Step 1: Test ElementFactory
	print("\n--- Step 1: ElementFactory ---")
	var factory = ElementFactory.new()
	print("  Factory created: ", factory != null)
	print("  Registry keys: ", factory._registry.keys())
	
	var box = factory.create_element("box")
	print("  box created: ", box != null)
	if box:
		print("  box.element_id: ", box.element_id)
		print("  box.is_obstacle: ", box.is_obstacle)
		print("  box.allows_falling: ", box.allows_falling)
		print("  box.max_health: ", box.max_health)
		print("  box class: ", box.get_class())
		print("  box script: ", box.get_script())
		box.free()
	
	# Step 2: Test LevelData creation
	print("\n--- Step 2: LevelData ---")
	var level = LevelData.new()
	level.level_id = "test_diag"
	level.grid_width = 8
	level.grid_height = 8
	level.move_limit = 30
	level.tile_type_count = 5
	level.target_objectives = {"box": 4}
	var initial_elems: Array = []
	for x in 2:
		for y in 2:
			initial_elems.append({"x": x, "y": y, "id": "box"})
	level.initial_elements = initial_elems
	print("  initial_elements count: ", level.initial_elements.size())
	print("  initial_elements[0]: ", level.initial_elements[0])
	print("  initial_elements is_empty: ", level.initial_elements.is_empty())
	
	# Step 3: Test BoardModel creation
	print("\n--- Step 3: BoardModel ---")
	var model = BoardModel.new(level, 42)
	print("  model.width: ", model.width)
	print("  model.height: ", model.height)
	print("  model.elements_map size: ", model.elements_map.size())
	print("  model.elements_map keys: ", model.elements_map.keys())
	print("  model.target_objectives_remaining: ", model.target_objectives_remaining)
	
	# Check element at each position
	for x in 2:
		for y in 2:
			var cell = Vector2i(x, y)
			var elem = model.get_element(cell)
			var tile_type = model.get_tile_type(cell)
			print("  cell ", cell, ": element=", elem, " tile_type=", tile_type)
			if elem:
				print("    elem.element_id=", elem.element_id, " elem.is_obstacle=", elem.is_obstacle)
	
	# Check a non-element cell
	var normal_cell = Vector2i(5, 5)
	print("  normal cell ", normal_cell, ": tile_type=", model.get_tile_type(normal_cell), " element=", model.get_element(normal_cell))
	
	print("\n=== DIAGNOSTIC END ===")
	quit()
