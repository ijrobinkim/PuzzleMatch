# res://scripts/ui/game_board_screen_test.gd
extends Node2D

@onready var _board_view: BoardView = $BoardView
@onready var _overlay: LevelResultOverlay = $LevelResultOverlay
@onready var _hud: GameHUD = $GameHUD
@onready var _status_label: Label = $TestControlCanvas/TestPanel/StatusLabel

var _top_cover: ColorRect
var _bottom_cover: ColorRect
var _test_level: LevelData

func _ready() -> void:
	if _status_label:
		_status_label.add_theme_font_size_override("font_size", 32)
	
	var panel = $TestControlCanvas/TestPanel
	if panel:
		for child in panel.get_children():
			if child is Button:
				child.add_theme_font_size_override("font_size", 32)
	EventBus.level_completed.connect(func(_id, _stars): _overlay.show_result(true))
	EventBus.level_failed.connect(func(_id): _overlay.show_result(false))
	_overlay.restart_requested.connect(func(): GameManager.change_scene("res://scenes/screens/game_board_screen_test.tscn"))
	
	if _hud:
		_hud.spawn_specials_requested.connect(func():
			if _board_view and _board_view.model:
				_board_view.model.spawn_random_special_items()
		)

	_setup_test_level()
	_setup_covers()
	_board_view.start_level(_test_level)
	_center_board()
	_update_status("상자 반절(24개) 배치 레벨 테스트 준비 완료!")

func _setup_test_level() -> void:
	_test_level = LevelData.new()
	_test_level.level_id = "test_boxes_half"
	_test_level.grid_width = 8
	_test_level.grid_height = 8
	_test_level.move_limit = 30
	_test_level.tile_type_count = 5
	_test_level.target_objectives = {"box": 24}

	var initial_elems: Array = []
	for x in 8:
		for y in 4:
			if x == 3 or x == 4:
				continue
			initial_elems.append({
				"x": x,
				"y": y,
				"id": "box"
			})
	_test_level.initial_elements = initial_elems

func _setup_covers() -> void:
	var bg_color: Color = RenderingServer.get_default_clear_color()
	
	_top_cover = ColorRect.new()
	_top_cover.color = bg_color
	_top_cover.z_index = 1
	add_child(_top_cover)
	
	_bottom_cover = ColorRect.new()
	_bottom_cover.color = bg_color
	_bottom_cover.z_index = 1
	add_child(_bottom_cover)
	
	if _board_view:
		move_child(_top_cover, _board_view.get_index() + 1)
		move_child(_bottom_cover, _board_view.get_index() + 2)

func _center_board() -> void:
	var board_size := Vector2(_test_level.grid_width, _test_level.grid_height) * BoardView.CELL_SIZE
	var viewport_size := get_viewport_rect().size
	_board_view.position = ((viewport_size - board_size) / 2).round()

	if _top_cover:
		_top_cover.position = Vector2.ZERO
		_top_cover.size = Vector2(viewport_size.x, _board_view.position.y)

	if _bottom_cover:
		var start_y: float = _board_view.position.y + board_size.y
		_bottom_cover.position = Vector2(0, start_y)
		_bottom_cover.size = Vector2(viewport_size.x, viewport_size.y - start_y)

func _on_damage_boxes_pressed() -> void:
	if _board_view and _board_view.model:
		var damaged_count := 0
		var active_elems: Array = _board_view.model.elements_map.values().duplicate()
		for elem in active_elems:
			if is_instance_valid(elem) and elem.element_id == "box" and elem.current_health > 0:
				elem.take_damage(1)
				damaged_count += 1
		_update_status("전체 상자 %d개에 1 데미지 적용!" % damaged_count)

func _on_pass_turn_pressed() -> void:
	if _board_view and _board_view.model:
		var active_elems: Array = _board_view.model.elements_map.values().duplicate()
		for elem in active_elems:
			if is_instance_valid(elem) and elem.has_method("on_turn_passed"):
				elem.on_turn_passed()
		_update_status("1 턴 경과!")

func _on_restart_pressed() -> void:
	GameManager.change_scene("res://scenes/screens/game_board_screen_test.tscn")

func _on_spawn_specials_pressed() -> void:
	if _board_view and _board_view.model:
		_board_view.model.spawn_random_special_items()
		_update_status("특수 아이템 랜덤 생성 완료!")

func _update_status(msg: String) -> void:
	if _status_label:
		_status_label.text = msg
