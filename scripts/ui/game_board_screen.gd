extends Node2D

const BGM_STREAM: AudioStream = preload("res://assets/audio/bgm/bgm_royal_kingdom.wav")

@onready var _board_view: BoardView = $BoardView
@onready var _overlay: LevelResultOverlay = $LevelResultOverlay
@onready var _hud: GameHUD = $GameHUD

var _top_cover: ColorRect
var _bottom_cover: ColorRect

var current_stage_idx: int = 1
const MAX_STAGES: int = 30

var _pending_result: Dictionary = {}

func _ready() -> void:
	AudioManager.play_music(BGM_STREAM)
	EventBus.level_completed.connect(_on_level_completed)
	EventBus.level_failed.connect(_on_level_failed)

	if _board_view:
		_board_view.animations_finished.connect(_on_board_animations_finished)

	if _overlay:
		_overlay.restart_requested.connect(_on_restart_requested)
		if _overlay.has_signal("next_level_requested"):
			_overlay.next_level_requested.connect(_on_next_level_requested)
		if _overlay.has_signal("stage_start_finished"):
			_overlay.stage_start_finished.connect(_on_stage_start_finished)

	if _hud:
		_hud.spawn_specials_requested.connect(func():
			if _board_view and _board_view.model:
				_board_view.model.spawn_random_special_items()
		)
		if _hud.has_signal("restart_requested"):
			_hud.restart_requested.connect(_on_restart_requested)
		if _hud.has_signal("next_stage_requested"):
			_hud.next_stage_requested.connect(_on_next_level_requested)

	_setup_covers()
	_load_stage(1)

func _load_stage(stage_idx: int) -> void:
	_pending_result = {}
	current_stage_idx = clampi(stage_idx, 1, MAX_STAGES)
	var tres_path := "res://resources/levels/level_%03d.tres" % current_stage_idx
	var level_data: LevelData = load(tres_path) as LevelData

	if level_data == null:
		push_error("Failed to load stage resource: " + tres_path)
		return

	if _overlay:
		_overlay.visible = false

	if _hud and _hud.has_method("set_stage_info"):
		_hud.set_stage_info(current_stage_idx, MAX_STAGES)

	_board_view.start_level(level_data)
	_center_board(level_data)

	if _board_view and _board_view.has_method("set_input_locked"):
		_board_view.set_input_locked(true)

	if _overlay and _overlay.has_method("show_stage_start"):
		_overlay.show_stage_start(current_stage_idx)

func _on_level_completed(_id: String, _stars: int) -> void:
	if _board_view and _board_view.has_method("set_input_locked"):
		_board_view.set_input_locked(true)
	_pending_result = {"won": true}
	_try_show_pending_result()

func _on_level_failed(_id: String) -> void:
	if _board_view and _board_view.has_method("set_input_locked"):
		_board_view.set_input_locked(true)
	_pending_result = {"won": false}
	_try_show_pending_result()

func _on_board_animations_finished() -> void:
	_try_show_pending_result()

func _on_stage_start_finished() -> void:
	if _board_view and _board_view.has_method("set_input_locked"):
		_board_view.set_input_locked(false)

func _try_show_pending_result() -> void:
	if _pending_result.is_empty():
		return
	if _board_view and _board_view.has_method("is_animating") and _board_view.is_animating():
		return

	var won: bool = _pending_result["won"]
	_pending_result = {}
	var is_final: bool = won and (current_stage_idx >= MAX_STAGES)

	if _overlay:
		if _overlay.has_method("show_result_stage"):
			_overlay.show_result_stage(won, current_stage_idx, is_final)
		else:
			_overlay.show_result(won)

func _on_next_level_requested() -> void:
	if current_stage_idx < MAX_STAGES:
		_load_stage(current_stage_idx + 1)
	else:
		_load_stage(1)

func _on_restart_requested() -> void:
	_load_stage(current_stage_idx)

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

func _center_board(level_data: LevelData) -> void:
	var board_size := Vector2(level_data.grid_width, level_data.grid_height) * BoardView.CELL_SIZE
	var viewport_size := get_viewport_rect().size
	_board_view.position = ((viewport_size - board_size) / 2).round()

	if _top_cover:
		_top_cover.position = Vector2.ZERO
		_top_cover.size = Vector2(viewport_size.x, _board_view.position.y)

	if _bottom_cover:
		var start_y: float = _board_view.position.y + board_size.y
		_bottom_cover.position = Vector2(0, start_y)
		_bottom_cover.size = Vector2(viewport_size.x, viewport_size.y - start_y)
