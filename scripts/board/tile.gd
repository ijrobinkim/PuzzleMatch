class_name Tile
extends Node2D

@onready var sprite: Sprite2D = $Sprite
@onready var bonus_overlay: Sprite2D = $BonusOverlay

var cell: Vector2i
var tile_type: int = -1

static func get_tile_color(type: int) -> Color:
	match type:
		0: return Color(1.0, 0.3, 0.3)
		1: return Color(0.3, 0.6, 1.0)
		2: return Color(0.3, 0.9, 0.4)
		3: return Color(1.0, 0.9, 0.2)
		4: return Color(0.8, 0.3, 0.9)
		5: return Color(1.0, 0.55, 0.2)
		_: return Color.WHITE

func setup(p_cell: Vector2i, p_type: int, bonus_kind: String, cell_size: float) -> void:
	cell = p_cell
	tile_type = p_type
	position = Vector2(cell.x, cell.y) * cell_size
	sprite.frame = max(0, p_type)
	bonus_overlay.rotation_degrees = 0.0
	bonus_overlay.modulate = Color.WHITE
	bonus_overlay.scale = Vector2.ONE
	rotation_degrees = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE

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
	rotation_degrees = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE

func animate_move_to(target_cell: Vector2i, cell_size: float, duration: float = 0.48) -> Tween:
	cell = target_cell
	var tween := create_tween()
	tween.tween_property(self, "position", Vector2(target_cell.x, target_cell.y) * cell_size, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tween

func animate_clear(duration: float = 0.35) -> Tween:
	_spawn_break_particles()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), duration * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(self, "scale", Vector2.ZERO, duration * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "rotation_degrees", randf_range(-30.0, 30.0), duration)
	tween.tween_property(self, "modulate:a", 0.0, duration)
	return tween

func animate_spawn(duration: float = 0.42) -> Tween:
	scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween

func _spawn_break_particles() -> void:
	var particles := CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 12
	particles.lifetime = 0.45
	particles.explosiveness = 0.95
	particles.spread = 180.0
	particles.gravity = Vector2(0, 500)
	particles.initial_velocity_min = 120.0
	particles.initial_velocity_max = 240.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 8.0
	particles.color = get_tile_color(tile_type)
	particles.position = sprite.position + Vector2(64.0, 64.0)

	add_child(particles)
	particles.emitting = true

	var timer := get_tree().create_timer(0.6)
	timer.timeout.connect(func(): if is_instance_valid(particles): particles.queue_free())
