extends Node2D

const LEVEL_001: LevelData = preload("res://resources/levels/level_001.tres")

@onready var _board_view: BoardView = $BoardView
@onready var _overlay: LevelResultOverlay = $LevelResultOverlay

func _ready() -> void:
	EventBus.level_completed.connect(func(_id, _stars): _overlay.show_result(true))
	EventBus.level_failed.connect(func(_id): _overlay.show_result(false))
	_overlay.restart_requested.connect(func(): GameManager.change_scene("res://scenes/screens/game_board_screen.tscn"))
	_board_view.start_level(LEVEL_001)
