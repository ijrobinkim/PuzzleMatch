# res://scripts/resources/level_data.gd
class_name LevelData
extends Resource

@export var level_id: String = ""
@export var grid_width: int = 8
@export var grid_height: int = 8
@export var tile_type_count: int = 6
@export var move_limit: int = 20
@export var objective: int = 1000

# Royal Kingdom Level Extension
@export var target_objectives: Dictionary = {}
@export var initial_elements: Array = []

static func from_dictionary(dict: Dictionary) -> LevelData:
	var data := LevelData.new()
	data.level_id = dict.get("level_id", "")
	data.grid_width = int(dict.get("grid_width", 8))
	data.grid_height = int(dict.get("grid_height", 8))
	data.tile_type_count = int(dict.get("tile_type_count", 5))
	data.move_limit = int(dict.get("move_limit", 20))
	data.objective = int(dict.get("objective", 1000))
	data.target_objectives = dict.get("target_objectives", {}).duplicate(true)
	data.initial_elements = dict.get("initial_elements", []).duplicate(true)
	return data

func to_dictionary() -> Dictionary:
	return {
		"level_id": level_id,
		"grid_width": grid_width,
		"grid_height": grid_height,
		"tile_type_count": tile_type_count,
		"move_limit": move_limit,
		"objective": objective,
		"target_objectives": target_objectives.duplicate(true),
		"initial_elements": initial_elements.duplicate(true),
	}
