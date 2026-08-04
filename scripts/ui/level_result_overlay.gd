class_name LevelResultOverlay
extends Control

signal restart_requested

@onready var _label: Label = $PanelContainer/VBoxContainer/ResultLabel
@onready var _restart_button: Button = $PanelContainer/VBoxContainer/RestartButton

func _ready() -> void:
	hide()
	_restart_button.pressed.connect(func(): restart_requested.emit())

func show_result(won: bool) -> void:
	_label.text = "Cleared!" if won else "Failed"
	show()
