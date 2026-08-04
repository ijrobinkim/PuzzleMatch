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

var width: int
var height: int
var tile_type_count: int
var types: Array = []
var bonuses: Array = []
var moves_remaining: int
var score: int = 0
var objective: int
var is_busy: bool = false
var _rng := RandomNumberGenerator.new()

func _init(level_data: LevelData, rng_seed: int = -1) -> void:
	width = level_data.grid_width
	height = level_data.grid_height
	tile_type_count = level_data.tile_type_count
	moves_remaining = level_data.move_limit
	objective = level_data.objective
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	_fill_random_grid()
	while not find_matches().is_empty():
		_fill_random_grid()
	if not has_any_valid_move():
		reshuffle()

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

func find_matches(swap_target: Vector2i = Vector2i(-1, -1)) -> Array:
	var runs: Array = []
	# 1. Horizontal runs (len >= 3)
	for y in height:
		var run_start := 0
		for x in range(1, width + 1):
			var same: bool = x < width and types[x][y] == types[run_start][y]
			if not same:
				var length := x - run_start
				if length >= 3 and types[run_start][y] != EMPTY_TYPE:
					var cells: Array = []
					for rx in range(run_start, x):
						cells.append(Vector2i(rx, y))
					runs.append({"cells": cells, "dir": "h", "length": length, "color": types[run_start][y]})
				run_start = x

	# 2. Vertical runs (len >= 3)
	for x in width:
		var run_start := 0
		for y in range(1, height + 1):
			var same: bool = y < height and types[x][y] == types[x][run_start]
			if not same:
				var length := y - run_start
				if length >= 3 and types[x][run_start] != EMPTY_TYPE:
					var cells: Array = []
					for ry in range(run_start, y):
						cells.append(Vector2i(x, ry))
					runs.append({"cells": cells, "dir": "v", "length": length, "color": types[x][run_start]})
				run_start = y

	# 3. 2x2 Square runs
	var squares: Array = []
	for x in range(width - 1):
		for y in range(height - 1):
			var c: int = types[x][y]
			if c != EMPTY_TYPE and types[x+1][y] == c and types[x][y+1] == c and types[x+1][y+1] == c:
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

	# Union-Find to group connected elements of SAME color
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

		# Creation Hierarchy (Royal Kingdom rules)
		if max_line_len >= 5:
			bonus_kind = BONUS_ELECTRO_BALL
		elif has_h and has_v and all_cells.size() >= 5:
			bonus_kind = BONUS_BOMB
			# Find intersection cell for L/T shape
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
			bonus_kind = BONUS_ROCKET_H if longest_run["dir"] == "h" else BONUS_ROCKET_V
		elif has_h and has_v:
			bonus_kind = BONUS_BOMB

		# Override spawn location if user initiated swap target is in this match
		if swap_target != Vector2i(-1, -1) and all_cells.has(swap_target):
			bonus_pos = swap_target

		matches.append({
			"cells": all_cells,
			"bonus_kind": bonus_kind,
			"bonus_pos": bonus_pos,
			"color": group_members[0]["color"]
		})

	return matches

func attempt_swap(a: Vector2i, b: Vector2i) -> bool:
	if is_busy:
		return false
	if not is_in_bounds(a) or not is_in_bounds(b):
		return false
	if absi(a.x - b.x) + absi(a.y - b.y) != 1:
		return false

	var bonus_a: String = bonuses[a.x][a.y]
	var bonus_b: String = bonuses[b.x][b.y]

	# Case 1: Combo of 2 Special Tiles
	if bonus_a != BONUS_NONE and bonus_b != BONUS_NONE:
		swap_committed.emit(a, b)
		_consume_move()
		is_busy = true
		_execute_special_combo(a, bonus_a, b, bonus_b)
		is_busy = false
		_check_game_over()
		return true

	# Case 2: Electro Ball + Color Tile
	if bonus_a == BONUS_ELECTRO_BALL and types[b.x][b.y] != EMPTY_TYPE:
		swap_committed.emit(a, b)
		_consume_move()
		is_busy = true
		_execute_electro_ball_color_swap(a, b)
		is_busy = false
		_check_game_over()
		return true
	elif bonus_b == BONUS_ELECTRO_BALL and types[a.x][a.y] != EMPTY_TYPE:
		swap_committed.emit(a, b)
		_consume_move()
		is_busy = true
		_execute_electro_ball_color_swap(b, a)
		is_busy = false
		_check_game_over()
		return true

	# Case 3: Swap Special Tile with Normal Color Tile
	if bonus_a != BONUS_NONE or bonus_b != BONUS_NONE:
		_swap_cells(a, b)
		var matches := find_matches(b)
		if not matches.is_empty():
			swap_committed.emit(a, b)
			_consume_move()
			is_busy = true
			_resolve_cascade(b)
			is_busy = false
			_check_game_over()
			return true
		else:
			# If swap makes no 3-color match, detonate the special tile at destination cell b
			var active_cell: Vector2i = b if bonus_a != BONUS_NONE else a
			swap_committed.emit(a, b)
			_consume_move()
			is_busy = true
			_detonate_single_special(active_cell)
			is_busy = false
			_check_game_over()
			return true

	# Case 4: Standard Color Swap
	_swap_cells(a, b)
	var matches := find_matches(b)
	if matches.is_empty():
		_swap_cells(a, b)
		swap_rejected.emit(a, b)
		return false

	swap_committed.emit(a, b)
	_consume_move()
	is_busy = true
	_resolve_cascade(b)
	is_busy = false
	_check_game_over()
	return true

func activate_special_tile(cell: Vector2i) -> bool:
	if is_busy or not is_in_bounds(cell):
		return false
	if bonuses[cell.x][cell.y] == BONUS_NONE:
		return false

	_consume_move()
	is_busy = true
	_detonate_single_special(cell)
	is_busy = false
	_check_game_over()
	return true

func _consume_move() -> void:
	moves_remaining -= 1
	move_consumed.emit(moves_remaining)

func _check_game_over() -> void:
	if score >= objective:
		level_completed.emit()
	elif moves_remaining <= 0:
		level_failed.emit()

func _swap_cells(a: Vector2i, b: Vector2i) -> void:
	var t: int = types[a.x][a.y]
	types[a.x][a.y] = types[b.x][b.y]
	types[b.x][b.y] = t

	var bo: String = bonuses[a.x][a.y]
	bonuses[a.x][a.y] = bonuses[b.x][b.y]
	bonuses[b.x][b.y] = bo

func _execute_special_combo(a: Vector2i, bonus_a: String, b: Vector2i, bonus_b: String) -> void:
	# Clear bonuses at a and b
	bonuses[a.x][a.y] = BONUS_NONE
	bonuses[b.x][b.y] = BONUS_NONE

	var cleared: Dictionary = {}
	cleared[a] = true
	cleared[b] = true

	var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var is_rocket_a := (bonus_a == BONUS_ROCKET_H or bonus_a == BONUS_ROCKET_V)
	var is_rocket_b := (bonus_b == BONUS_ROCKET_H or bonus_b == BONUS_ROCKET_V)

	if bonus_a == BONUS_ELECTRO_BALL and bonus_b == BONUS_ELECTRO_BALL:
		# Electro Ball + Electro Ball: Clear ENTIRE BOARD
		for x in width:
			for y in height:
				cleared[Vector2i(x, y)] = true
	elif bonus_a == BONUS_ELECTRO_BALL or bonus_b == BONUS_ELECTRO_BALL:
		var other_bonus := bonus_b if bonus_a == BONUS_ELECTRO_BALL else bonus_a
		var target_color := _find_most_common_color()
		if target_color != EMPTY_TYPE:
			for x in width:
				for y in height:
					if types[x][y] == target_color:
						bonuses[x][y] = other_bonus
						cleared[Vector2i(x, y)] = true
	elif is_rocket_a and is_rocket_b:
		# Rocket + Rocket: 1 full row + 1 full col
		for x in width:
			cleared[Vector2i(x, b.y)] = true
		for y in height:
			cleared[Vector2i(b.x, y)] = true
	elif (is_rocket_a and bonus_b == BONUS_BOMB) or (bonus_a == BONUS_BOMB and is_rocket_b):
		# Rocket + Bomb: 3 full rows + 3 full cols
		for dy in range(-1, 2):
			var ry: int = b.y + dy
			if ry >= 0 and ry < height:
				for x in width:
					cleared[Vector2i(x, ry)] = true
		for dx in range(-1, 2):
			var rx: int = b.x + dx
			if rx >= 0 and rx < width:
				for y in height:
					cleared[Vector2i(rx, y)] = true
	elif bonus_a == BONUS_BOMB and bonus_b == BONUS_BOMB:
		# Bomb + Bomb: 5x5 area centered at b
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				var c: Vector2i = Vector2i(b.x + dx, b.y + dy)
				if is_in_bounds(c):
					cleared[c] = true
	elif bonus_a == BONUS_SPINNER and bonus_b == BONUS_SPINNER:
		# Spinner + Spinner: 4 cross adjacent + 3 spinner targets
		for dir in dirs:
			var c: Vector2i = b + dir
			if is_in_bounds(c):
				cleared[c] = true
		var targets := _pick_random_targets(3, [b])
		for t in targets:
			cleared[t] = true
	elif (bonus_a == BONUS_SPINNER and is_rocket_b) or (is_rocket_a and bonus_b == BONUS_SPINNER):
		# Spinner + Rocket: Launch spinner to target, trigger Rocket cross at target
		for dir in dirs:
			var c: Vector2i = b + dir
			if is_in_bounds(c):
				cleared[c] = true
		var targets := _pick_random_targets(1, [b])
		if not targets.is_empty():
			var t: Vector2i = targets[0]
			for x in width:
				cleared[Vector2i(x, t.y)] = true
			for y in height:
				cleared[Vector2i(t.x, y)] = true
	elif (bonus_a == BONUS_SPINNER and bonus_b == BONUS_BOMB) or (bonus_a == BONUS_BOMB and bonus_b == BONUS_SPINNER):
		# Spinner + Bomb: Launch spinner to target, trigger 3x3 explosion at target
		for dir in dirs:
			var c: Vector2i = b + dir
			if is_in_bounds(c):
				cleared[c] = true
		var targets := _pick_random_targets(1, [b])
		if not targets.is_empty():
			var t: Vector2i = targets[0]
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var c: Vector2i = Vector2i(t.x + dx, t.y + dy)
					if is_in_bounds(c):
						cleared[c] = true

	_process_cleared_dict(cleared)

func _execute_electro_ball_color_swap(ball_cell: Vector2i, color_cell: Vector2i) -> void:
	var target_color: int = types[color_cell.x][color_cell.y]
	bonuses[ball_cell.x][ball_cell.y] = BONUS_NONE

	var cleared: Dictionary = {}
	cleared[ball_cell] = true
	for x in width:
		for y in height:
			if types[x][y] == target_color:
				cleared[Vector2i(x, y)] = true

	_process_cleared_dict(cleared)

func _detonate_single_special(cell: Vector2i) -> void:
	var cleared: Dictionary = {}
	cleared[cell] = true
	_process_cleared_dict(cleared)

func _process_cleared_dict(cleared: Dictionary) -> void:
	cleared = _expand_bonus_triggers(cleared)
	score += cleared.size() * POINTS_PER_TILE
	score_changed.emit(score)

	var cleared_cells: Array = cleared.keys()
	var falls := _apply_gravity(cleared_cells)
	var refills := _refill_empty_cells()

	cascade_step.emit({
		"matches": [],
		"cleared": cleared_cells,
		"bonuses": [],
		"falls": falls,
		"refills": refills,
	})

	_resolve_cascade()

func _resolve_cascade(swap_target: Vector2i = Vector2i(-1, -1)) -> void:
	var matches := find_matches(swap_target)
	while not matches.is_empty():
		var match_infos: Array = []
		var cleared: Dictionary = {}
		var bonus_spawns: Array = []

		for m in matches:
			var anchor: Vector2i = m["cells"][0]
			match_infos.append({
				"type": m["color"],
				"count": m["cells"].size(),
				"position": m["bonus_pos"] if m["bonus_kind"] != BONUS_NONE else anchor,
			})
			for cell in m["cells"]:
				cleared[cell] = true
			if m["bonus_kind"] != BONUS_NONE:
				bonus_spawns.append({"pos": m["bonus_pos"], "kind": m["bonus_kind"]})

		cleared = _expand_bonus_triggers(cleared)

		for spawn in bonus_spawns:
			cleared.erase(spawn["pos"])

		score += cleared.size() * POINTS_PER_TILE
		score_changed.emit(score)

		var cleared_cells: Array = cleared.keys()
		var falls := _apply_gravity(cleared_cells)
		var refills := _refill_empty_cells()

		for spawn in bonus_spawns:
			var final_pos: Vector2i = spawn["pos"]
			for f in falls:
				if f["from"] == spawn["pos"]:
					final_pos = f["to"]
					break
			bonuses[final_pos.x][final_pos.y] = spawn["kind"]
			spawn["pos"] = final_pos

		cascade_step.emit({
			"matches": match_infos,
			"cleared": cleared_cells,
			"bonuses": bonus_spawns,
			"falls": falls,
			"refills": refills,
		})

		# After first step, clear swap_target so subsequent cascade steps use natural spawn points
		swap_target = Vector2i(-1, -1)
		matches = find_matches()

	if not has_any_valid_move():
		reshuffle()
	cascade_finished.emit()

func _expand_bonus_triggers(cleared: Dictionary) -> Dictionary:
	var changed := true
	var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	while changed:
		changed = false
		for cell in cleared.keys():
			var kind: String = bonuses[cell.x][cell.y]
			if kind == BONUS_NONE:
				continue
			var extra: Array = []
			if kind == BONUS_ROCKET_H:
				for x in width:
					extra.append(Vector2i(x, cell.y))
			elif kind == BONUS_ROCKET_V:
				for y in height:
					extra.append(Vector2i(cell.x, y))
			elif kind == BONUS_BOMB:
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						var c: Vector2i = Vector2i(cell.x + dx, cell.y + dy)
						if is_in_bounds(c):
							extra.append(c)
			elif kind == BONUS_SPINNER:
				for dir in dirs:
					var c: Vector2i = cell + dir
					if is_in_bounds(c):
						extra.append(c)
				var targets := _pick_random_targets(1, [cell])
				extra.append_array(targets)
			elif kind == BONUS_ELECTRO_BALL:
				var most_common := _find_most_common_color()
				if most_common != EMPTY_TYPE:
					for x in width:
						for y in height:
							if types[x][y] == most_common:
								extra.append(Vector2i(x, y))

			for c in extra:
				if not cleared.has(c):
					cleared[c] = true
					changed = true
	return cleared

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
	var candidates: Array = []
	for x in width:
		for y in height:
			var c := Vector2i(x, y)
			if not exclude.has(c) and types[x][y] != EMPTY_TYPE:
				candidates.append(c)
	candidates.shuffle()
	return candidates.slice(0, count)

func _apply_gravity(cleared_cells: Array) -> Array:
	var falls: Array = []
	for cell in cleared_cells:
		types[cell.x][cell.y] = EMPTY_TYPE
		bonuses[cell.x][cell.y] = BONUS_NONE
	for x in width:
		var write_y := height - 1
		for y in range(height - 1, -1, -1):
			if types[x][y] == EMPTY_TYPE:
				continue
			if write_y != y:
				types[x][write_y] = types[x][y]
				bonuses[x][write_y] = bonuses[x][y]
				falls.append({"from": Vector2i(x, y), "to": Vector2i(x, write_y)})
			write_y -= 1
		for empty_y in range(write_y, -1, -1):
			types[x][empty_y] = EMPTY_TYPE
			bonuses[x][empty_y] = BONUS_NONE
	return falls

func _refill_empty_cells() -> Array:
	var refills: Array = []
	for x in width:
		for y in height:
			if types[x][y] == EMPTY_TYPE:
				var new_type := _rng.randi() % tile_type_count
				types[x][y] = new_type
				bonuses[x][y] = BONUS_NONE
				refills.append({"pos": Vector2i(x, y), "type": new_type})
	return refills

func has_any_valid_move() -> bool:
	for x in width:
		for y in height:
			var cell := Vector2i(x, y)
			# Any special tile can be tapped or swapped!
			if bonuses[x][y] != BONUS_NONE:
				return true
			if x + 1 < width and _would_swap_valid(cell, Vector2i(x + 1, y)):
				return true
			if y + 1 < height and _would_swap_valid(cell, Vector2i(x, y + 1)):
				return true
	return false

func _would_swap_valid(a: Vector2i, b: Vector2i) -> bool:
	if bonuses[a.x][a.y] != BONUS_NONE or bonuses[b.x][b.y] != BONUS_NONE:
		return true
	_swap_cells(a, b)
	var has_match := not find_matches().is_empty()
	_swap_cells(a, b)
	return has_match

func reshuffle() -> bool:
	var flat_types: Array = []
	for x in width:
		for y in height:
			flat_types.append(types[x][y])
	var attempts := 0
	while attempts < 100:
		flat_types.shuffle()
		var i := 0
		for x in width:
			for y in height:
				types[x][y] = flat_types[i]
				i += 1
		if find_matches().is_empty() and has_any_valid_move():
			board_reshuffled.emit()
			return true
		attempts += 1
	var fallback_attempts := 0
	while fallback_attempts < 1000:
		_fill_random_grid()
		if find_matches().is_empty() and has_any_valid_move():
			board_reshuffled.emit()
			return true
		fallback_attempts += 1
	push_warning("reshuffle() exhausted all attempts without reaching a valid board state")
	board_reshuffled.emit()
	return false
