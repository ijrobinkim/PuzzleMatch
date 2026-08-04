class_name Tile
extends Node2D

@onready var sprite: Sprite2D = $Sprite
@onready var bonus_overlay: Sprite2D = $BonusOverlay

var cell: Vector2i
var tile_type: int = -1

func setup(p_cell: Vector2i, p_type: int, bonus_kind: String, cell_size: float) -> void:
	cell = p_cell
	tile_type = p_type
	position = Vector2(cell.x, cell.y) * cell_size
	sprite.frame = max(0, p_type)
	bonus_overlay.rotation_degrees = 0.0
	bonus_overlay.modulate = Color.WHITE
	bonus_overlay.scale = Vector2.ONE

	match bonus_kind:
		BoardModel.BONUS_NONE:
			bonus_overlay.visible = false
		BoardModel.BONUS_BOMB:
			bonus_overlay.visible = true
			bonus_overlay.frame = 1
		BoardModel.BONUS_ROCKET_H:
			bonus_overlay.visible = true
			bonus_overlay.frame = 0
			bonus_overlay.rotation_degrees = 0.0
		BoardModel.BONUS_ROCKET_V:
			bonus_overlay.visible = true
			bonus_overlay.frame = 0
			bonus_overlay.rotation_degrees = 90.0
		BoardModel.BONUS_SPINNER:
			bonus_overlay.visible = true
			bonus_overlay.frame = 1
			bonus_overlay.rotation_degrees = 45.0
			bonus_overlay.scale = Vector2(0.85, 0.85)
		BoardModel.BONUS_ELECTRO_BALL:
			bonus_overlay.visible = true
			bonus_overlay.frame = 1
			bonus_overlay.modulate = Color(1.0, 0.85, 0.2)

func reset() -> void:
	tile_type = -1
	bonus_overlay.visible = false
	bonus_overlay.rotation_degrees = 0.0
	bonus_overlay.modulate = Color.WHITE
	bonus_overlay.scale = Vector2.ONE
	scale = Vector2.ONE
	modulate = Color.WHITE

func animate_move_to(target_cell: Vector2i, cell_size: float, duration: float = 0.2) -> void:
	cell = target_cell
	var tween := create_tween()
	tween.tween_property(self, "position", Vector2(target_cell.x, target_cell.y) * cell_size, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func animate_clear(duration: float = 0.15) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

func animate_spawn(duration: float = 0.15) -> void:
	scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
