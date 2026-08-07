extends Node2D

const LEVEL_001: LevelData = preload("res://resources/levels/level_001.tres")

@onready var _board_view: BoardView = $BoardView
@onready var _overlay: LevelResultOverlay = $LevelResultOverlay
@onready var _hud: GameHUD = $GameHUD

var _top_cover: ColorRect
var _bottom_cover: ColorRect

func _ready() -> void:
	EventBus.level_completed.connect(func(_id, _stars): _overlay.show_result(true))
	EventBus.level_failed.connect(func(_id): _overlay.show_result(false))
	_overlay.restart_requested.connect(func(): GameManager.change_scene("res://scenes/screens/game_board_screen.tscn"))
	if _hud:
		_hud.spawn_specials_requested.connect(func():
			if _board_view and _board_view.model:
				_board_view.model.spawn_random_special_items()
		)
	_setup_covers()
	_board_view.start_level(LEVEL_001)
	_center_board()

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
	var board_size := Vector2(LEVEL_001.grid_width, LEVEL_001.grid_height) * BoardView.CELL_SIZE
	var viewport_size := get_viewport_rect().size
	_board_view.position = ((viewport_size - board_size) / 2).round()

	if _top_cover:
		_top_cover.position = Vector2.ZERO
		_top_cover.size = Vector2(viewport_size.x, _board_view.position.y)

	if _bottom_cover:
		var start_y: float = _board_view.position.y + board_size.y
		_bottom_cover.position = Vector2(0, start_y)
		_bottom_cover.size = Vector2(viewport_size.x, viewport_size.y - start_y)
