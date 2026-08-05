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

var _current_hint_target: Dictionary = {}
var _hint_timer: SceneTreeTimer = null
var _hint_loop_timer: SceneTreeTimer = null
var _is_hint_active: bool = false

func start_level(level_data: LevelData) -> void:
	model = BoardModel.new(level_data)
	model.cascade_step.connect(_on_cascade_step)
	model.swap_committed.connect(_on_swap_committed)
	model.swap_rejected.connect(_on_swap_rejected)
	model.move_consumed.connect(func(remaining: int): EventBus.move_used.emit(remaining))
	model.level_completed.connect(func(): EventBus.level_completed.emit(level_data.level_id, 3))
	model.level_failed.connect(func(): EventBus.level_failed.emit(level_data.level_id))
	model.board_reshuffled.connect(func():
		_current_hint_target = {}
		EventBus.board_shuffled.emit()
		_schedule_hint_timer()
	)
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
	_schedule_hint_timer()

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
	_cancel_hint_timers()
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
	_cancel_hint_timers()
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
	_schedule_hint_timer()

func _on_cascade_step(step: Dictionary) -> void:
	_pending_steps.append(step)
	if not _is_animating:
		_process_cascade_pipeline()

func _process_cascade_pipeline() -> void:
	_cancel_hint_timers()
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

		# 2. Tile breaking / pop particle animation & Item gather animation
		var bonuses_in_step: Array = step.get("bonuses", [])
		var cleared_cells: Array = step.get("cleared", [])

		var converging_cells: Dictionary = {} # cell -> target_spawn_pos
		var bonus_spawn_map: Dictionary = {} # spawn_pos -> bonus_dict

		for b in bonuses_in_step:
			var spawn_pos: Vector2i = b.get("spawn_pos", b["pos"])
			bonus_spawn_map[spawn_pos] = b
			var match_cells: Array = b.get("match_cells", [])
			for c in match_cells:
				if c != spawn_pos:
					converging_cells[c] = spawn_pos

		var has_gather_tweens := false

		# A. Normal cleared tiles (not part of item creation gathering)
		for cell in cleared_cells:
			if not converging_cells.has(cell):
				var tile: Tile = _cell_to_tile.get(cell)
				if tile:
					tile.animate_clear(0.35)
					has_gather_tweens = true

		# B. Converging tiles (sliding towards user's target / item position)
		for cell in converging_cells.keys():
			var target_spawn_pos: Vector2i = converging_cells[cell]
			var tile: Tile = _cell_to_tile.get(cell)
			if tile:
				tile.animate_converge_to(target_spawn_pos, CELL_SIZE, 0.32)
				has_gather_tweens = true

		# C. Target spawn tile (absorbing / wobble pulse)
		for spawn_pos in bonus_spawn_map.keys():
			var target_tile: Tile = _cell_to_tile.get(spawn_pos)
			if target_tile:
				target_tile.animate_gather_target(0.32)
				has_gather_tweens = true

		if has_gather_tweens:
			await get_tree().create_timer(0.32).timeout

		# Clean up cleared & converged tiles
		for cell in cleared_cells:
			var tile: Tile = _cell_to_tile.get(cell)
			if tile:
				tile.reset()
				tile.visible = false
				_cell_to_tile.erase(cell)

		# D. Transform target spawn tiles into Bonus Items with pop animation & particle burst
		if not bonus_spawn_map.is_empty():
			for spawn_pos in bonus_spawn_map.keys():
				var b: Dictionary = bonus_spawn_map[spawn_pos]
				var target_tile: Tile = _cell_to_tile.get(spawn_pos)
				if target_tile:
					target_tile.setup(spawn_pos, target_tile.tile_type, b["kind"], CELL_SIZE)
					target_tile.animate_item_transform(b["kind"], 0.35)

			await get_tree().create_timer(0.35).timeout

		# Brief pause before gravity fall
		await get_tree().create_timer(0.1).timeout

		# 3. Stacked Column Falling & Refill animation
		var move_tween := create_tween().set_parallel(true)
		var has_move_tweens := false
		var landing_tiles: Array = []

		for fall in step["falls"]:
			var tile: Tile = _cell_to_tile.get(fall["from"])
			if tile:
				_cell_to_tile.erase(fall["from"])
				_cell_to_tile[fall["to"]] = tile
				tile.cell = fall["to"]
				var dist := fall["to"].y - fall["from"].y
				var duration := 0.22 + dist * 0.07
				move_tween.tween_property(tile, "position", Vector2(fall["to"].x, fall["to"].y) * CELL_SIZE, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				landing_tiles.append(tile)
				has_move_tweens = true

		var refills_by_col: Dictionary = {}
		for refill in step["refills"]:
			var col: int = refill["pos"].x
			if not refills_by_col.has(col):
				refills_by_col[col] = []
			refills_by_col[col].append(refill)

		for col in refills_by_col.keys():
			var col_refills: Array = refills_by_col[col]
			var n_refills := col_refills.size()
			for i in range(n_refills):
				var refill: Dictionary = col_refills[i]
				var pos: Vector2i = refill["pos"]
				var start_y := -(n_refills - i)
				var tile := _get_pooled_tile()
				tile.setup(pos, refill["type"], model.get_bonus_kind(pos), CELL_SIZE)
				tile.position = Vector2(pos.x, start_y) * CELL_SIZE
				var dist := pos.y - start_y
				var duration := 0.22 + dist * 0.07
				move_tween.tween_property(tile, "position", Vector2(pos.x, pos.y) * CELL_SIZE, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				_cell_to_tile[pos] = tile
				landing_tiles.append(tile)
				has_move_tweens = true

		for spawn in step["bonuses"]:
			var tile: Tile = _cell_to_tile.get(spawn["pos"])
			if tile:
				tile.setup(spawn["pos"], model.get_tile_type(spawn["pos"]), spawn["kind"], CELL_SIZE)

		if has_move_tweens:
			await move_tween.finished
			for tile in landing_tiles:
				if is_instance_valid(tile) and tile.visible:
					tile.animate_land_bounce(0.12)

		# Pause between cascade steps if cascading continues
		if not _pending_steps.is_empty():
			await get_tree().create_timer(0.25).timeout

	_is_animating = false

	if not _current_hint_target.is_empty() and not model.is_hint_target_valid(_current_hint_target):
		_current_hint_target = {}
	_schedule_hint_timer()

func _schedule_hint_timer() -> void:
	_cancel_hint_timers()
	if model == null or model.is_busy or _is_animating:
		return
	var timer := get_tree().create_timer(2.0)
	_hint_timer = timer
	timer.timeout.connect(func():
		if _hint_timer == timer:
			_hint_timer = null
			_run_hint_loop()
	)

func _cancel_hint_timers() -> void:
	_hint_timer = null
	_hint_loop_timer = null
	_stop_active_hint_animations()

func _stop_active_hint_animations() -> void:
	_is_hint_active = false
	if _current_hint_target.has("target_cells"):
		for cell in _current_hint_target["target_cells"]:
			var tile: Tile = _cell_to_tile.get(cell)
			if tile:
				tile.stop_hint()

func _run_hint_loop() -> void:
	if model == null or model.is_busy or _is_animating:
		return

	if not _current_hint_target.is_empty():
		if not model.is_hint_target_valid(_current_hint_target):
			_current_hint_target = {}

	if _current_hint_target.is_empty():
		_current_hint_target = model.find_hint_move()

	if _current_hint_target.is_empty():
		return

	_is_hint_active = true
	var target_cells: Array = _current_hint_target.get("target_cells", [])
	for cell in target_cells:
		var tile: Tile = _cell_to_tile.get(cell)
		if tile:
			tile.animate_hint()

	var loop_timer := get_tree().create_timer(1.5)
	_hint_loop_timer = loop_timer
	loop_timer.timeout.connect(func():
		if _hint_loop_timer == loop_timer and _is_hint_active:
			_hint_loop_timer = null
			_run_hint_loop()
	)

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
		_cancel_hint_timers()
		if pressed:
			_drag_start_cell = cell
			_drag_start_pos = pos
		else:
			_handle_release(cell)
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if _drag_start_cell == Vector2i(-1, -1):
			return
		_cancel_hint_timers()
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
		_schedule_hint_timer()
		return
	if _selected_cell == Vector2i(-1, -1):
		if model.get_bonus_kind(cell) != BoardModel.BONUS_NONE:
			model.activate_special_tile(cell)
		else:
			_selected_cell = cell
		_schedule_hint_timer()
		return
	if _selected_cell == cell:
		if model.get_bonus_kind(cell) != BoardModel.BONUS_NONE:
			model.activate_special_tile(cell)
		_selected_cell = Vector2i(-1, -1)
		_schedule_hint_timer()
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
		_schedule_hint_timer()
