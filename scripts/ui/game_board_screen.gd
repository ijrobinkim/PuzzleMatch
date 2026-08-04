extends Node2D

const LEVEL_001: LevelData = preload("res://resources/levels/level_001.tres")

@onready var _board_view: BoardView = $BoardView
@onready var _overlay: LevelResultOverlay = $LevelResultOverlay

func _ready() -> void:
	EventBus.level_completed.connect(func(_id, _stars): _overlay.show_result(true))
	EventBus.level_failed.connect(func(_id): _overlay.show_result(false))
	_overlay.restart_requested.connect(func(): GameManager.change_scene("res://scenes/screens/game_board_screen.tscn"))
	_board_view.start_level(LEVEL_001)
	_center_board()

func _center_board() -> void:
	var board_size := Vector2(LEVEL_001.grid_width, LEVEL_001.grid_height) * BoardView.CELL_SIZE
	var viewport_size := get_viewport_rect().size
	_board_view.position = ((viewport_size - board_size) / 2).round()
