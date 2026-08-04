class_name BoardView
extends Node2D

const CELL_SIZE := 120.0
const TILE_SCENE: PackedScene = preload("res://scenes/board/tile.tscn")

var model: BoardModel
var _tile_pool: Array = []
var _cell_to_tile: Dictionary = {}
var _selected_cell := Vector2i(-1, -1)
var _drag_start_cell := Vector2i(-1, -1)
var _drag_start_pos := Vector2.ZERO
const DRAG_THRESHOLD := 30.0


func start_level(level_data: LevelData) -> void:
	model = BoardModel.new(level_data)
	model.cascade_step.connect(_on_cascade_step)
	model.swap_rejected.connect(_on_swap_rejected)
	model.move_consumed.connect(func(remaining: int): EventBus.move_used.emit(remaining))
	model.level_completed.connect(func(): EventBus.level_completed.emit(level_data.level_id, 3))
	model.level_failed.connect(func(): EventBus.level_failed.emit(level_data.level_id))
	model.board_reshuffled.connect(func(): EventBus.board_shuffled.emit())
	EventBus.level_started.emit(level_data.level_id)
	_render_initial_board()

func _render_initial_board() -> void:
	for x in model.width:
		for y in model.height:
			var cell := Vector2i(x, y)
			var tile := _get_pooled_tile()
			tile.setup(cell, model.get_tile_type(cell), model.get_bonus_kind(cell), CELL_SIZE)
			tile.animate_spawn()
			_cell_to_tile[cell] = tile

func _get_pooled_tile() -> Tile:
	for tile in _tile_pool:
		if not tile.visible:
			tile.visible = true
			return tile
	var tile: Tile = TILE_SCENE.instantiate()
	add_child(tile)
	_tile_pool.append(tile)
	return tile

func _on_cascade_step(step: Dictionary) -> void:
	for match_info in step["matches"]:
		EventBus.tiles_matched.emit(match_info["type"], match_info["count"], match_info["position"])
	for cell in step["cleared"]:
		var tile: Tile = _cell_to_tile.get(cell)
		if tile:
			tile.animate_clear()
			tile.reset()
			tile.visible = false
			_cell_to_tile.erase(cell)
	for fall in step["falls"]:
		var tile: Tile = _cell_to_tile.get(fall["from"])
		if tile:
			_cell_to_tile.erase(fall["from"])
			_cell_to_tile[fall["to"]] = tile
			tile.animate_move_to(fall["to"], CELL_SIZE)
	for refill in step["refills"]:
		var tile := _get_pooled_tile()
		tile.setup(refill["pos"], refill["type"], "", CELL_SIZE)
		tile.animate_spawn()
		_cell_to_tile[refill["pos"]] = tile
	for spawn in step["bonuses"]:
		var tile: Tile = _cell_to_tile.get(spawn["pos"])
		if tile:
			tile.setup(spawn["pos"], model.get_tile_type(spawn["pos"]), spawn["kind"], CELL_SIZE)

func _on_swap_rejected(a: Vector2i, b: Vector2i) -> void:
	for cell in [a, b]:
		var tile: Tile = _cell_to_tile.get(cell)
		if tile:
			tile.animate_move_to(cell, CELL_SIZE)

func _cell_at_position(local_pos: Vector2) -> Vector2i:
	return Vector2i(int(local_pos.x / CELL_SIZE), int(local_pos.y / CELL_SIZE))

func _unhandled_input(event: InputEvent) -> void:
	if model == null or model.is_busy:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pressed: bool = event.is_pressed() if event is InputEventScreenTouch else (event as InputEventMouseButton).pressed
		var pos: Vector2 = event.position if event is InputEventScreenTouch else (event as InputEventMouseButton).position
		var cell := _cell_at_position(to_local(pos))
		if not model.is_in_bounds(cell):
			return
		if pressed:
			_drag_start_cell = cell
			_drag_start_pos = pos
		else:
			_handle_release(cell)
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if _drag_start_cell == Vector2i(-1, -1):
			return
		var pos: Vector2 = event.position if event is InputEventScreenDrag else (event as InputEventMouseMotion).position
		var delta: Vector2 = pos - _drag_start_pos
		if delta.length() >= DRAG_THRESHOLD:
			var dir := Vector2i(0, 0)
			if absf(delta.x) > absf(delta.y):
				dir = Vector2i(1 if delta.x > 0 else -1, 0)
			else:
				dir = Vector2i(0, 1 if delta.y > 0 else -1)
			var start := _drag_start_cell
			var target := start + dir
			_drag_start_cell = Vector2i(-1, -1)
			_selected_cell = Vector2i(-1, -1)
			model.attempt_swap(start, target)

func _handle_release(cell: Vector2i) -> void:
	var start := _drag_start_cell
	_drag_start_cell = Vector2i(-1, -1)
	if start != cell:
		return
	if _selected_cell == Vector2i(-1, -1):
		_selected_cell = cell
		return
	if _selected_cell == cell:
		_selected_cell = Vector2i(-1, -1)
		return
	var dist := absi(_selected_cell.x - cell.x) + absi(_selected_cell.y - cell.y)
	if dist == 1:
		model.attempt_swap(_selected_cell, cell)
		_selected_cell = Vector2i(-1, -1)
	else:
		_selected_cell = cell

