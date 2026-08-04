class_name BoardModel
extends RefCounted

const BONUS_NONE := ""
const BONUS_STRIPED_ROW := "striped_row"
const BONUS_STRIPED_COL := "striped_col"
const BONUS_BOMB := "bomb"
const EMPTY_TYPE := -1

var width: int
var height: int
var tile_type_count: int
var types: Array = []
var bonuses: Array = []
var moves_remaining: int
var score: int = 0
var objective: int
var is_busy: bool = false
var _rng := RandomNumberGenerator.new()

func _init(level_data: LevelData, rng_seed: int = -1) -> void:
	width = level_data.grid_width
	height = level_data.grid_height
	tile_type_count = level_data.tile_type_count
	moves_remaining = level_data.move_limit
	objective = level_data.objective
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	_fill_random_grid()

func _fill_random_grid() -> void:
	types.clear()
	bonuses.clear()
	for x in width:
		var col_types: Array = []
		var col_bonuses: Array = []
		for y in height:
			col_types.append(_rng.randi() % tile_type_count)
			col_bonuses.append(BONUS_NONE)
		types.append(col_types)
		bonuses.append(col_bonuses)

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height

func get_tile_type(cell: Vector2i) -> int:
	return types[cell.x][cell.y]

func get_bonus_kind(cell: Vector2i) -> String:
	return bonuses[cell.x][cell.y]
