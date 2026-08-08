# res://scripts/ui/game_board_scene_custom_test.gd
extends Node2D

@onready var _board_view: BoardView = $BoardView
@onready var _overlay: LevelResultOverlay = $LevelResultOverlay
@onready var _hud: GameHUD = $GameHUD
@onready var _status_label: Label = $TestControlCanvas/TestPanel/ControlsRow/StatusLabel

# CheckBox references
@onready var _box_check: CheckBox = $TestControlCanvas/TestPanel/GimmicksRow/BoxCheck
@onready var _snow_check: CheckBox = $TestControlCanvas/TestPanel/GimmicksRow/SnowCheck
@onready var _ivy_check: CheckBox = $TestControlCanvas/TestPanel/GimmicksRow/IvyCheck
@onready var _column_check: CheckBox = $TestControlCanvas/TestPanel/GimmicksRow/ColumnCheck
@onready var _birdhouse_check: CheckBox = $TestControlCanvas/TestPanel/GimmicksRow/BirdhouseCheck
@onready var _steam_bomb_check: CheckBox = $TestControlCanvas/TestPanel/GimmicksRow/SteamBombCheck
@onready var _dragon_box_check: CheckBox = $TestControlCanvas/TestPanel/GimmicksRow/DragonBoxCheck
@onready var _trophy_cabinet_check: CheckBox = $TestControlCanvas/TestPanel/GimmicksRow/TrophyCabinetCheck

var _top_cover: ColorRect
var _bottom_cover: ColorRect
var _test_level: LevelData

func _ready() -> void:
	if _status_label:
		_status_label.add_theme_font_size_override("font_size", 20)
	
	var panel = $TestControlCanvas/TestPanel
	if panel:
		_override_font_sizes_recursive(panel, 20)

	EventBus.level_completed.connect(func(_id, _stars): _overlay.show_result(true))
	EventBus.level_failed.connect(func(_id): _overlay.show_result(false))
	_overlay.restart_requested.connect(func(): GameManager.change_scene("res://scenes/screens/game_board_scene_custom_test.tscn"))
	
	if _hud:
		_hud.spawn_specials_requested.connect(func():
			if _board_view and _board_view.model:
				_board_view.model.spawn_random_special_items()
		)

	# Start with empty board test level first
	_setup_test_level([])
	_setup_covers()
	_board_view.start_level(_test_level)
	_center_board()
	_update_status("기믹을 선택하고 배치 버튼을 누르세요.")

func _override_font_sizes_recursive(node: Node, size: int) -> void:
	if node is Button or node is Label or node is CheckBox:
		node.add_theme_font_size_override("font_size", size)
	for child in node.get_children():
		_override_font_sizes_recursive(child, size)

func _setup_test_level(active_gimmicks: Array) -> void:
	_test_level = LevelData.new()
	_test_level.level_id = "test_custom_gimmicks"
	_test_level.grid_width = 8
	_test_level.grid_height = 8
	_test_level.move_limit = 40
	_test_level.tile_type_count = 5

	var initial_elems: Array = []
	var target_objs: Dictionary = {}

	if not active_gimmicks.is_empty():
		var column_x := -1
		if active_gimmicks.has("column"):
			var cols := [2, 3, 4, 5]
			cols.shuffle()
			column_x = cols[0]
			target_objs["column"] = 8
			for y in 8:
				initial_elems.append({
					"x": column_x,
					"y": y,
					"id": "column"
				})

		var all_cells: Array = []
		for x in 8:
			if x == column_x:
				continue
			for y in 8:
				all_cells.append(Vector2i(x, y))
		
		all_cells.shuffle()

		var current_idx := 0
		for gimmick_id in active_gimmicks:
			if gimmick_id == "column":
				continue
			if gimmick_id == "trophy_cabinet":
				target_objs["trophy_cabinet"] = 1
				for idx in range(all_cells.size()):
					var c: Vector2i = all_cells[idx]
					if c.x < 7 and c.y < 7 and c.x != column_x and (c.x + 1) != column_x:
						initial_elems.append({
							"x": c.x,
							"y": c.y,
							"id": "trophy_cabinet"
						})
						break
				continue

			target_objs[gimmick_id] = 4
			for i in 4:
				if current_idx < all_cells.size():
					var cell: Vector2i = all_cells[current_idx]
					initial_elems.append({
						"x": cell.x,
						"y": cell.y,
						"id": gimmick_id
					})
					current_idx += 1

	_test_level.initial_elements = initial_elems
	_test_level.target_objectives = target_objs

func _setup_covers() -> void:
	var bg_color: Color = RenderingServer.get_default_clear_color()
	
	_top_cover = ColorRect.new()
	_top_cover.color = bg_color
	_top_cover.z_index = 20
	add_child(_top_cover)
	
	_bottom_cover = ColorRect.new()
	_bottom_cover.color = bg_color
	_bottom_cover.z_index = 20
	add_child(_bottom_cover)
	
	if _board_view:
		move_child(_top_cover, _board_view.get_index() + 1)
		move_child(_bottom_cover, _board_view.get_index() + 2)

func _center_board() -> void:
	var board_size := Vector2(_test_level.grid_width, _test_level.grid_height) * BoardView.CELL_SIZE
	var viewport_size := get_viewport_rect().size
	# Move board slightly down to make space for the VBoxContainer (TestPanel)
	_board_view.position = ((viewport_size - board_size) / 2).round()
	_board_view.position.y += 60.0

	if _top_cover:
		_top_cover.position = Vector2.ZERO
		_top_cover.size = Vector2(viewport_size.x, _board_view.position.y)

	if _bottom_cover:
		var start_y: float = _board_view.position.y + board_size.y
		_bottom_cover.position = Vector2(0, start_y)
		_bottom_cover.size = Vector2(viewport_size.x, viewport_size.y - start_y)

func _on_deploy_pressed() -> void:
	var active_gimmicks := []
	if _box_check and _box_check.button_pressed: active_gimmicks.append("box")
	if _snow_check and _snow_check.button_pressed: active_gimmicks.append("snow")
	if _ivy_check and _ivy_check.button_pressed: active_gimmicks.append("ivy")
	if _column_check and _column_check.button_pressed: active_gimmicks.append("column")
	if _birdhouse_check and _birdhouse_check.button_pressed: active_gimmicks.append("birdhouse")
	if _steam_bomb_check and _steam_bomb_check.button_pressed: active_gimmicks.append("steam_bomb")
	if _dragon_box_check and _dragon_box_check.button_pressed: active_gimmicks.append("dragon_box")
	if _trophy_cabinet_check and _trophy_cabinet_check.button_pressed: active_gimmicks.append("trophy_cabinet")

	_setup_test_level(active_gimmicks)
	_board_view.start_level(_test_level)
	_center_board()

	if active_gimmicks.is_empty():
		_update_status("일반 블록 배치 완료! (선택된 기믹 없음)")
	else:
		_update_status("선택한 기믹 %d종(총 %d개) 배치 완료!" % [active_gimmicks.size(), _test_level.initial_elements.size()])

func _on_damage_all_pressed() -> void:
	if _board_view and _board_view.model:
		var damaged_count := 0
		var active_elems: Array = _board_view.model.elements_map.values().duplicate()
		for elem in active_elems:
			if is_instance_valid(elem) and elem.current_health > 0:
				elem.take_damage(1)
				damaged_count += 1
		_update_status("전체 기믹 %d개에 1 데미지 적용!" % damaged_count)

func _on_pass_turn_pressed() -> void:
	if _board_view and _board_view.model:
		var active_elems: Array = _board_view.model.elements_map.values().duplicate()
		for elem in active_elems:
			if is_instance_valid(elem) and elem.has_method("on_turn_passed"):
				elem.on_turn_passed()
		_update_status("1 턴 경과!")

func _on_restart_pressed() -> void:
	GameManager.change_scene("res://scenes/screens/game_board_scene_custom_test.tscn")

func _on_spawn_specials_pressed() -> void:
	if _board_view and _board_view.model:
		_board_view.model.spawn_random_special_items()
		_update_status("특수 아이템 랜덤 생성 완료!")

func _update_status(msg: String) -> void:
	if _status_label:
		_status_label.text = msg

func _on_copy_log_pressed() -> void:
	if not _board_view or not _board_view.model:
		_update_status("보드가 준비되지 않았습니다.")
		return
		
	var m = _board_view.model
	var lines: Array = []
	lines.append("=== ROYAL PUZZLE DEBUG BOARD STATE ===")
	lines.append("Board Size: %d x %d" % [m.width, m.height])
	lines.append("Objectives: %s" % str(m.target_objectives_remaining))
	lines.append("Moves: Remaining %d" % m.moves_remaining)
	lines.append("")
	
	# Integrity check: find cells that are EMPTY_TYPE but have no static gimmick (should not exist)
	var orphan_empties: Array = []
	for x in m.width:
		for y in m.height:
			if m.types[x][y] == m.EMPTY_TYPE:
				var cell := Vector2i(x, y)
				var has_static = m.elements_map.has(cell) and is_instance_valid(m.elements_map[cell]) and not m.elements_map[cell].allows_falling
				if not has_static:
					orphan_empties.append("(%d,%d)" % [x, y])
	if orphan_empties.is_empty():
		lines.append("✅ 보드 정합성: 이상 없음 (빈 셀 없음)")
	else:
		lines.append("⚠️ 보드 정합성 오류: 기믹 없이 빈 셀 %d개 발견: %s" % [orphan_empties.size(), ", ".join(orphan_empties)])
	lines.append("")
	
	lines.append("--- TILE TYPES GRID ---")
	var header := "   "
	for x in m.width:
		header += "%3d" % x
	lines.append(header)
	for y in m.height:
		var row_str := "%d |" % y
		for x in m.width:
			var t = m.types[x][y]
			var t_str = str(t)
			if t == m.EMPTY_TYPE:
				t_str = " X"
			row_str += "%3s" % t_str
		lines.append(row_str)
	lines.append("")
	
	lines.append("--- BONUSES GRID ---")
	lines.append(header)
	for y in m.height:
		var row_str := "%d |" % y
		for x in m.width:
			var b = m.bonuses[x][y]
			var b_str = " ."
			if b != m.BONUS_NONE:
				b_str = b.substr(0, 2).to_upper()
			row_str += "%3s" % b_str
		lines.append(row_str)
	lines.append("")
	
	lines.append("--- ELEMENTS MAP (GIMMICKS) ---")
	var has_elements := false
	for cell in m.elements_map.keys():
		var elem = m.elements_map[cell]
		if is_instance_valid(elem):
			has_elements = true
			var tile_type = m.types[cell.x][cell.y]
			var tile_type_str = str(tile_type) if tile_type != m.EMPTY_TYPE else "X(empty)"
			var bonus = m.bonuses[cell.x][cell.y]
			var bonus_str = bonus if bonus != m.BONUS_NONE else "none"
			lines.append("  - Cell %s: ID='%s', Health=%d/%d, tile_type=%s, bonus=%s, allows_falling=%s, allows_adjacent=%s" % [
				str(cell),
				elem.element_id,
				elem.current_health,
				elem.max_health,
				tile_type_str,
				bonus_str,
				str(elem.allows_falling),
				str(elem.allows_adjacent_damage)
			])
		elif elem != null:
			lines.append("  - Cell %s: INVALID INSTANCE (Freed but keys remain)" % str(cell))
			
	if not has_elements:
		lines.append("  No active elements on board.")
		
	# 4. Append Blackbox Histories for AI reproduction
	lines.append("")
	lines.append("=== BLACKBOX REPRODUCTION DATA ===")
	lines.append("--- INITIAL TILE TYPES GRID ---")
	if m.initial_types.size() > 0:
		for y in m.height:
			var row_str := ""
			for x in m.width:
				var t = m.initial_types[x][y]
				var t_str = str(t)
				if t == m.EMPTY_TYPE:
					t_str = " X"
				row_str += "%3s" % t_str
			lines.append(row_str)
	else:
		lines.append("  No initial types captured.")
	lines.append("")
	
	lines.append("--- INITIAL BONUSES GRID ---")
	if m.initial_bonuses.size() > 0:
		for y in m.height:
			var row_str := ""
			for x in m.width:
				var b = m.initial_bonuses[x][y]
				var b_str = " ."
				if b != m.BONUS_NONE:
					b_str = b.substr(0, 2).to_upper()
				row_str += "%3s" % b_str
			lines.append(row_str)
	else:
		lines.append("  No initial bonuses captured.")
	lines.append("")
	
	lines.append("--- INITIAL GIMMICKS ---")
	if m.initial_elements_list.size() > 0:
		for item in m.initial_elements_list:
			lines.append("  - Cell (%d,%d): ID='%s'" % [item.get("x", -1), item.get("y", -1), item.get("id", "")])
	else:
		lines.append("  No initial gimmicks spawned.")
	lines.append("")
	
	lines.append("--- ACTION HISTORY (SWAPS & TAPS) ---")
	if m.action_history.size() > 0:
		for action in m.action_history:
			lines.append("  " + action)
	else:
		lines.append("  No player actions recorded yet.")
	lines.append("")
	
	lines.append("--- RUNTIME EVENT LOG HISTORY ---")
	if m.log_history.size() > 0:
		for evt in m.log_history:
			lines.append("  " + evt)
	else:
		lines.append("  No runtime events logged yet.")
		
	var final_log = "\n".join(lines)
	DisplayServer.clipboard_set(final_log)
	_update_status("📋 보드 상태 로그가 클립보드에 복사되었습니다!")
