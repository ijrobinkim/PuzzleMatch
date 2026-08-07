class_name BoardModel
extends RefCounted

const BONUS_NONE := ""
const BONUS_ROCKET_H := "rocket_h"
const BONUS_ROCKET_V := "rocket_v"
const BONUS_SPINNER := "spinner"
const BONUS_BOMB := "bomb"
const BONUS_ELECTRO_BALL := "electro_ball"

# Compatibility aliases
const BONUS_STRIPED_ROW := BONUS_ROCKET_H
const BONUS_STRIPED_COL := BONUS_ROCKET_V

const EMPTY_TYPE := -1
const POINTS_PER_TILE := 10

signal swap_rejected(a: Vector2i, b: Vector2i)
signal swap_committed(a: Vector2i, b: Vector2i)
signal cascade_step(step: Dictionary)
signal cascade_finished
signal move_consumed(moves_remaining: int)
signal score_changed(score: int)
signal level_completed
signal level_failed
signal board_reshuffled
signal log_event(message: String)
signal special_items_spawned

var width: int
var height: int
var tile_type_count: int
var types: Array = []
var bonuses: Array = []
var elements_map: Dictionary = {}
var moves_remaining: int
var score: int = 0
var objective: int
var target_objectives_remaining: Dictionary = {}
var is_busy: bool = false
var _rng := RandomNumberGenerator.new()

# Debug logger history variables
var initial_types: Array = []
var initial_bonuses: Array = []
var initial_elements_list: Array = []
var action_history: Array = []
var log_history: Array = []


func _init(level_data: LevelData, rng_seed: int = -1) -> void:
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()

	width = level_data.grid_width
	height = level_data.grid_height
	tile_type_count = level_data.tile_type_count
	moves_remaining = level_data.move_limit
	objective = level_data.objective
	target_objectives_remaining = level_data.target_objectives.duplicate()

	# 1. Fill default random tiles (reroll until no initial matches)
	_fill_random_grid()
	while not find_matches().is_empty():
		_fill_random_grid()

	# 2. Place predefined elements/gimmicks
	_load_initial_elements(level_data)

	# 3. Ensure the board has at least one valid move
	if not has_any_valid_move():
		reshuffle()

	# 4. Capture initial board state for blackbox logging
	initial_types = types.duplicate(true)
	initial_bonuses = bonuses.duplicate(true)
	if level_data.initial_elements:
		initial_elements_list = level_data.initial_elements.duplicate(true)
	else:
		initial_elements_list = []

	log_event.connect(func(msg: String): log_history.append(msg))
	swap_committed.connect(func(a: Vector2i, b: Vector2i):
		action_history.append("[Swap Commit] %s <-> %s" % [str(a), str(b)])
	)

func _load_initial_elements(level_data: LevelData) -> void:
	if level_data.initial_elements.is_empty():
		return
	var factory := ElementFactory.new()
	for item in level_data.initial_elements:
		if item is Dictionary:
			var cell := Vector2i(item.get("x", 0), item.get("y", 0))
			if item.has("pos"):
				cell = Vector2i(item["pos"])
			var elem_id: String = item.get("id", "")
			if not elem_id.is_empty():
				var elem := factory.create_element(elem_id)
				if elem:
					set_element(cell, elem)

static func get_color_name(type: int) -> String:
	match type:
		0: return "🔴 빨강"
		1: return "🔵 파랑"
		2: return "🟢 초록"
		3: return "🟡 노랑"
		4: return "🟣 보라"
		5: return "🟠 주황"
		_: return "타일"

static func get_bonus_name(kind: String) -> String:
	match kind:
		BONUS_ROCKET_H, BONUS_ROCKET_V: return "🚀 로켓"
		BONUS_SPINNER: return "🌀 스피너"
		BONUS_BOMB: return "💣 폭탄"
		BONUS_ELECTRO_BALL: return "⚡ 일렉트로 볼"
		_: return ""



func _fill_random_grid() -> void:
	types.clear()
	bonuses.clear()
	for x in width:
		var col_types: Array = []
		var col_bonuses: Array = []
		for y in height:
			col_types.append(_rng.randi() % tile_type_count)
			col_bonuses.append(BONUS_NONE)
		types.append(col_types)
		bonuses.append(col_bonuses)

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height

func get_tile_type(cell: Vector2i) -> int:
	return types[cell.x][cell.y]

func get_bonus_kind(cell: Vector2i) -> String:
	return bonuses[cell.x][cell.y]

func set_element(cell: Vector2i, element: BaseElement) -> void:
	if not is_in_bounds(cell):
		return
	if element == null:
		elements_map.erase(cell)
	else:
		elements_map[cell] = element
		element.grid_position = cell
		if not element.element_destroyed.is_connected(_on_element_destroyed):
			element.element_destroyed.connect(_on_element_destroyed)
		
		# If the element is Column, clear any gem block underneath it to make it empty inside.
		if element.element_id == "column":
			types[cell.x][cell.y] = EMPTY_TYPE

func get_element(cell: Vector2i) -> BaseElement:
	if elements_map.has(cell):
		var elem = elements_map[cell]
		if is_instance_valid(elem):
			return elem as BaseElement
	return null

func _on_element_destroyed(element: BaseElement) -> void:
	if element != null and not element.element_id.is_empty():
		if target_objectives_remaining.has(element.element_id):
			target_objectives_remaining[element.element_id] = max(0, target_objectives_remaining[element.element_id] - 1)
			if target_objectives_remaining[element.element_id] <= 0:
				target_objectives_remaining.erase(element.element_id)

	if element != null:
		var pos = element.grid_position
		if element.element_id == "column":
			types[pos.x][pos.y] = EMPTY_TYPE
			
		if elements_map.has(pos) and (elements_map[pos] == element or not is_instance_valid(elements_map[pos])):
			elements_map.erase(pos)
		else:
			for cell in elements_map.keys():
				if elements_map[cell] == element or not is_instance_valid(elements_map[cell]):
					elements_map.erase(cell)
					break

func is_objective_completed() -> bool:
	if not target_objectives_remaining.is_empty():
		return false
	return true

func damage_adjacent_elements(cleared_cells: Array, normal_match_cells: Array = []) -> void:
	var damaged_targets: Dictionary = {}
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	
	# 1. Self damage for all cleared cells
	for cell_val in cleared_cells:
		var cell: Vector2i = cell_val
		if elements_map.has(cell):
			var elem: BaseElement = elements_map[cell]
			if elem != null:
				var is_normal_match = normal_match_cells.has(cell)
				if (not is_normal_match) or elem.allows_self_damage:
					if not damaged_targets.has(elem):
						damaged_targets[elem] = "item" if not is_normal_match else "normal"
				
	# 2. Adjacent damage propagation from normal matching cells only
	var adjacent_sources = normal_match_cells
	if adjacent_sources.is_empty():
		adjacent_sources = cleared_cells
		
	for cell_val in adjacent_sources:
		var cell: Vector2i = cell_val
		var is_ivy_source = elements_map.has(cell) and elements_map[cell].element_id == "ivy"
		
		if not is_ivy_source:
			for d in dirs:
				var neighbor = cell + d
				if is_in_bounds(neighbor) and elements_map.has(neighbor):
					var elem: BaseElement = elements_map[neighbor]
					if elem != null and elem.allows_adjacent_damage and not cleared_cells.has(neighbor):
						if not damaged_targets.has(elem):
							damaged_targets[elem] = "normal"
	
	# Filter columns: If it is normal match damage ("normal"), only allow at most ONE column element
	# in the entire board to take damage. We pick the one with the maximum y coordinate (lowest segment).
	# This ensures only one column segment breaks per match across the whole board.
	var lowest_column: BaseElement = null
	for elem in damaged_targets.keys():
		if elem.element_id == "column" and damaged_targets[elem] == "normal":
			if lowest_column == null or elem.grid_position.y > lowest_column.grid_position.y:
				lowest_column = elem

	var columns_to_remove: Array = []
	for elem in damaged_targets.keys():
		if elem.element_id == "column" and damaged_targets[elem] == "normal":
			if elem != lowest_column:
				columns_to_remove.append(elem)

	for elem in columns_to_remove:
		damaged_targets.erase(elem)

	for elem in damaged_targets.keys():
		(elem as BaseElement).take_damage(1)


func _get_effective_type(x: int, y: int) -> int:
	if bonuses[x][y] != BONUS_NONE:
		return EMPTY_TYPE
	var cell := Vector2i(x, y)
	if elements_map.has(cell):
		var elem: BaseElement = elements_map[cell]
		if elem and elem.is_obstacle:
			return EMPTY_TYPE
	return types[x][y]


func find_matches(swap_target: Vector2i = Vector2i(-1, -1)) -> Array:
	var runs: Array = []
	for y in height:
		var run_start := 0
		for x in range(1, width + 1):
			var same: bool = x < width and _get_effective_type(x, y) == _get_effective_type(run_start, y)
			if not same:
				var length := x - run_start
				var eff_type := _get_effective_type(run_start, y)
				if length >= 3 and eff_type != EMPTY_TYPE:
					var cells: Array = []
					for rx in range(run_start, x):
						cells.append(Vector2i(rx, y))
					runs.append({"cells": cells, "dir": "h", "length": length, "color": eff_type})
				run_start = x

	for x in width:
		var run_start := 0
		for y in range(1, height + 1):
			var same: bool = y < height and _get_effective_type(x, y) == _get_effective_type(x, run_start)
			if not same:
				var length := y - run_start
				var eff_type := _get_effective_type(x, run_start)
				if length >= 3 and eff_type != EMPTY_TYPE:
					var cells: Array = []
					for ry in range(run_start, y):
						cells.append(Vector2i(x, ry))
					runs.append({"cells": cells, "dir": "v", "length": length, "color": eff_type})
				run_start = y

	var squares: Array = []
	for x in range(width - 1):
		for y in range(height - 1):
			var c: int = _get_effective_type(x, y)
			if c != EMPTY_TYPE and _get_effective_type(x+1, y) == c and _get_effective_type(x, y+1) == c and _get_effective_type(x+1, y+1) == c:
				squares.append({
					"cells": [Vector2i(x, y), Vector2i(x+1, y), Vector2i(x, y+1), Vector2i(x+1, y+1)],
					"dir": "sq",
					"length": 4,
					"color": c
				})

	if runs.is_empty() and squares.is_empty():
		return []

	var all_elements: Array = []
	all_elements.append_array(runs)
	all_elements.append_array(squares)

	var parent: Array = []
	for i in all_elements.size():
		parent.append(i)

	var find_root := func(start_i: int) -> int:
		var idx := start_i
		while parent[idx] != idx:
			idx = parent[idx]
		return idx

	for i in all_elements.size():
		for j in range(i + 1, all_elements.size()):
			if all_elements[i]["color"] != all_elements[j]["color"]:
				continue
			var shares := false
			for cell in all_elements[i]["cells"]:
				if all_elements[j]["cells"].has(cell):
					shares = true
					break
			if shares:
				var ri: int = find_root.call(i)
				var rj: int = find_root.call(j)
				if ri != rj:
					parent[ri] = rj

	var groups_by_root: Dictionary = {}
	for i in all_elements.size():
		var root: int = find_root.call(i)
		if not groups_by_root.has(root):
			groups_by_root[root] = []
		groups_by_root[root].append(all_elements[i])

	var matches: Array = []
	for root in groups_by_root.keys():
		var group_members: Array = groups_by_root[root]
		var all_cells: Array = []
		var has_h := false
		var has_v := false
		var has_sq := false
		var max_line_len := 0
		var longest_run: Dictionary = group_members[0]

		for elem in group_members:
			if elem["dir"] == "h":
				has_h = true
				if elem["length"] > max_line_len:
					max_line_len = elem["length"]
					longest_run = elem
			elif elem["dir"] == "v":
				has_v = true
				if elem["length"] > max_line_len:
					max_line_len = elem["length"]
					longest_run = elem
			elif elem["dir"] == "sq":
				has_sq = true

			for cell in elem["cells"]:
				if not all_cells.has(cell):
					all_cells.append(cell)

		var bonus_kind := BONUS_NONE
		var bonus_pos: Vector2i = longest_run["cells"][int(longest_run["cells"].size() / 2)]

		if max_line_len >= 5:
			bonus_kind = BONUS_ELECTRO_BALL
		elif has_h and has_v and all_cells.size() >= 5:
			bonus_kind = BONUS_BOMB
			for elem_a in group_members:
				if elem_a["dir"] != "h":
					continue
				for elem_b in group_members:
					if elem_b["dir"] != "v":
						continue
					for cell in elem_a["cells"]:
						if elem_b["cells"].has(cell):
							bonus_pos = cell
							break
		elif has_sq and all_cells.size() <= 6:
			bonus_kind = BONUS_SPINNER
		elif max_line_len == 4:
			bonus_kind = BONUS_ROCKET_V if longest_run["dir"] == "h" else BONUS_ROCKET_H
		elif has_h and has_v:
			bonus_kind = BONUS_BOMB

		if swap_target != Vector2i(-1, -1) and all_cells.has(swap_target):
			bonus_pos = swap_target

		var line_runs: Array = []
		for elem in group_members:
			line_runs.append(elem["cells"].duplicate())

		matches.append({
			"cells": all_cells,
			"runs": line_runs,
			"bonus_kind": bonus_kind,
			"bonus_pos": bonus_pos,
			"color": group_members[0]["color"]
		})

	return matches

func _can_swap_cell(cell: Vector2i) -> bool:
	if not is_in_bounds(cell):
		return false
	if elements_map.has(cell):
		var elem = elements_map[cell]
		if elem.is_obstacle or elem.element_id == "ivy":
			return false
	return true

func attempt_swap(a: Vector2i, b: Vector2i) -> bool:
	if is_busy:
		return false
	if not is_in_bounds(a) or not is_in_bounds(b):
		return false
	if absi(a.x - b.x) + absi(a.y - b.y) != 1:
		return false

	if not _can_swap_cell(a) or not _can_swap_cell(b):
		return false

	var bonus_a: String = bonuses[a.x][a.y]
	var bonus_b: String = bonuses[b.x][b.y]

	# Case 1: Combo of 2 Special Tiles
	if bonus_a != BONUS_NONE and bonus_b != BONUS_NONE:
		log_event.emit("[아이템 사용] %s + %s 콤보 발동! (%d,%d)↔(%d,%d)" % [get_bonus_name(bonus_a), get_bonus_name(bonus_b), a.x, a.y, b.x, b.y])
		swap_committed.emit(a, b)
		_consume_move()
		_handle_special_combo_async(a, bonus_a, b, bonus_b)
		return true

	# Case 2: Electro Ball + Color Tile
	if bonus_a == BONUS_ELECTRO_BALL and types[b.x][b.y] != EMPTY_TYPE:
		log_event.emit("[아이템 사용] ⚡ 일렉트로 볼 + %s 색상 콤보 발동!" % get_color_name(types[b.x][b.y]))
		swap_committed.emit(a, b)
		_consume_move()
		_do_electro_ball(a, b)
		return true
	elif bonus_b == BONUS_ELECTRO_BALL and types[a.x][a.y] != EMPTY_TYPE:
		log_event.emit("[아이템 사용] ⚡ 일렉트로 볼 + %s 색상 콤보 발동!" % get_color_name(types[a.x][a.y]))
		swap_committed.emit(a, b)
		_consume_move()
		_do_electro_ball(b, a)
		return true

	# Case 3: Swap Special Tile with Normal Color Tile
	if bonus_a != BONUS_NONE or bonus_b != BONUS_NONE:
		_swap_cells(a, b)
		var matches := find_matches(b)
		if not matches.is_empty():
			var special_cell: Vector2i = b if bonus_a != BONUS_NONE else a
			log_event.emit("[스왑 & 아이템 발동] (%d,%d) ↔ (%d,%d)" % [a.x, a.y, b.x, b.y])
			swap_committed.emit(a, b)
			_consume_move()
			_do_attempt_swap_cascade(b, special_cell)
			_check_game_over()
			return true
		else:
			var active_cell: Vector2i = b if bonus_a != BONUS_NONE else a
			var active_kind: String = bonus_a if bonus_a != BONUS_NONE else bonus_b
			log_event.emit("[아이템 사용] %s (%d,%d) 이동 발동!" % [get_bonus_name(active_kind), active_cell.x, active_cell.y])
			swap_committed.emit(a, b)
			_consume_move()
			_do_attempt_swap_cascade(Vector2i(-1,-1), active_cell)
			_check_game_over()
			return true

	# Case 4: Standard Color Swap
	_swap_cells(a, b)
	var matches := find_matches(b)
	if matches.is_empty():
		_swap_cells(a, b)
		log_event.emit("[스왑 취소] (%d,%d) ↔ (%d,%d) (매치 없음)" % [a.x, a.y, b.x, b.y])
		swap_rejected.emit(a, b)
		return false

	log_event.emit("[스왑 성공] (%d,%d) ↔ (%d,%d)" % [a.x, a.y, b.x, b.y])
	swap_committed.emit(a, b)
	_consume_move()
	_do_attempt_swap_cascade(b, Vector2i(-1,-1))
	return true

func _do_activate_special_tile(cell: Vector2i) -> void:
	action_history.append("[Tap Commit] Activated special item at %s" % str(cell))
	is_busy = true
	var cleared: Dictionary = {}
	cleared[cell] = true
	await _run_cascade_async(Vector2i(-1,-1), Vector2i(-1,-1), cleared)
	is_busy = false
	_check_game_over()

func activate_special_tile(cell: Vector2i) -> bool:
	if is_busy or not is_in_bounds(cell):
		return false
	var kind: String = bonuses[cell.x][cell.y]
	if kind == BONUS_NONE:
		return false

	log_event.emit("[아이템 사용] %s (%d,%d) 터치 발동!" % [get_bonus_name(kind), cell.x, cell.y])
	_consume_move()
	_do_activate_special_tile(cell)
	return true

func _consume_move() -> void:
	moves_remaining -= 1
	move_consumed.emit(moves_remaining)

func _check_game_over() -> void:
	if score >= objective:
		log_event.emit("[게임 완료] 목표 달성! 🎉 (최종 점수: %d점)" % score)
		level_completed.emit()
	elif moves_remaining <= 0:
		log_event.emit("[게임 실패] 남은 이동 횟수 소진! 😢")
		level_failed.emit()

func _swap_cells(a: Vector2i, b: Vector2i) -> void:
	var t: int = types[a.x][a.y]
	types[a.x][a.y] = types[b.x][b.y]
	types[b.x][b.y] = t

	var bo: String = bonuses[a.x][a.y]
	bonuses[a.x][a.y] = bonuses[b.x][b.y]
	bonuses[b.x][b.y] = bo

func _handle_special_combo_async(a: Vector2i, bonus_a: String, b: Vector2i, bonus_b: String) -> void:
	is_busy = true
	await _execute_special_combo_impl(a, bonus_a, b, bonus_b)
	is_busy = false
	_check_game_over()

func _execute_special_combo_impl(a: Vector2i, bonus_a: String, b: Vector2i, bonus_b: String) -> void:
	bonuses[a.x][a.y] = BONUS_NONE
	bonuses[b.x][b.y] = BONUS_NONE

	var cleared: Dictionary = {}
	cleared[a] = true
	cleared[b] = true

	var custom_rockets: Array = []
	var custom_spinners: Array = []

	var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var is_rocket_a := (bonus_a == BONUS_ROCKET_H or bonus_a == BONUS_ROCKET_V)
	var is_rocket_b := (bonus_b == BONUS_ROCKET_H or bonus_b == BONUS_ROCKET_V)

	if bonus_a == BONUS_ELECTRO_BALL and bonus_b == BONUS_ELECTRO_BALL:
		for x in width:
			for y in height:
				cleared[Vector2i(x, y)] = true
	elif bonus_a == BONUS_ELECTRO_BALL or bonus_b == BONUS_ELECTRO_BALL:
		var other_bonus := bonus_b if bonus_a == BONUS_ELECTRO_BALL else bonus_a
		var target_color: int = types[b.x][b.y] if bonus_a == BONUS_ELECTRO_BALL else types[a.x][a.y]
		if target_color == EMPTY_TYPE:
			target_color = _find_most_common_color()
		if target_color != EMPTY_TYPE:
			var target_cells: Array[Vector2i] = []
			for x in width:
				for y in height:
					if types[x][y] == target_color:
						target_cells.append(Vector2i(x, y))
			
			target_cells.shuffle()

			# 1. Conversion step (staggered visually in the view)
			var conversion_bonuses: Array = []
			for cell in target_cells:
				bonuses[cell.x][cell.y] = other_bonus
				conversion_bonuses.append({
					"pos": cell,
					"spawn_pos": cell,
					"kind": other_bonus,
					"match_cells": [],
				})
			
			cascade_step.emit({
				"matches": [],
				"cleared": [],
				"bonuses": conversion_bonuses,
				"falls": [],
				"refills": [],
				"spinners": [],
				"rockets": [],
				"is_electro_stagger": true,
			})

			# Wait for staggered conversion animation to finish in the view
			var conversion_delay := 0.35 + float(target_cells.size()) * 0.08
			await Engine.get_main_loop().create_timer(conversion_delay).timeout

			# 2. Sequential explosions in the model (packed into a single staggered step)
			var cumulative_cleared: Dictionary = {}
			var staggered_clears: Array = []
			
			for cell in target_cells:
				var step_cleared: Dictionary = {}
				var step_rockets: Array = []
				var step_spinners: Array = []

				step_cleared[cell] = true
				bonuses[cell.x][cell.y] = BONUS_NONE

				if other_bonus == BONUS_BOMB:
					for dx in range(-2, 3):
						for dy in range(-2, 3):
							var c: Vector2i = Vector2i(cell.x + dx, cell.y + dy)
							if is_in_bounds(c):
								step_cleared[c] = true
								bonuses[c.x][c.y] = BONUS_NONE
				elif other_bonus == BONUS_ROCKET_H or other_bonus == BONUS_ROCKET_V:
					var r_kind := other_bonus
					if r_kind == BONUS_ROCKET_H:
						for x in width:
							step_cleared[Vector2i(x, cell.y)] = true
							bonuses[x][cell.y] = BONUS_NONE
					else:
						for y in height:
							step_cleared[Vector2i(cell.x, y)] = true
							bonuses[cell.x][y] = BONUS_NONE
					step_rockets.append({"from": cell, "kind": r_kind, "already_emitted": true})
				elif other_bonus == BONUS_SPINNER:
					var cross_cells: Array[Vector2i] = []
					for dir in dirs:
						var c := cell + dir
						if is_in_bounds(c):
							cross_cells.append(c)
							step_cleared[c] = true
							bonuses[c.x][c.y] = BONUS_NONE
					
					var targets := _pick_random_targets(1, [cell])
					var target_cell := cell
					if not targets.is_empty():
						target_cell = targets[0]
					
					var spinner_event = {
						"from": cell,
						"cross": cross_cells,
						"target": target_cell,
						"item_kind": BONUS_SPINNER,
						"impact_area": [target_cell],
						"already_emitted": true,
					}
					step_spinners.append(spinner_event)
					custom_spinners.append(spinner_event)

				var new_cleared_cells: Array = []
				for c in step_cleared.keys():
					if not cumulative_cleared.has(c):
						new_cleared_cells.append(c)
						cumulative_cleared[c] = true

				staggered_clears.append({
					"center": cell,
					"cleared": new_cleared_cells,
					"rockets": step_rockets,
					"spinners": step_spinners,
					"kind": other_bonus,
				})

				var gained := new_cleared_cells.size() * POINTS_PER_TILE
				score += gained
				score_changed.emit(score)

			# Emit the single step containing all staggered clear events
			cascade_step.emit({
				"matches": [],
				"cleared": cumulative_cleared.keys(),
				"bonuses": [],
				"falls": [],
				"refills": [],
				"spinners": [],
				"rockets": [],
				"staggered_clears": staggered_clears,
			})

			# Wait for staggered explosion animation to finish in the view (max delay 0.4s + 0.35s)
			await Engine.get_main_loop().create_timer(0.75).timeout

			await _run_cascade_async(Vector2i(-1,-1), Vector2i(-1,-1), cumulative_cleared, custom_spinners, custom_rockets, true)
			return
	elif is_rocket_a and is_rocket_b:
		for x in width:
			cleared[Vector2i(x, b.y)] = true
		for y in height:
			cleared[Vector2i(b.x, y)] = true
		custom_rockets.append({"from": b, "kind": BONUS_ROCKET_H})
		custom_rockets.append({"from": b, "kind": BONUS_ROCKET_V})
	elif (is_rocket_a and bonus_b == BONUS_BOMB) or (bonus_a == BONUS_BOMB and is_rocket_b):
		for dy in range(-1, 2):
			var ry: int = b.y + dy
			if ry >= 0 and ry < height:
				for x in width:
					cleared[Vector2i(x, ry)] = true
				custom_rockets.append({"from": Vector2i(b.x, ry), "kind": BONUS_ROCKET_H})
		for dx in range(-1, 2):
			var rx: int = b.x + dx
			if rx >= 0 and rx < width:
				for y in height:
					cleared[Vector2i(rx, y)] = true
				custom_rockets.append({"from": Vector2i(rx, b.y), "kind": BONUS_ROCKET_V})
	elif bonus_a == BONUS_BOMB and bonus_b == BONUS_BOMB:
		for dx in range(-4, 5):
			for dy in range(-4, 5):
				var c: Vector2i = Vector2i(b.x + dx, b.y + dy)
				if is_in_bounds(c):
					cleared[c] = true
	elif bonus_a == BONUS_SPINNER and bonus_b == BONUS_SPINNER:
		var cross_cells: Array[Vector2i] = []
		for dir in dirs:
			var c: Vector2i = b + dir
			if is_in_bounds(c):
				cross_cells.append(c)
				cleared[c] = true
		var targets := _pick_random_targets(3, [b])
		for t in targets:
			custom_spinners.append({
				"from": b,
				"cross": cross_cells,
				"target": t,
				"item_kind": BONUS_SPINNER,
				"impact_area": [t]
			})
	elif (bonus_a == BONUS_SPINNER and is_rocket_b) or (is_rocket_a and bonus_b == BONUS_SPINNER):
		var cross_cells: Array[Vector2i] = []
		for dir in dirs:
			var c: Vector2i = b + dir
			if is_in_bounds(c):
				cross_cells.append(c)
				cleared[c] = true
		var targets := _pick_random_targets(1, [b])
		if not targets.is_empty():
			var t: Vector2i = targets[0]
			var rocket_kind := bonus_b if is_rocket_b else bonus_a
			var rocket_area: Array[Vector2i] = []
			if rocket_kind == BONUS_ROCKET_H:
				for x in width:
					var c := Vector2i(x, t.y)
					if not rocket_area.has(c):
						rocket_area.append(c)
			else:
				for y in height:
					var c := Vector2i(t.x, y)
					if not rocket_area.has(c):
						rocket_area.append(c)
			
			custom_spinners.append({
				"from": b,
				"cross": cross_cells,
				"target": t,
				"item_kind": rocket_kind,
				"impact_area": rocket_area
			})
	elif (bonus_a == BONUS_SPINNER and bonus_b == BONUS_BOMB) or (bonus_a == BONUS_BOMB and bonus_b == BONUS_SPINNER):
		var cross_cells: Array[Vector2i] = []
		for dir in dirs:
			var c: Vector2i = b + dir
			if is_in_bounds(c):
				cross_cells.append(c)
				cleared[c] = true
		var targets := _pick_random_targets(1, [b])
		if not targets.is_empty():
			var t: Vector2i = targets[0]
			var bomb_area: Array[Vector2i] = []
			for dx in range(-2, 3):
				for dy in range(-2, 3):
					var c: Vector2i = Vector2i(t.x + dx, t.y + dy)
					if is_in_bounds(c):
						if not bomb_area.has(c):
							bomb_area.append(c)
			custom_spinners.append({
				"from": b,
				"cross": cross_cells,
				"target": t,
				"item_kind": BONUS_BOMB,
				"impact_area": bomb_area
			})

	# Clear bonuses for blast zone cells so unrelated items on the board do not trigger secondary chain explosions
	var is_electro_convert := (bonus_a == BONUS_ELECTRO_BALL or bonus_b == BONUS_ELECTRO_BALL) and (bonus_a != bonus_b or bonus_a != BONUS_ELECTRO_BALL)
	if not is_electro_convert:
		for c in cleared.keys():
			bonuses[c.x][c.y] = BONUS_NONE

	await _run_cascade_async(Vector2i(-1,-1), Vector2i(-1,-1), cleared, custom_spinners, custom_rockets)

func _do_attempt_swap_cascade(swap_target: Vector2i, extra_trigger: Vector2i) -> void:
	is_busy = true
	await _run_cascade_async(swap_target, extra_trigger)
	is_busy = false
	_check_game_over()

func _do_electro_ball(ball: Vector2i, color_cell: Vector2i) -> void:
	is_busy = true
	await _execute_electro_ball_color_swap(ball, color_cell)
	is_busy = false
	_check_game_over()

func _execute_electro_ball_color_swap(ball_cell: Vector2i, color_cell: Vector2i) -> void:
	var target_color: int = types[color_cell.x][color_cell.y]
	bonuses[ball_cell.x][ball_cell.y] = BONUS_NONE

	var cleared: Dictionary = {}
	cleared[ball_cell] = true
	for x in width:
		for y in height:
			if types[x][y] == target_color:
				cleared[Vector2i(x, y)] = true

	await _run_cascade_async(Vector2i(-1,-1), Vector2i(-1,-1), cleared)



func _expand_bonus_triggers(cleared: Dictionary) -> Array:
	var changed := true
	var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var processed_bonuses: Dictionary = {}
	var spinner_events: Array = []
	var rocket_events: Array = []

	while changed:
		changed = false
		for cell in cleared.keys():
			if processed_bonuses.has(cell):
				continue
			var kind: String = bonuses[cell.x][cell.y]
			if kind == BONUS_NONE:
				continue
			processed_bonuses[cell] = true
			var extra: Array = []
			if kind == BONUS_ROCKET_H or kind == BONUS_ROCKET_V:
				rocket_events.append({
					"from": cell,
					"kind": kind
				})
				if kind == BONUS_ROCKET_H:
					for x in width:
						extra.append(Vector2i(x, cell.y))
				else:
					for y in height:
						extra.append(Vector2i(cell.x, y))
			elif kind == BONUS_BOMB:
				for dx in range(-2, 3):
					for dy in range(-2, 3):
						var c: Vector2i = Vector2i(cell.x + dx, cell.y + dy)
						if is_in_bounds(c):
							extra.append(c)
			elif kind == BONUS_SPINNER:
				var cross_cells: Array[Vector2i] = []
				for dir in dirs:
					var c: Vector2i = cell + dir
					if is_in_bounds(c):
						cross_cells.append(c)
						extra.append(c)
				var targets := _pick_random_targets(1, [cell])
				var target_cell: Vector2i = cell
				if not targets.is_empty():
					target_cell = targets[0]
				spinner_events.append({
					"from": cell,
					"cross": cross_cells,
					"target": target_cell,
					"item_kind": BONUS_NONE,
					"impact_area": [target_cell]
				})
			elif kind == BONUS_ELECTRO_BALL:
				var most_common := _find_most_common_color()
				if most_common != EMPTY_TYPE:
					for x in width:
						for y in height:
							if types[x][y] == most_common:
								extra.append(Vector2i(x, y))

			log_event.emit("[아이템 연쇄] %s 연쇄 폭발! (%d,%d)" % [get_bonus_name(kind), cell.x, cell.y])

			for c in extra:
				if not cleared.has(c):
					cleared[c] = true
					changed = true

	return [cleared, spinner_events, rocket_events]

func _find_most_common_color() -> int:
	var counts: Dictionary = {}
	for x in width:
		for y in height:
			var t: int = types[x][y]
			if t != EMPTY_TYPE:
				counts[t] = counts.get(t, 0) + 1
	var max_count := -1
	var best_color := EMPTY_TYPE
	for color in counts.keys():
		if counts[color] > max_count:
			max_count = counts[color]
			best_color = color
	return best_color

func _pick_random_targets(count: int, exclude: Array) -> Array:
	var normal_candidates: Array = []
	var all_candidates: Array = []
	for x in width:
		for y in height:
			var c := Vector2i(x, y)
			if not exclude.has(c) and types[x][y] != EMPTY_TYPE:
				if bonuses[x][y] == BONUS_NONE:
					normal_candidates.append(c)
				all_candidates.append(c)

	normal_candidates.shuffle()
	if normal_candidates.size() >= count:
		return normal_candidates.slice(0, count)

	all_candidates.shuffle()
	return all_candidates.slice(0, count)

func _is_column_blocked_above(x: int, y: int) -> bool:
	for check_y in range(y - 1, -1, -1):
		var check_cell := Vector2i(x, check_y)
		if elements_map.has(check_cell) and is_instance_valid(elements_map[check_cell]) and not elements_map[check_cell].allows_falling:
			return true
	return false

func _apply_gravity(cleared_cells: Array) -> Array:
	for cell in cleared_cells:
		types[cell.x][cell.y] = EMPTY_TYPE
		bonuses[cell.x][cell.y] = BONUS_NONE

	var final_falls: Dictionary = {}
	var moved := true
	while moved:
		moved = false
		for y in range(height - 1, 0, -1):
			for x in width:
				var dst := Vector2i(x, y)
				if types[dst.x][dst.y] != EMPTY_TYPE:
					continue
				if elements_map.has(dst) and is_instance_valid(elements_map[dst]) and not elements_map[dst].allows_falling:
					continue
					
				# 1. Column gimmick falling collapse
				var up := Vector2i(x, y - 1)
				var up_elem = elements_map.get(up)
				if up_elem and is_instance_valid(up_elem) and up_elem.element_id == "column":
					elements_map.erase(up)
					elements_map[dst] = up_elem
					up_elem.grid_position = dst
					types[dst.x][dst.y] = EMPTY_TYPE
					types[up.x][up.y] = EMPTY_TYPE
					
					var original_from = up
					for k in final_falls.keys():
						if final_falls[k] == up:
							original_from = k
							break
					final_falls[original_from] = dst
					moved = true
					continue
					
				# 2. Straight down
				var up_blocked = elements_map.has(up) and is_instance_valid(elements_map[up]) and not elements_map[up].allows_falling
				if not up_blocked and types[up.x][up.y] != EMPTY_TYPE:
					_move_tile_internal(up, dst, final_falls)
					moved = true
					continue
					
				# 2. Diagonal falls
				if _is_column_blocked_above(x, y):
					var diags := []
					if _rng.randi() % 2 == 0:
						if x > 0: diags.append(Vector2i(x - 1, y - 1))
						if x < width - 1: diags.append(Vector2i(x + 1, y - 1))
					else:
						if x < width - 1: diags.append(Vector2i(x + 1, y - 1))
						if x > 0: diags.append(Vector2i(x - 1, y - 1))
						
					for diag in diags:
						# Skip if the diag source cell is occupied by a static gimmick
						if elements_map.has(diag) and is_instance_valid(elements_map[diag]) and not elements_map[diag].allows_falling:
							continue
						var diag_blocked = elements_map.has(diag) and is_instance_valid(elements_map[diag]) and not elements_map[diag].allows_falling
						if not diag_blocked and types[diag.x][diag.y] != EMPTY_TYPE:
							_move_tile_internal(diag, dst, final_falls)
							moved = true
							break

	var falls_array: Array = []
	for k in final_falls.keys():
		falls_array.append({"from": k, "to": final_falls[k]})
	return falls_array

func _move_tile_internal(from_cell: Vector2i, to_cell: Vector2i, final_falls: Dictionary) -> void:
	# Safety guard: never write a gem into a cell occupied by a static gimmick
	if elements_map.has(to_cell) and is_instance_valid(elements_map[to_cell]) and not elements_map[to_cell].allows_falling:
		return
	
	types[to_cell.x][to_cell.y] = types[from_cell.x][from_cell.y]
	bonuses[to_cell.x][to_cell.y] = bonuses[from_cell.x][from_cell.y]
	types[from_cell.x][from_cell.y] = EMPTY_TYPE
	bonuses[from_cell.x][from_cell.y] = BONUS_NONE
	
	var original_from = from_cell
	for k in final_falls.keys():
		if final_falls[k] == from_cell:
			original_from = k
			break
	final_falls[original_from] = to_cell

func _refill_empty_cells() -> Array:
	var refills: Array = []
	for x in width:
		for y in range(height - 1, -1, -1):
			if types[x][y] == EMPTY_TYPE:
				var cell := Vector2i(x, y)
				if elements_map.has(cell) and is_instance_valid(elements_map[cell]) and not elements_map[cell].allows_falling:
					continue
				if not _is_column_blocked_above(x, y):
					var new_type := _rng.randi() % tile_type_count
					types[x][y] = new_type
					bonuses[x][y] = BONUS_NONE
					refills.append({"pos": cell, "type": new_type})
	return refills

func has_any_valid_move() -> bool:
	for x in width:
		for y in height:
			var cell := Vector2i(x, y)
			if bonuses[x][y] != BONUS_NONE:
				return true
			if x + 1 < width and _would_swap_valid(cell, Vector2i(x + 1, y)):
				return true
			if y + 1 < height and _would_swap_valid(cell, Vector2i(x, y + 1)):
				return true
	return false

func _would_swap_valid(a: Vector2i, b: Vector2i) -> bool:
	if not _can_swap_cell(a) or not _can_swap_cell(b):
		return false
	if bonuses[a.x][a.y] != BONUS_NONE or bonuses[b.x][b.y] != BONUS_NONE:
		return true
	_swap_cells(a, b)
	var has_match := not find_matches().is_empty()
	_swap_cells(a, b)
	return has_match

func get_all_hint_moves() -> Array:
	if is_busy:
		return []

	var candidates: Array = []
	for x in width:
		for y in height:
			var cell := Vector2i(x, y)
			var type_cell: int = types[cell.x][cell.y]
			if not _can_swap_cell(cell):
				continue

			if x + 1 < width:
				var right := Vector2i(x + 1, y)
				if _can_swap_cell(right):
					var type_right: int = types[right.x][right.y]
					_swap_cells(cell, right)
					var matches := find_matches()
					_swap_cells(cell, right)
					
					if not matches.is_empty():
						var best_m: Dictionary = matches[0]
						var best_score: int = best_m["cells"].size()
						for m in matches:
							var s: int = m["cells"].size()
							if m.get("bonus_kind", BONUS_NONE) != BONUS_NONE:
								s += 20
							if s > best_score:
								best_score = s
								best_m = m

						var cell_dict: Dictionary = {}
						var active_swaps: Dictionary = {}
						var match_region_dict: Dictionary = {}
						var match_line_regions: Array = []

						var m_color: int = best_m.get("color", -1)
						if type_cell == m_color:
							active_swaps[cell] = true
						if type_right == m_color:
							active_swaps[right] = true

						var runs: Array = best_m.get("runs", [best_m["cells"]])
						for run in runs:
							match_line_regions.append(run.duplicate())

						for c in best_m["cells"]:
							match_region_dict[c] = true
							var pre_c: Vector2i = c
							if c == cell:
								pre_c = right
							elif c == right:
								pre_c = cell
							cell_dict[pre_c] = true

						var bonus_kind: String = best_m.get("bonus_kind", BONUS_NONE)
						var total_matched: int = match_region_dict.size()
						var p := 10
						if bonus_kind == BONUS_ROCKET_H or bonus_kind == BONUS_ROCKET_V or bonus_kind == BONUS_BOMB:
							p = 40
						elif bonus_kind == BONUS_ELECTRO_BALL:
							p = 50
						elif bonus_kind == BONUS_SPINNER:
							p = 35
						elif bonus_kind != BONUS_NONE or total_matched == 4:
							p = 30

						candidates.append({
							"target_cells": cell_dict.keys(),
							"match_region_cells": match_region_dict.keys(),
							"match_line_regions": match_line_regions,
							"swap_a": cell,
							"swap_b": right,
							"active_swap_cells": active_swaps.keys(),
							"priority": p
						})

			if y + 1 < height:
				var down := Vector2i(x, y + 1)
				if not (elements_map.has(down) and elements_map[down].is_obstacle):
					var type_down: int = types[down.x][down.y]
					_swap_cells(cell, down)
					var matches := find_matches()
					_swap_cells(cell, down)
					
					if not matches.is_empty():
						var best_m: Dictionary = matches[0]
						var best_score: int = best_m["cells"].size()
						for m in matches:
							var s: int = m["cells"].size()
							if m.get("bonus_kind", BONUS_NONE) != BONUS_NONE:
								s += 20
							if s > best_score:
								best_score = s
								best_m = m

						var cell_dict: Dictionary = {}
						var active_swaps: Dictionary = {}
						var match_region_dict: Dictionary = {}
						var match_line_regions: Array = []

						var m_color: int = best_m.get("color", -1)
						if type_cell == m_color:
							active_swaps[cell] = true
						if type_down == m_color:
							active_swaps[down] = true

						var runs_down: Array = best_m.get("runs", [best_m["cells"]])
						for run in runs_down:
							match_line_regions.append(run.duplicate())

						for c in best_m["cells"]:
							match_region_dict[c] = true
							var pre_c: Vector2i = c
							if c == cell:
								pre_c = down
							elif c == down:
								pre_c = cell
							cell_dict[pre_c] = true

						var bonus_kind: String = best_m.get("bonus_kind", BONUS_NONE)
						var total_matched: int = match_region_dict.size()
						var p := 10
						if bonus_kind == BONUS_ROCKET_H or bonus_kind == BONUS_ROCKET_V or bonus_kind == BONUS_BOMB:
							p = 40
						elif bonus_kind == BONUS_ELECTRO_BALL:
							p = 50
						elif bonus_kind == BONUS_SPINNER:
							p = 35
						elif bonus_kind != BONUS_NONE or total_matched == 4:
							p = 30

						candidates.append({
							"target_cells": cell_dict.keys(),
							"match_region_cells": match_region_dict.keys(),
							"match_line_regions": match_line_regions,
							"swap_a": cell,
							"swap_b": down,
							"active_swap_cells": active_swaps.keys(),
							"priority": p
						})

	if candidates.is_empty():
		return []

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("priority", 0) > b.get("priority", 0)
	)

	return candidates

func find_hint_move(hint_index: int = 0) -> Dictionary:
	var moves := get_all_hint_moves()
	if moves.is_empty():
		return {}
	return moves[hint_index % moves.size()]

func is_hint_target_valid(target: Dictionary) -> bool:
	if target.is_empty():
		return false
	var a: Vector2i = target.get("swap_a", Vector2i(-1, -1))
	var b: Vector2i = target.get("swap_b", Vector2i(-1, -1))
	if not is_in_bounds(a) or not is_in_bounds(b):
		return false
	if a == b:
		return false
	if bonuses[a.x][a.y] != BONUS_NONE and bonuses[b.x][b.y] != BONUS_NONE:
		return true
	return _would_swap_valid(a, b)

func reshuffle() -> bool:
	log_event.emit("[보드] 이동 가능한 매치가 없어 판을 섞습니다!")
	
	# 1. Collect only valid active gem cells (exclude columns/obstacles and empty slots)
	var shuffle_cells: Array[Vector2i] = []
	var gem_colors: Array[int] = []
	for x in width:
		for y in height:
			var cell := Vector2i(x, y)
			var is_obstacle_cell = elements_map.has(cell) and is_instance_valid(elements_map[cell]) and elements_map[cell].is_obstacle
			var is_empty_cell = types[x][y] == EMPTY_TYPE
			
			if not is_obstacle_cell and not is_empty_cell:
				shuffle_cells.append(cell)
				gem_colors.append(types[x][y])
				
	if shuffle_cells.is_empty():
		return false

	var attempts := 0
	while attempts < 100:
		gem_colors.shuffle()
		for idx in shuffle_cells.size():
			var cell = shuffle_cells[idx]
			types[cell.x][cell.y] = gem_colors[idx]
			
		if find_matches().is_empty() and has_any_valid_move():
			board_reshuffled.emit()
			return true
		attempts += 1
		
	# 2. Fallback: Re-fill only the target active slots with new random gem colors
	var fallback_attempts := 0
	while fallback_attempts < 1000:
		for cell in shuffle_cells:
			types[cell.x][cell.y] = _rng.randi() % tile_type_count
		if find_matches().is_empty() and has_any_valid_move():
			board_reshuffled.emit()
			return true
		fallback_attempts += 1
		
	push_warning("reshuffle() exhausted all attempts without reaching a valid board state")
	board_reshuffled.emit()
	return false

func spawn_random_special_items() -> void:
	if is_busy:
		return
	var valid_cells: Array[Vector2i] = []
	for x in width:
		for y in height:
			if types[x][y] != EMPTY_TYPE and bonuses[x][y] == BONUS_NONE:
				valid_cells.append(Vector2i(x, y))

	if valid_cells.is_empty():
		log_event.emit("[디버그] ⚠️ 이미 모든 일반 타일에 특수 아이템이 생성되어 있습니다!")
		return

	var cell: Vector2i = valid_cells.pick_random()
	var possible_bonuses: Array[String] = [
		BONUS_ROCKET_H,
		BONUS_ROCKET_V,
		BONUS_BOMB,
		BONUS_SPINNER,
		BONUS_ELECTRO_BALL
	]
	var bonus: String = possible_bonuses.pick_random()
	bonuses[cell.x][cell.y] = bonus

	log_event.emit("[디버그] 🎲 (%d,%d) 위치에 %s 1개 생성!" % [cell.x, cell.y, get_bonus_name(bonus)])
	special_items_spawned.emit()

func _run_cascade_async(swap_target: Vector2i = Vector2i(-1, -1), extra_trigger_cell: Vector2i = Vector2i(-1, -1), initial_cleared: Dictionary = {}, extra_spinners: Array = [], extra_rockets: Array = [], skip_scoring: bool = false) -> void:
	var current_cleared := initial_cleared.duplicate()
	var pending_spinners := extra_spinners.duplicate()
	var pending_rockets := extra_rockets.duplicate()
	var current_extra_trigger := extra_trigger_cell
	var current_swap_target := swap_target

	var has_more_work := true

	while has_more_work:
		has_more_work = false
		
		var matches := find_matches(current_swap_target)
		var match_infos: Array = []
		var bonus_spawns: Array = []
		var normal_match_cells: Array = []

		for m in matches:
			var anchor: Vector2i = m["cells"][0]
			match_infos.append({
				"type": m["color"],
				"count": m["cells"].size(),
				"position": m["bonus_pos"] if m["bonus_kind"] != BONUS_NONE else anchor,
			})
			for cell in m["cells"]:
				current_cleared[cell] = true
				normal_match_cells.append(cell)
			if m["bonus_kind"] != BONUS_NONE:
				bonus_spawns.append({
					"pos": m["bonus_pos"],
					"spawn_pos": m["bonus_pos"],
					"kind": m["bonus_kind"],
					"match_cells": m["cells"].duplicate(),
				})
				log_event.emit("[아이템 생성] %s 생성! (%d,%d)" % [get_bonus_name(m["bonus_kind"]), m["bonus_pos"].x, m["bonus_pos"].y])
			else:
				log_event.emit("[매치] %s %d개 제거!" % [get_color_name(m["color"]), m["cells"].size()])
		
		if current_extra_trigger != Vector2i(-1, -1):
			current_cleared[current_extra_trigger] = true
			current_extra_trigger = Vector2i(-1, -1)

		# 1. Expand cleared cells and score if we have matches
		if not current_cleared.is_empty():
			var expand_res := _expand_bonus_triggers(current_cleared)
			current_cleared = expand_res[0]
			pending_spinners.append_array(expand_res[1])
			pending_rockets.append_array(expand_res[2])

			for spawn in bonus_spawns:
				current_cleared.erase(spawn["spawn_pos"])

			if not skip_scoring:
				var gained := current_cleared.size() * POINTS_PER_TILE
				score += gained
				score_changed.emit(score)
				log_event.emit("[점수] +%d점 (총 %d점)" % [gained, score])
			else:
				skip_scoring = false

		# 2. Run gravity and refill regardless of whether we had matches,
		# because previous refills might have enabled new diagonal falls.
		var cleared_cells: Array = current_cleared.keys()
		if not cleared_cells.is_empty():
			damage_adjacent_elements(cleared_cells, normal_match_cells)
			var cleared_strs: Array = []
			for c in cleared_cells:
				cleared_strs.append("(%d,%d)" % [c.x, c.y])
			log_event.emit("[캐스케이드 소거] %d개 셀: %s" % [cleared_cells.size(), ", ".join(cleared_strs)])
			
		var falls := _apply_gravity(cleared_cells)
		if not falls.is_empty():
			var fall_strs: Array = []
			for f in falls:
				fall_strs.append("(%d,%d)→(%d,%d)" % [f["from"].x, f["from"].y, f["to"].x, f["to"].y])
			log_event.emit("[낙하] %d개: %s" % [falls.size(), ", ".join(fall_strs)])
		var refills := _refill_empty_cells()
		if not refills.is_empty():
			var refill_strs: Array = []
			for r in refills:
				refill_strs.append("(%d,%d)=타입%d" % [r["pos"].x, r["pos"].y, r["type"]])
			log_event.emit("[보충] %d개: %s" % [refills.size(), ", ".join(refill_strs)])

		# 3. Apply bonus spawning if we have matches
		for spawn in bonus_spawns:
			var final_pos: Vector2i = spawn["spawn_pos"]
			for f in falls:
				if f["from"] == spawn["spawn_pos"]:
					final_pos = f["to"]
					break
			bonuses[final_pos.x][final_pos.y] = spawn["kind"]
			spawn["pos"] = final_pos

		# 4. Emit step if there are matches, falls, or refills
		if not cleared_cells.is_empty() or not falls.is_empty() or not refills.is_empty():
			var emit_spinners: Array = []
			for sp in pending_spinners:
				if not sp.get("already_emitted", false):
					emit_spinners.append(sp)

			var emit_rockets: Array = []
			for rk in pending_rockets:
				if not rk.get("already_emitted", false):
					emit_rockets.append(rk)

			cascade_step.emit({
				"matches": match_infos,
				"cleared": cleared_cells,
				"bonuses": bonus_spawns,
				"falls": falls,
				"refills": refills,
				"spinners": emit_spinners,
				"rockets": emit_rockets,
			})

			has_more_work = true

		current_swap_target = Vector2i(-1, -1)
		current_cleared.clear()

		var delayed_impacts: Array = []
		for sp in pending_spinners:
			if sp.has("impact_area") or sp.has("target"):
				delayed_impacts.append(sp)
		
		pending_spinners.clear()
		pending_rockets.clear()

		if not delayed_impacts.is_empty():
			await Engine.get_main_loop().create_timer(0.70).timeout
			for sp in delayed_impacts:
				var area: Array = sp.get("impact_area", [sp.get("target", Vector2i(-1, -1))])
				for c in area:
					if c != Vector2i(-1, -1):
						current_cleared[c] = true
			
			for c in current_cleared.keys():
				if is_in_bounds(c):
					bonuses[c.x][c.y] = BONUS_NONE
			
			has_more_work = true
	
	# Board integrity check: log any non-gimmick cell that is still EMPTY_TYPE (bug indicator)
	var orphan_empties: Array = []
	for x in width:
		for y in height:
			if types[x][y] == EMPTY_TYPE:
				var cell := Vector2i(x, y)
				var has_static = elements_map.has(cell) and is_instance_valid(elements_map[cell]) and not elements_map[cell].allows_falling
				if not has_static:
					orphan_empties.append("(%d,%d)" % [x, y])
	if not orphan_empties.is_empty():
		log_event.emit("[⚠️ 정합성 오류] 기믹 없이 빈 셀 %d개 발견: %s" % [orphan_empties.size(), ", ".join(orphan_empties)])

	if not has_any_valid_move():
		reshuffle()
	cascade_finished.emit()
