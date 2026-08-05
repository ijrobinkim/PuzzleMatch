import re

with open('e:\\1111_WORK\\000000_Project\\RoyalPuzzle\\scripts\\board\\board_model.gd', 'r', encoding='utf-8') as f:
    code = f.read()

# 1. Update activate_special_tile
code = code.replace("""	log_event.emit("[아이템 사용] %s (%d,%d) 터치 발동!" % [get_bonus_name(kind), cell.x, cell.y])
	_consume_move()
	is_busy = true
	_detonate_single_special(cell)
	is_busy = false
	_check_game_over()
	return true""", """	log_event.emit("[아이템 사용] %s (%d,%d) 터치 발동!" % [get_bonus_name(kind), cell.x, cell.y])
	_consume_move()
	_do_activate_special_tile(cell)
	return true""")

# 2. Add _do_activate_special_tile
code = code.replace("func activate_special_tile(cell: Vector2i) -> bool:", """func _do_activate_special_tile(cell: Vector2i) -> void:
	is_busy = true
	var cleared: Dictionary = {}
	cleared[cell] = true
	await _run_cascade_async(Vector2i(-1,-1), Vector2i(-1,-1), cleared)
	is_busy = false
	_check_game_over()

func activate_special_tile(cell: Vector2i) -> bool:""")

# 3. Update attempt_swap cases
# Case 3
code = code.replace("""			is_busy = true
			_resolve_cascade(b, special_cell)
			is_busy = false""", """			_do_attempt_swap_cascade(b, special_cell)""")

code = code.replace("""			is_busy = true
			_detonate_single_special(active_cell)
			is_busy = false""", """			_do_attempt_swap_cascade(Vector2i(-1,-1), active_cell)""")

# Case 4
code = code.replace("""	is_busy = true
	_resolve_cascade(b)
	is_busy = false
	_check_game_over()""", """	_do_attempt_swap_cascade(b, Vector2i(-1,-1))""")

# Case 2
code = code.replace("""		is_busy = true
		_execute_electro_ball_color_swap(a, b)
		is_busy = false
		_check_game_over()""", """		_do_electro_ball(a, b)""")

code = code.replace("""		is_busy = true
		_execute_electro_ball_color_swap(b, a)
		is_busy = false
		_check_game_over()""", """		_do_electro_ball(b, a)""")

code = code.replace("func _execute_electro_ball_color_swap", """func _do_attempt_swap_cascade(swap_target: Vector2i, extra_trigger: Vector2i) -> void:
	is_busy = true
	await _run_cascade_async(swap_target, extra_trigger)
	is_busy = false
	_check_game_over()

func _do_electro_ball(ball: Vector2i, color_cell: Vector2i) -> void:
	is_busy = true
	await _execute_electro_ball_color_swap(ball, color_cell)
	is_busy = false
	_check_game_over()

func _execute_electro_ball_color_swap""")

# Update _execute_electro_ball_color_swap to await _run_cascade_async
code = code.replace("""func _execute_electro_ball_color_swap(ball_cell: Vector2i, color_cell: Vector2i) -> void:
	var target_color: int = types[color_cell.x][color_cell.y]
	bonuses[ball_cell.x][ball_cell.y] = BONUS_NONE

	var cleared: Dictionary = {}
	cleared[ball_cell] = true
	for x in width:
		for y in height:
			if types[x][y] == target_color:
				cleared[Vector2i(x, y)] = true

	_process_cleared_dict(cleared)""", """func _execute_electro_ball_color_swap(ball_cell: Vector2i, color_cell: Vector2i) -> void:
	var target_color: int = types[color_cell.x][color_cell.y]
	bonuses[ball_cell.x][ball_cell.y] = BONUS_NONE

	var cleared: Dictionary = {}
	cleared[ball_cell] = true
	for x in width:
		for y in height:
			if types[x][y] == target_color:
				cleared[Vector2i(x, y)] = true

	await _run_cascade_async(Vector2i(-1,-1), Vector2i(-1,-1), cleared)""")

# Add _run_cascade_async at the end and REMOVE the old _process_cleared_dict, _resolve_cascade, _detonate_single_special
# We will just append _run_cascade_async and then use regex to delete the old functions.

async_func = '''
func _run_cascade_async(swap_target: Vector2i = Vector2i(-1, -1), extra_trigger_cell: Vector2i = Vector2i(-1, -1), initial_cleared: Dictionary = {}, extra_spinners: Array = [], extra_rockets: Array = []) -> void:
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

		for m in matches:
			var anchor: Vector2i = m["cells"][0]
			match_infos.append({
				"type": m["color"],
				"count": m["cells"].size(),
				"position": m["bonus_pos"] if m["bonus_kind"] != BONUS_NONE else anchor,
			})
			for cell in m["cells"]:
				current_cleared[cell] = true
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

		if not current_cleared.is_empty():
			var expand_res := _expand_bonus_triggers(current_cleared)
			current_cleared = expand_res[0]
			pending_spinners.append_array(expand_res[1])
			pending_rockets.append_array(expand_res[2])

			for spawn in bonus_spawns:
				current_cleared.erase(spawn["spawn_pos"])

			var gained := current_cleared.size() * POINTS_PER_TILE
			score += gained
			score_changed.emit(score)
			log_event.emit("[점수] +%d점 (총 %d점)" % [gained, score])

			var cleared_cells: Array = current_cleared.keys()
			var falls := _apply_gravity(cleared_cells)
			var refills := _refill_empty_cells()

			for spawn in bonus_spawns:
				var final_pos: Vector2i = spawn["spawn_pos"]
				for f in falls:
					if f["from"] == spawn["spawn_pos"]:
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
				"spinners": pending_spinners.duplicate(),
				"rockets": pending_rockets.duplicate(),
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
			await Engine.get_main_loop().create_timer(0.48).timeout
			for sp in delayed_impacts:
				var area: Array = sp.get("impact_area", [sp.get("target", Vector2i(-1, -1))])
				for c in area:
					if c != Vector2i(-1, -1):
						current_cleared[c] = true
			
			for c in current_cleared.keys():
				if is_in_bounds(c):
					bonuses[c.x][c.y] = BONUS_NONE
			
			has_more_work = true
	
	if not has_any_valid_move():
		reshuffle()
	cascade_finished.emit()
'''

code += "\\n" + async_func

with open('e:\\1111_WORK\\000000_Project\\RoyalPuzzle\\scripts\\board\\board_model.gd', 'w', encoding='utf-8') as f:
    f.write(code)

print("Updates applied")
