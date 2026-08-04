class_name BoardModel
extends RefCounted

const BONUS_NONE := ""
const BONUS_STRIPED_ROW := "striped_row"
const BONUS_STRIPED_COL := "striped_col"
const BONUS_BOMB := "bomb"
const EMPTY_TYPE := -1

signal swap_rejected(a: Vector2i, b: Vector2i)
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

func find_matches() -> Array:
	var runs: Array = []
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
					runs.append({"cells": cells, "dir": "h", "length": length})
				run_start = x
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
					runs.append({"cells": cells, "dir": "v", "length": length})
				run_start = y

	if runs.is_empty():
		return []

	var parent: Array = []
	for i in runs.size():
		parent.append(i)

	var find_root := func(start_i: int) -> int:
		var i := start_i
		while parent[i] != i:
			i = parent[i]
		return i

	for i in runs.size():
		for j in range(i + 1, runs.size()):
			var shares := false
			for cell in runs[i]["cells"]:
				if runs[j]["cells"].has(cell):
					shares = true
					break
			if shares:
				var ri: int = find_root.call(i)
				var rj: int = find_root.call(j)
				if ri != rj:
					parent[ri] = rj

	var groups_by_root: Dictionary = {}
	for i in runs.size():
		var root: int = find_root.call(i)
		if not groups_by_root.has(root):
			groups_by_root[root] = []
		groups_by_root[root].append(runs[i])

	var matches: Array = []
	for root in groups_by_root.keys():
		var member_runs: Array = groups_by_root[root]
		var all_cells: Array = []
		var has_h := false
		var has_v := false
		var max_len := 0
		var longest_run: Dictionary = member_runs[0]
		for run in member_runs:
			if run["dir"] == "h":
				has_h = true
			else:
				has_v = true
			if run["length"] > max_len:
				max_len = run["length"]
				longest_run = run
			for cell in run["cells"]:
				if not all_cells.has(cell):
					all_cells.append(cell)

		var bonus_kind := BONUS_NONE
		var bonus_pos: Vector2i = longest_run["cells"][int(longest_run["cells"].size() / 2)]

		if max_len >= 5 or (has_h and has_v):
			bonus_kind = BONUS_BOMB
			if has_h and has_v:
				for run_a in member_runs:
					if run_a["dir"] != "h":
						continue
					for run_b in member_runs:
						if run_b["dir"] != "v":
							continue
						for cell in run_a["cells"]:
							if run_b["cells"].has(cell):
								bonus_pos = cell
		elif max_len == 4:
			bonus_kind = BONUS_STRIPED_ROW if longest_run["dir"] == "h" else BONUS_STRIPED_COL

		matches.append({"cells": all_cells, "bonus_kind": bonus_kind, "bonus_pos": bonus_pos})

	return matches

func attempt_swap(a: Vector2i, b: Vector2i) -> bool:
	if is_busy:
		return false
	if not is_in_bounds(a) or not is_in_bounds(b):
		return false
	if absi(a.x - b.x) + absi(a.y - b.y) != 1:
		return false
	_swap_cells(a, b)
	if find_matches().is_empty():
		_swap_cells(a, b)
		swap_rejected.emit(a, b)
		return false
	moves_remaining -= 1
	move_consumed.emit(moves_remaining)
	is_busy = true
	_resolve_cascade()
	is_busy = false
	if score >= objective:
		level_completed.emit()
	elif moves_remaining <= 0:
		level_failed.emit()
	return true

func _swap_cells(a: Vector2i, b: Vector2i) -> void:
	var t: int = types[a.x][a.y]
	types[a.x][a.y] = types[b.x][b.y]
	types[b.x][b.y] = t
	var bo: String = bonuses[a.x][a.y]
	bonuses[a.x][a.y] = bonuses[b.x][b.y]
	bonuses[b.x][b.y] = bo

func _resolve_cascade() -> void:
	var matches := find_matches()
	while not matches.is_empty():
		for m in matches:
			for cell in m["cells"]:
				types[cell.x][cell.y] = EMPTY_TYPE
				bonuses[cell.x][cell.y] = BONUS_NONE
		matches = find_matches()
	cascade_finished.emit()
