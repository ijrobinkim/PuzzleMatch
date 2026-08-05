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
var _current_hint_index: int = 0
var _hint_cycle_count: int = 0
var _hint_timer: SceneTreeTimer = null
var _hint_loop_timer: SceneTreeTimer = null
var _is_hint_active: bool = false
var _hint_outline_drawer: HintOutlineDrawer = null

class HintOutlineDrawer extends Node2D:
	var cell_size: float = 128.0
	var padding: float = 8.0
	var line_color: Color = Color(1.0, 0.9, 0.35, 0.95)
	var line_width: float = 4.0
	var shadow_color: Color = Color(1.0, 0.85, 0.2, 0.45)
	var cells: Array = []

	func set_cells(new_cells: Array) -> void:
		cells = new_cells
		queue_redraw()

	func _draw() -> void:
		if cells.is_empty():
			return

		var cell_set: Dictionary = {}
		for c in cells:
			cell_set[Vector2i(c)] = true

		var segments: Array = []

		for c in cell_set.keys():
			var cell: Vector2i = c
			var px := cell.x * cell_size
			var py := cell.y * cell_size

			# 1. Top Edge: exists if (x, y-1) is NOT in cell_set
			if not cell_set.has(Vector2i(cell.x, cell.y - 1)):
				var x_start := px if cell_set.has(Vector2i(cell.x - 1, cell.y)) else px - padding
				var x_end := px + cell_size if cell_set.has(Vector2i(cell.x + 1, cell.y)) else px + cell_size + padding
				segments.append([Vector2(x_start, py - padding), Vector2(x_end, py - padding)])

			# 2. Bottom Edge: exists if (x, y+1) is NOT in cell_set
			if not cell_set.has(Vector2i(cell.x, cell.y + 1)):
				var x_start := px if cell_set.has(Vector2i(cell.x - 1, cell.y)) else px - padding
				var x_end := px + cell_size if cell_set.has(Vector2i(cell.x + 1, cell.y)) else px + cell_size + padding
				segments.append([Vector2(x_start, py + cell_size + padding), Vector2(x_end, py + cell_size + padding)])

			# 3. Left Edge: exists if (x-1, y) is NOT in cell_set
			if not cell_set.has(Vector2i(cell.x - 1, cell.y)):
				var y_start := py if cell_set.has(Vector2i(cell.x, cell.y - 1)) else py - padding
				var y_end := py + cell_size if cell_set.has(Vector2i(cell.x, cell.y + 1)) else py + cell_size + padding
				segments.append([Vector2(px - padding, y_start), Vector2(px - padding, y_end)])

			# 4. Right Edge: exists if (x+1, y) is NOT in cell_set
			if not cell_set.has(Vector2i(cell.x + 1, cell.y)):
				var y_start := py if cell_set.has(Vector2i(cell.x, cell.y - 1)) else py - padding
				var y_end := py + cell_size if cell_set.has(Vector2i(cell.x, cell.y + 1)) else py + cell_size + padding
				segments.append([Vector2(px + cell_size + padding, y_start), Vector2(px + cell_size + padding, y_end)])

		# Draw glow shadow lines first
		for seg in segments:
			draw_line(seg[0], seg[1], shadow_color, line_width + 6.0, true)

		# Draw crisp main border lines
		for seg in segments:
			draw_line(seg[0], seg[1], line_color, line_width, true)

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
	model.special_items_spawned.connect(func():
		for x in model.width:
			for y in model.height:
				var cell := Vector2i(x, y)
				var tile := _ensure_tile_at(cell)
				tile.setup(cell, model.get_tile_type(cell), model.get_bonus_kind(cell), CELL_SIZE)
				tile.animate_gather_target(0.25)
	)
	EventBus.level_started.emit(level_data.level_id)
	_render_initial_board()

func _ensure_tile_at(cell: Vector2i) -> Tile:
	var tile: Tile = _cell_to_tile.get(cell)
	if tile == null or not is_instance_valid(tile):
		tile = _get_pooled_tile()
		_cell_to_tile[cell] = tile
	return tile

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
			tile.reset()
			tile.visible = true
			return tile
	var tile: Tile = TILE_SCENE.instantiate()
	add_child(tile)
	_tile_pool.append(tile)
	return tile

func _perform_user_swap(a: Vector2i, b: Vector2i) -> void:
	if _is_animating or model == null or model.is_busy:
		return
	if not model.is_in_bounds(a) or not model.is_in_bounds(b):
		return

	_is_animating = true
	_cancel_hint_timers()

	var tile_a: Tile = _cell_to_tile.get(a)
	var tile_b: Tile = _cell_to_tile.get(b)

	if tile_a:
		tile_a.stop_hint(CELL_SIZE)
	if tile_b:
		tile_b.stop_hint(CELL_SIZE)

	var is_combo := (model.get_bonus_kind(a) != BoardModel.BONUS_NONE and model.get_bonus_kind(b) != BoardModel.BONUS_NONE)

	if is_combo:
		# Item Merge: tile_a slides into destination cell B
		var swap_tween := create_tween().set_parallel(true)
		if tile_a:
			swap_tween.tween_property(tile_a, "position", Vector2(b.x, b.y) * CELL_SIZE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if tile_b:
			swap_tween.tween_property(tile_b, "scale", Vector2(1.25, 1.25), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		await swap_tween.finished

		# Absorb tile_a into tile_b at destination B: erase source A
		_cell_to_tile.erase(a)
		if tile_a:
			tile_a.reset()
			tile_a.visible = false

		if tile_b:
			var merge_pulse := create_tween()
			merge_pulse.tween_property(tile_b, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			await merge_pulse.finished

		_is_animating = false
		model.attempt_swap(a, b)
	else:
		# Standard 2-way swap
		var swap_tween := create_tween().set_parallel(true)
		if tile_a:
			swap_tween.tween_property(tile_a, "position", Vector2(b.x, b.y) * CELL_SIZE, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if tile_b:
			swap_tween.tween_property(tile_b, "position", Vector2(a.x, a.y) * CELL_SIZE, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		await swap_tween.finished

		_is_animating = false
		var success := model.attempt_swap(a, b)

		if not success:
			_is_animating = true
			var revert_tween := create_tween().set_parallel(true)
			if tile_a:
				revert_tween.tween_property(tile_a, "position", Vector2(a.x, a.y) * CELL_SIZE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			if tile_b:
				revert_tween.tween_property(tile_b, "position", Vector2(a.x, a.y) * CELL_SIZE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			await revert_tween.finished
			_is_animating = false
			_schedule_hint_timer()

func _on_swap_committed(a: Vector2i, b: Vector2i) -> void:
	_cancel_hint_timers()
	var tile_a: Tile = _cell_to_tile.get(a)
	var tile_b: Tile = _cell_to_tile.get(b)

	if tile_a == null:
		# Combo merge absorption already handled: cell 'a' is empty, tile_b is at destination cell 'b'
		_cell_to_tile.erase(a)
		if tile_b:
			tile_b.cell = b
			tile_b.position = Vector2(b.x, b.y) * CELL_SIZE
	else:
		_cell_to_tile[a] = tile_b
		_cell_to_tile[b] = tile_a
		if tile_a:
			tile_a.cell = b
			tile_a.position = Vector2(b.x, b.y) * CELL_SIZE
		if tile_b:
			tile_b.cell = a
			tile_b.position = Vector2(a.x, a.y) * CELL_SIZE

func _on_swap_rejected(a: Vector2i, b: Vector2i) -> void:
	_cancel_hint_timers()

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
			_perform_user_swap(start, target)

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
		var sel := _selected_cell
		_selected_cell = Vector2i(-1, -1)
		_perform_user_swap(sel, cell)
	else:
		if model.get_bonus_kind(cell) != BoardModel.BONUS_NONE:
			model.activate_special_tile(cell)
			_selected_cell = Vector2i(-1, -1)
		else:
			_selected_cell = cell
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

		# Collect rocket delays for sequential penetration clear animation
		var rocket_delay_map: Dictionary = {}
		var rockets_in_step: Array = step.get("rockets", [])
		var max_rocket_delay := 0.0

		if not rockets_in_step.is_empty():
			for rk in rockets_in_step:
				var origin: Vector2i = rk["from"]
				var kind: String = rk["kind"]
				_animate_rocket_launch_projectile(origin, kind)
				if kind == BoardModel.BONUS_ROCKET_H:
					for x in model.width:
						var dist := absi(x - origin.x)
						var c := Vector2i(x, origin.y)
						var delay: float = dist * 0.045
						if not rocket_delay_map.has(c) or delay < rocket_delay_map[c]:
							rocket_delay_map[c] = delay
						if delay > max_rocket_delay:
							max_rocket_delay = delay
				elif kind == BoardModel.BONUS_ROCKET_V:
					for y in model.height:
						var dist := absi(y - origin.y)
						var c := Vector2i(origin.x, y)
						var delay: float = dist * 0.045
						if not rocket_delay_map.has(c) or delay < rocket_delay_map[c]:
							rocket_delay_map[c] = delay
						if delay > max_rocket_delay:
							max_rocket_delay = delay

		# A. Normal cleared tiles (not part of item creation gathering or spinner impact area)
		for cell in cleared_cells:
			if not converging_cells.has(cell):
				var tile: Tile = _cell_to_tile.get(cell)
				if tile:
					var delay: float = rocket_delay_map.get(cell, 0.0)
					if delay > 0.0:
						var t_ref := tile
						get_tree().create_timer(delay).timeout.connect(func():
							if is_instance_valid(t_ref):
								t_ref.animate_clear(0.28)
						)
					else:
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
			var wait_time: float = maxf(0.35, max_rocket_delay + 0.30)
			await get_tree().create_timer(wait_time).timeout

		# Process Spinner cross flash & pinpoint flying propeller animations
		var spinners_in_step: Array = step.get("spinners", [])
		if not spinners_in_step.is_empty():
			for sp in spinners_in_step:
				_animate_spinner_event(sp)
			await get_tree().create_timer(0.48).timeout

		# Clean up cleared & converged tiles (except spawn_pos and spinner_impact_cells)
		for cell in cleared_cells:
			if bonus_spawn_map.has(cell):
				continue
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
				else:
					var new_tile := _get_pooled_tile()
					new_tile.setup(spawn_pos, model.get_tile_type(spawn_pos), b["kind"], CELL_SIZE)
					new_tile.animate_item_transform(b["kind"], 0.35)
					_cell_to_tile[spawn_pos] = new_tile

			await get_tree().create_timer(0.35).timeout

		# Brief pause before gravity fall
		await get_tree().create_timer(0.08).timeout

		# 3. Smooth Falling & Refill animation (All tiles drop together simultaneously)
		var move_tween := create_tween().set_parallel(true)
		var has_move_tweens := false

		for fall in step["falls"]:
			var tile: Tile = _cell_to_tile.get(fall["from"])
			if tile:
				_cell_to_tile.erase(fall["from"])
				_cell_to_tile[fall["to"]] = tile
				tile.cell = fall["to"]
				var target_pos := Vector2(fall["to"].x, fall["to"].y) * CELL_SIZE
				move_tween.tween_property(tile, "position", target_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				has_move_tweens = true

		var refills_by_col: Dictionary = {}
		for refill in step["refills"]:
			var col: int = refill["pos"].x
			if not refills_by_col.has(col):
				refills_by_col[col] = []
			refills_by_col[col].append(refill)

		for col in refills_by_col.keys():
			var col_refills: Array = refills_by_col[col]
			col_refills.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return a["pos"].y < b["pos"].y
			)
			var total_in_col: int = col_refills.size()
			for idx in total_in_col:
				var refill: Dictionary = col_refills[idx]
				var dest_pos: Vector2i = refill["pos"]
				var tile := _get_pooled_tile()
				tile.setup(dest_pos, refill["type"], "", CELL_SIZE)

				var start_y: float = -1.0 - float(total_in_col - 1 - idx)
				tile.position = Vector2(dest_pos.x, start_y) * CELL_SIZE

				var target_pos := Vector2(dest_pos.x, dest_pos.y) * CELL_SIZE
				move_tween.tween_property(tile, "position", target_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				_cell_to_tile[dest_pos] = tile
				has_move_tweens = true

		for spawn in step["bonuses"]:
			var tile: Tile = _cell_to_tile.get(spawn["pos"])
			if tile:
				tile.setup(spawn["pos"], tile.tile_type, spawn["kind"], CELL_SIZE)

		if has_move_tweens:
			await move_tween.finished

		# We DO NOT sync here anymore because the model might have advanced multiple steps.

		# Pause between cascade steps if cascading continues
		if not _pending_steps.is_empty():
			await get_tree().create_timer(0.25).timeout

	_is_animating = false

	# Full Board State Sync at the very end of all animations, if model is fully done
	if not model.is_busy:
		for x in model.width:
			for y in model.height:
				var cell := Vector2i(x, y)
				var tile := _ensure_tile_at(cell)
				tile.setup(cell, model.get_tile_type(cell), model.get_bonus_kind(cell), CELL_SIZE)
				tile.position = Vector2(x, y) * CELL_SIZE

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

func _show_hint_region_boxes(cells: Array) -> void:
	if _hint_outline_drawer == null:
		_hint_outline_drawer = HintOutlineDrawer.new()
		_hint_outline_drawer.z_index = 5
		_hint_outline_drawer.visible = false
		add_child(_hint_outline_drawer)

	if cells.is_empty():
		_hide_hint_region_boxes()
		return

	_hint_outline_drawer.set_cells(cells)
	if not _hint_outline_drawer.visible or _hint_outline_drawer.modulate.a < 0.5:
		_hint_outline_drawer.modulate.a = 0.0
		_hint_outline_drawer.visible = true
		var tween := create_tween()
		tween.tween_property(_hint_outline_drawer, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _hide_hint_region_boxes() -> void:
	if _hint_outline_drawer and _hint_outline_drawer.visible:
		var tween := create_tween()
		tween.tween_property(_hint_outline_drawer, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.finished.connect(func():
			if _hint_outline_drawer:
				_hint_outline_drawer.visible = false
		)

func _cancel_hint_timers() -> void:
	_hint_timer = null
	_hint_loop_timer = null
	_current_hint_index = 0
	_hint_cycle_count = 0
	_hide_hint_region_boxes()
	_stop_active_hint_animations()

func _reset_hint_tile_visuals() -> void:
	for cell in _cell_to_tile.keys():
		var tile: Tile = _cell_to_tile[cell]
		if tile:
			tile.stop_hint(CELL_SIZE)

func _stop_active_hint_animations() -> void:
	_is_hint_active = false
	_reset_hint_tile_visuals()

func _run_hint_loop() -> void:
	if model == null or model.is_busy or _is_animating:
		return

	var hint_moves := model.get_all_hint_moves()
	if hint_moves.is_empty():
		_current_hint_target = {}
		_hide_hint_region_boxes()
		return

	if _hint_cycle_count == 0 or _current_hint_target.is_empty():
		_reset_hint_tile_visuals()
		_current_hint_index = _current_hint_index % hint_moves.size()
		_current_hint_target = hint_moves[_current_hint_index]

		var region_cells: Array = _current_hint_target.get("match_region_cells", [])
		if region_cells.is_empty():
			region_cells = _current_hint_target.get("target_cells", [])
		_show_hint_region_boxes(region_cells)

	_is_hint_active = true
	var swap_a: Vector2i = _current_hint_target.get("swap_a", Vector2i(-1, -1))
	var swap_b: Vector2i = _current_hint_target.get("swap_b", Vector2i(-1, -1))
	var target_cells: Array = _current_hint_target.get("target_cells", [])
	var active_swap_cells: Array = _current_hint_target.get("active_swap_cells", [])

	if swap_a == swap_b:
		var tile_a: Tile = _cell_to_tile.get(swap_a)
		if tile_a:
			tile_a.animate_hint_pulse()
	else:
		for c in active_swap_cells:
			var tile: Tile = _cell_to_tile.get(c)
			if tile:
				var target_c: Vector2i = swap_b if c == swap_a else swap_a
				var dir := Vector2(target_c - c)
				tile.animate_hint_nudge(dir, CELL_SIZE)

	for cell in target_cells:
		if not active_swap_cells.has(cell):
			var tile: Tile = _cell_to_tile.get(cell)
			if tile:
				tile.animate_hint_match_pulse()

	_hint_cycle_count += 1
	var wait_duration := 1.2
	if _hint_cycle_count >= 3:
		_hint_cycle_count = 0
		_current_hint_index += 1
		wait_duration = 1.2 + 2.0
		
		var rest_timer := get_tree().create_timer(1.2)
		rest_timer.timeout.connect(func():
			if _is_hint_active:
				_reset_hint_tile_visuals()
				_hide_hint_region_boxes()
		)

	var loop_timer := get_tree().create_timer(wait_duration)
	_hint_loop_timer = loop_timer
	loop_timer.timeout.connect(func():
		if _hint_loop_timer == loop_timer and _is_hint_active:
			_hint_loop_timer = null
			_run_hint_loop()
	)

func _cell_at_position(local_pos: Vector2) -> Vector2i:
	return Vector2i(int(local_pos.x / CELL_SIZE), int(local_pos.y / CELL_SIZE))

func _animate_spinner_event(sp: Dictionary) -> void:
	var from_cell: Vector2i = sp["from"]
	var target_cell: Vector2i = sp["target"]
	var item_kind: String = sp.get("item_kind", BoardModel.BONUS_SPINNER)

	var center_pos := Vector2(from_cell.x + 0.5, from_cell.y + 0.5) * CELL_SIZE
	var target_pos := Vector2(target_cell.x + 0.5, target_cell.y + 0.5) * CELL_SIZE

	_spawn_cross_flash_particles(center_pos)

	var flying_prop := Sprite2D.new()
	var icon_path := "res://assets/sprites/board/item_spinner.png"
	if item_kind == BoardModel.BONUS_BOMB:
		icon_path = "res://assets/sprites/board/item_bomb.png"
	elif item_kind == BoardModel.BONUS_ROCKET_H or item_kind == BoardModel.BONUS_ROCKET_V:
		icon_path = "res://assets/sprites/board/item_rocket_h.png"

	var tex := Tile._get_icon(icon_path)
	if tex:
		flying_prop.texture = tex
	flying_prop.scale = Vector2(0.80, 0.80)
	flying_prop.position = center_pos
	flying_prop.z_index = 20
	add_child(flying_prop)

	var mid_pos := (center_pos + target_pos) * 0.5 + Vector2(0.0, -140.0)

	var tween := create_tween().set_parallel(true)
	tween.tween_method(func(t: float):
		if is_instance_valid(flying_prop):
			var p := (1.0 - t) * (1.0 - t) * center_pos + 2.0 * (1.0 - t) * t * mid_pos + t * t * target_pos
			flying_prop.position = p
			flying_prop.rotation_degrees = t * 720.0
	, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	tween.chain().tween_callback(func():
		if is_instance_valid(flying_prop):
			_spawn_hit_spark_particles(target_pos)
			flying_prop.queue_free()

			var impact_area: Array = sp.get("impact_area", [target_cell])
			for c in impact_area:
				var target_tile: Tile = _cell_to_tile.get(c)
				if target_tile:
					_cell_to_tile.erase(c)
					var tw := target_tile.animate_clear(0.35)
					if tw:
						tw.chain().tween_callback(func():
							if is_instance_valid(target_tile):
								target_tile.reset()
								target_tile.visible = false
						)
					else:
						target_tile.reset()
						target_tile.visible = false

			if item_kind == BoardModel.BONUS_ROCKET_H or item_kind == BoardModel.BONUS_ROCKET_V:
				_animate_rocket_launch_projectile(target_cell, BoardModel.BONUS_ROCKET_H)
				_animate_rocket_launch_projectile(target_cell, BoardModel.BONUS_ROCKET_V)
			elif item_kind == BoardModel.BONUS_BOMB:
				_spawn_cross_flash_particles(target_pos)
	)

func _spawn_cross_flash_particles(center_pos: Vector2) -> void:
	var dirs := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	for d in dirs:
		var particles := CPUParticles2D.new()
		particles.position = center_pos
		particles.emitting = false
		particles.one_shot = true
		particles.amount = 10
		particles.lifetime = 0.35
		particles.explosiveness = 0.9
		particles.spread = 25.0
		particles.direction = d
		particles.gravity = Vector2.ZERO
		particles.initial_velocity_min = 180.0
		particles.initial_velocity_max = 280.0
		particles.scale_amount_min = 3.0
		particles.scale_amount_max = 6.0
		particles.color = Color(1.0, 0.9, 0.3, 1.0)
		add_child(particles)
		particles.restart()
		get_tree().create_timer(0.4).timeout.connect(particles.queue_free)

func _spawn_hit_spark_particles(target_pos: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.position = target_pos
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 16
	particles.lifetime = 0.4
	particles.explosiveness = 0.95
	particles.spread = 180.0
	particles.gravity = Vector2(0, 400)
	particles.initial_velocity_min = 140.0
	particles.initial_velocity_max = 300.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 8.0
	particles.color = Color(0.2, 0.9, 1.0, 1.0)
	add_child(particles)
	particles.restart()
	get_tree().create_timer(0.45).timeout.connect(particles.queue_free)

func _animate_rocket_launch_projectile(origin: Vector2i, kind: String) -> void:
	var start_pos := Vector2(origin.x + 0.5, origin.y + 0.5) * CELL_SIZE
	var tex_path := "res://assets/sprites/board/item_rocket_h.png" if kind == BoardModel.BONUS_ROCKET_H else "res://assets/sprites/board/item_rocket_v.png"
	var tex := Tile._get_icon(tex_path)
	if not tex:
		return

	var directions: Array[Vector2] = []
	var end_positions: Array[Vector2] = []

	if kind == BoardModel.BONUS_ROCKET_H:
		directions = [Vector2.LEFT, Vector2.RIGHT]
		end_positions = [Vector2(-64, start_pos.y), Vector2(model.width * CELL_SIZE + 64, start_pos.y)]
	else:
		directions = [Vector2.UP, Vector2.DOWN]
		end_positions = [Vector2(start_pos.x, -64), Vector2(start_pos.x, model.height * CELL_SIZE + 64)]

	for i in directions.size():
		var dir := directions[i]
		var end_pos := end_positions[i]

		var r_sprite := Sprite2D.new()
		r_sprite.texture = tex
		r_sprite.scale = Vector2(0.40, 0.40)
		r_sprite.position = start_pos
		r_sprite.rotation = dir.angle()
		r_sprite.z_index = 25
		add_child(r_sprite)

		var dist := start_pos.distance_to(end_pos)
		var duration := dist / 1600.0

		var tween := create_tween()
		tween.tween_property(r_sprite, "position", end_pos, duration).set_trans(Tween.TRANS_LINEAR)
		tween.chain().tween_callback(r_sprite.queue_free)
