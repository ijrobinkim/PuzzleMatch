class_name BoardView
extends Node2D

const CELL_SIZE := 128.0
const TILE_SCENE: PackedScene = preload("res://scenes/board/tile.tscn")

var model: BoardModel
var _tile_pool: Array = []
var _cell_to_tile: Dictionary = {}
var _selected_cell := Vector2i(-1, -1)
var _drag_start_cell := Vector2i(-1, -1)
var _drag_start_pos := Vector2.ZERO
const DRAG_THRESHOLD := 30.0

var _pending_steps: Array = []
var _is_animating: bool = false
var _active_swap_tween: Tween

func start_level(level_data: LevelData) -> void:
	model = BoardModel.new(level_data)
	model.cascade_step.connect(_on_cascade_step)
	model.swap_committed.connect(_on_swap_committed)
	model.swap_rejected.connect(_on_swap_rejected)
	model.move_consumed.connect(func(remaining: int): EventBus.move_used.emit(remaining))
	model.level_completed.connect(func(): EventBus.level_completed.emit(level_data.level_id, 3))
	model.level_failed.connect(func(): EventBus.level_failed.emit(level_data.level_id))
	model.board_reshuffled.connect(func(): EventBus.board_shuffled.emit())
	model.log_event.connect(func(msg: String): EventBus.log_emitted.emit(msg, "board"))
	EventBus.level_started.emit(level_data.level_id)
	_render_initial_board()

func _render_initial_board() -> void:
	for x in model.width:
		for y in model.height:
			var cell := Vector2i(x, y)
			var tile := _get_pooled_tile()
			tile.setup(cell, model.get_tile_type(cell), model.get_bonus_kind(cell), CELL_SIZE)
			tile.animate_spawn(0.3)
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

func _on_swap_committed(a: Vector2i, b: Vector2i) -> void:
	var tile_a: Tile = _cell_to_tile.get(a)
	var tile_b: Tile = _cell_to_tile.get(b)
	_cell_to_tile[a] = tile_b
	_cell_to_tile[b] = tile_a

	_active_swap_tween = create_tween().set_parallel(true)
	if tile_a:
		_active_swap_tween.tween_property(tile_a, "position", Vector2(b.x, b.y) * CELL_SIZE, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tile_a.cell = b
	if tile_b:
		_active_swap_tween.tween_property(tile_b, "position", Vector2(a.x, a.y) * CELL_SIZE, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tile_b.cell = a

func _on_swap_rejected(a: Vector2i, b: Vector2i) -> void:
	var tile_a: Tile = _cell_to_tile.get(a)
	var tile_b: Tile = _cell_to_tile.get(b)

	var tween := create_tween().set_parallel(true)
	if tile_a:
		tween.tween_property(tile_a, "position", Vector2(b.x, b.y) * CELL_SIZE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if tile_b:
		tween.tween_property(tile_b, "position", Vector2(a.x, a.y) * CELL_SIZE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

	var return_tween := create_tween().set_parallel(true)
	if tile_a:
		return_tween.tween_property(tile_a, "position", Vector2(a.x, a.y) * CELL_SIZE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if tile_b:
		return_tween.tween_property(tile_b, "position", Vector2(b.x, b.y) * CELL_SIZE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await return_tween.finished

func _on_cascade_step(step: Dictionary) -> void:
	_pending_steps.append(step)
	if not _is_animating:
		_process_cascade_pipeline()

func _process_cascade_pipeline() -> void:
	_is_animating = true

	# 1. Wait for swap animation to finish completely
	if _active_swap_tween and _active_swap_tween.is_running():
		await _active_swap_tween.finished
		_active_swap_tween = null

	# Brief pause so user sees the matched tiles aligned before breaking
	await get_tree().create_timer(0.2).timeout

	while not _pending_steps.is_empty():
		var step: Dictionary = _pending_steps.pop_front()

		for match_info in step["matches"]:
			EventBus.tiles_matched.emit(match_info["type"], match_info["count"], match_info["position"])

		# 2. Tile breaking / pop particle animation
		if not step["cleared"].is_empty():
			var clear_tween := create_tween().set_parallel(true)
			var has_clear_tweens := false
			for cell in step["cleared"]:
				var tile: Tile = _cell_to_tile.get(cell)
				if tile:
					tile.animate_clear(0.35)
					has_clear_tweens = true
			if has_clear_tweens:
				await get_tree().create_timer(0.35).timeout

			for cell in step["cleared"]:
				var tile: Tile = _cell_to_tile.get(cell)
				if tile:
					tile.reset()
					tile.visible = false
					_cell_to_tile.erase(cell)

		# Brief pause before gravity fall
		await get_tree().create_timer(0.1).timeout

		# 3. Slower Falling & Refill animation
		var move_tween := create_tween().set_parallel(true)
		var has_move_tweens := false
		for fall in step["falls"]:
			var tile: Tile = _cell_to_tile.get(fall["from"])
			if tile:
				_cell_to_tile.erase(fall["from"])
				_cell_to_tile[fall["to"]] = tile
				tile.cell = fall["to"]
				move_tween.tween_property(tile, "position", Vector2(fall["to"].x, fall["to"].y) * CELL_SIZE, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				has_move_tweens = true

		for refill in step["refills"]:
			var tile := _get_pooled_tile()
			tile.setup(refill["pos"], refill["type"], model.get_bonus_kind(refill["pos"]), CELL_SIZE)
			tile.position = Vector2(refill["pos"].x, -1) * CELL_SIZE
			move_tween.tween_property(tile, "position", Vector2(refill["pos"].x, refill["pos"].y) * CELL_SIZE, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_cell_to_tile[refill["pos"]] = tile
			has_move_tweens = true

		for spawn in step["bonuses"]:
			var tile: Tile = _cell_to_tile.get(spawn["pos"])
			if tile:
				tile.setup(spawn["pos"], model.get_tile_type(spawn["pos"]), spawn["kind"], CELL_SIZE)

		if has_move_tweens:
			await move_tween.finished

		# Pause between cascade steps if cascading continues
		if not _pending_steps.is_empty():
			await get_tree().create_timer(0.25).timeout

	_is_animating = false

func _cell_at_position(local_pos: Vector2) -> Vector2i:
	return Vector2i(int(local_pos.x / CELL_SIZE), int(local_pos.y / CELL_SIZE))

func _unhandled_input(event: InputEvent) -> void:
	if model == null or model.is_busy or _is_animating:
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
		if model.get_bonus_kind(cell) != BoardModel.BONUS_NONE:
			model.activate_special_tile(cell)
		else:
			_selected_cell = cell
		return
	if _selected_cell == cell:
		if model.get_bonus_kind(cell) != BoardModel.BONUS_NONE:
			model.activate_special_tile(cell)
		_selected_cell = Vector2i(-1, -1)
		return
	var dist := absi(_selected_cell.x - cell.x) + absi(_selected_cell.y - cell.y)
	if dist == 1:
		model.attempt_swap(_selected_cell, cell)
		_selected_cell = Vector2i(-1, -1)
	else:
		if model.get_bonus_kind(cell) != BoardModel.BONUS_NONE:
			model.activate_special_tile(cell)
			_selected_cell = Vector2i(-1, -1)
		else:
			_selected_cell = cell
