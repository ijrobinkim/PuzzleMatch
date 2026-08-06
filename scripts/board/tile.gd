class_name Tile
extends Node2D

var visual: Node2D
var sprite: Sprite2D
var bonus_overlay: Sprite2D

var cell: Vector2i
var tile_type: int = -1
var bonus_kind: String = ""
var _active_tween: Tween

func stop_animations() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		_active_tween = null

func _ensure_nodes() -> void:
	if visual == null:
		visual = get_node_or_null("Visual")
	if sprite == null:
		sprite = get_node_or_null("Visual/Sprite") if visual else get_node_or_null("Sprite")
	if bonus_overlay == null:
		bonus_overlay = get_node_or_null("Visual/BonusOverlay") if visual else get_node_or_null("BonusOverlay")

static var _icon_cache: Dictionary = {}

static func _get_icon(path: String) -> Texture2D:
	if _icon_cache.has(path):
		return _icon_cache[path]
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			_icon_cache[path] = res
			return res
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img:
			var tex := ImageTexture.create_from_image(img)
			_icon_cache[path] = tex
			return tex
	return null

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
	stop_animations()
	_ensure_nodes()
	cell = p_cell
	tile_type = p_type
	self.bonus_kind = bonus_kind
	position = Vector2(cell.x, cell.y) * cell_size
	if sprite:
		sprite.frame = max(0, p_type)
	if bonus_overlay:
		bonus_overlay.rotation_degrees = 0.0
		bonus_overlay.modulate = Color.WHITE
		bonus_overlay.scale = Vector2.ONE
		bonus_overlay.hframes = 1
		bonus_overlay.vframes = 1
		bonus_overlay.frame = 0
		bonus_overlay.centered = true
		bonus_overlay.position = Vector2.ZERO
	rotation_degrees = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE
	if visual:
		visual.scale = Vector2.ONE
		visual.rotation_degrees = 0.0

	if bonus_overlay == null:
		return

	var icon_path := ""
	match bonus_kind:
		BoardModel.BONUS_NONE:
			bonus_overlay.visible = false
		BoardModel.BONUS_BOMB:
			icon_path = "res://assets/sprites/board/item_bomb.png"
		BoardModel.BONUS_ROCKET_H:
			icon_path = "res://assets/sprites/board/item_rocket_h.png"
		BoardModel.BONUS_ROCKET_V:
			icon_path = "res://assets/sprites/board/item_rocket_v.png"
		BoardModel.BONUS_SPINNER:
			icon_path = "res://assets/sprites/board/item_spinner.png"
		BoardModel.BONUS_ELECTRO_BALL:
			icon_path = "res://assets/sprites/board/item_electro_ball.png"

	if icon_path != "":
		var tex := _get_icon(icon_path)
		if tex:
			if sprite:
				sprite.visible = false
			bonus_overlay.visible = true
			bonus_overlay.texture = tex
			bonus_overlay.region_enabled = false
			bonus_overlay.hframes = 1
			bonus_overlay.vframes = 1
			bonus_overlay.frame = 0
			bonus_overlay.scale = Vector2(0.80, 0.80)
			bonus_overlay.position = Vector2.ZERO
		else:
			if sprite:
				sprite.visible = true
			bonus_overlay.visible = true
			bonus_overlay.region_enabled = true
	else:
		if sprite:
			sprite.visible = true
		bonus_overlay.visible = false

func reset() -> void:
	stop_animations()
	_ensure_nodes()
	tile_type = -1
	bonus_kind = ""
	if sprite:
		sprite.visible = true
	if bonus_overlay:
		bonus_overlay.visible = false
		bonus_overlay.rotation_degrees = 0.0
		bonus_overlay.modulate = Color.WHITE
		bonus_overlay.scale = Vector2.ONE
	rotation_degrees = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE
	if visual:
		visual.scale = Vector2.ONE
		visual.rotation_degrees = 0.0

func animate_move_to(target_cell: Vector2i, cell_size: float, duration: float = 0.48) -> Tween:
	stop_animations()
	cell = target_cell
	var target_pos := Vector2(target_cell.x, target_cell.y) * cell_size
	if not is_inside_tree():
		position = target_pos
		return null
	var tween := create_tween()
	if tween == null:
		position = target_pos
		return null
	_active_tween = tween
	tween.tween_property(self, "position", target_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tween

func animate_clear(duration: float = 0.35) -> Tween:
	stop_animations()
	_ensure_nodes()
	_spawn_break_particles()
	if not is_inside_tree():
		if visual: visual.scale = Vector2.ZERO
		return null
	var tween := create_tween()
	if tween == null:
		if visual: visual.scale = Vector2.ZERO
		return null
	_active_tween = tween
	tween.set_parallel(true)
	if visual:
		tween.tween_property(visual, "scale", Vector2(1.28, 1.28), duration * 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color(2.0, 2.0, 2.0, 1.0), duration * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if visual:
		tween.chain().tween_property(visual, "scale", Vector2.ZERO, duration * 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, duration * 0.65)
	return tween

func animate_spawn(duration: float = 0.42) -> Tween:
	stop_animations()
	_ensure_nodes()
	if not is_inside_tree():
		if visual: visual.scale = Vector2.ONE
		return null
	if visual: visual.scale = Vector2.ZERO
	var tween := create_tween()
	if tween == null:
		if visual: visual.scale = Vector2.ONE
		return null
	_active_tween = tween
	if visual:
		tween.tween_property(visual, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween

func animate_converge_to(target_cell: Vector2i, cell_size: float, duration: float = 0.32) -> Tween:
	stop_animations()
	_ensure_nodes()
	var target_pos := Vector2(target_cell.x, target_cell.y) * cell_size
	if not is_inside_tree():
		position = target_pos
		return null
	var tween := create_tween()
	if tween == null:
		position = target_pos
		return null
	_active_tween = tween
	tween.set_parallel(true)
	tween.tween_property(self, "position", target_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if visual:
		tween.tween_property(visual, "scale", Vector2(0.15, 0.15), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.2, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return tween

func animate_gather_target(duration: float = 0.32) -> Tween:
	stop_animations()
	_ensure_nodes()
	if not is_inside_tree():
		if visual: visual.scale = Vector2.ONE
		return null
	var tween := create_tween()
	if tween == null:
		if visual: visual.scale = Vector2.ONE
		return null
	_active_tween = tween
	if visual:
		tween.tween_property(visual, "scale", Vector2(0.82, 0.82), duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(visual, "scale", Vector2.ONE, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tween

func animate_item_transform(bonus_kind: String, duration: float = 0.35) -> Tween:
	stop_animations()
	_ensure_nodes()
	_spawn_item_creation_particles(bonus_kind)
	if not is_inside_tree():
		if visual: visual.scale = Vector2.ONE
		modulate = Color.WHITE
		return null
	if visual: visual.scale = Vector2(0.4, 0.4)
	modulate = Color(1.8, 1.8, 1.8, 1.0)
	var tween := create_tween()
	if tween == null:
		if visual: visual.scale = Vector2.ONE
		modulate = Color.WHITE
		return null
	_active_tween = tween
	tween.set_parallel(true)
	if visual:
		tween.tween_property(visual, "scale", Vector2(1.35, 1.35), duration * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(visual, "scale", Vector2.ONE, duration * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "modulate", Color.WHITE, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tween

func animate_hint_nudge(dir: Vector2, cell_size: float) -> Tween:
	stop_animations()
	_ensure_nodes()
	if not is_inside_tree():
		return null
	var tween := create_tween()
	if tween == null:
		return null
	_active_tween = tween
	var base_pos := Vector2(cell.x, cell.y) * cell_size
	var target_pos := base_pos + dir.normalized() * (cell_size * 0.22)
	tween.set_parallel(true)
	tween.tween_property(self, "position", target_pos, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if visual:
		tween.tween_property(visual, "scale", Vector2(1.15, 1.15), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color(1.6, 1.5, 1.1), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.chain().tween_property(self, "position", base_pos, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if visual:
		tween.chain().tween_property(visual, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_property(self, "modulate", Color.WHITE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return tween

func animate_hint_pulse() -> Tween:
	stop_animations()
	_ensure_nodes()
	if not is_inside_tree():
		return null
	var tween := create_tween()
	if tween == null:
		return null
	_active_tween = tween
	tween.set_parallel(true)
	if visual:
		tween.tween_property(visual, "scale", Vector2(1.22, 1.22), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color(1.7, 1.5, 1.1), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if visual:
		tween.chain().tween_property(visual, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(self, "modulate", Color.WHITE, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return tween

func animate_hint_match_pulse() -> Tween:
	stop_animations()
	_ensure_nodes()
	if not is_inside_tree():
		return null
	var tween := create_tween()
	if tween == null:
		return null
	_active_tween = tween
	tween.set_parallel(true)
	if visual:
		tween.tween_property(visual, "scale", Vector2(1.08, 1.08), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color(1.4, 1.4, 1.4), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if visual:
		tween.chain().tween_property(visual, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_property(self, "modulate", Color.WHITE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return tween

func animate_hint() -> Tween:
	return animate_hint_pulse()

func stop_hint(cell_size: float = 128.0) -> void:
	stop_animations()
	if cell != Vector2i(-1, -1):
		position = Vector2(cell.x, cell.y) * cell_size
	scale = Vector2.ONE
	rotation_degrees = 0.0
	modulate = Color.WHITE
	if visual:
		visual.scale = Vector2.ONE
		visual.rotation_degrees = 0.0

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
	particles.position = Vector2(64.0, 64.0)

	add_child(particles)
	particles.emitting = true

	var timer := get_tree().create_timer(0.6)
	timer.timeout.connect(func(): if is_instance_valid(particles): particles.queue_free())

func _spawn_item_creation_particles(bonus_kind: String) -> void:
	var particles := CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 24
	particles.lifetime = 0.5
	particles.explosiveness = 0.9
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 140.0
	particles.initial_velocity_max = 280.0
	particles.scale_amount_min = 5.0
	particles.scale_amount_max = 10.0
	particles.color = _get_bonus_particle_color(bonus_kind)
	particles.position = Vector2(64.0, 64.0)

	add_child(particles)
	particles.emitting = true

	var timer := get_tree().create_timer(0.7)
	timer.timeout.connect(func(): if is_instance_valid(particles): particles.queue_free())

func _get_bonus_particle_color(bonus_kind: String) -> Color:
	match bonus_kind:
		BoardModel.BONUS_BOMB:
			return Color(1.0, 0.45, 0.15)
		BoardModel.BONUS_ROCKET_H, BoardModel.BONUS_ROCKET_V:
			return Color(0.35, 0.85, 1.0)
		BoardModel.BONUS_SPINNER:
			return Color(0.95, 0.35, 0.95)
		BoardModel.BONUS_ELECTRO_BALL:
			return Color(1.0, 0.92, 0.25)
		_:
			return Color(1.0, 1.0, 0.8)
