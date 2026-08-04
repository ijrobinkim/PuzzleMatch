extends Node
## Game state, versioning and scene transitions.

const GAME_VERSION := "0.0.1.6"

signal scene_changed(scene_path: String)
signal game_paused(is_paused: bool)

var current_level_id: String = ""
var is_paused: bool = false


func change_scene(path: String) -> void:
	scene_changed.emit(path)
	get_tree().change_scene_to_file(path)


func set_paused(paused: bool) -> void:
	is_paused = paused
	get_tree().paused = paused
	game_paused.emit(paused)


func quit_game() -> void:
	get_tree().quit()
