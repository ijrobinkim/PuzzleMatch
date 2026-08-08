class_name GameHUD
extends CanvasLayer

signal restart_requested
signal spawn_specials_requested

const KOREAN_FONT: Font = preload("res://assets/fonts/malgun.ttf")

@onready var version_label: Label = $TopCenter/VersionPanel/VersionLabel
@onready var scroll_container: ScrollContainer = $BottomFull/LogPanel/MarginContainer/ScrollContainer
@onready var log_vbox: VBoxContainer = $BottomFull/LogPanel/MarginContainer/ScrollContainer/LogVBox
@onready var restart_button: Button = get_node_or_null("TopRight/RestartButton")
@onready var spawn_specials_button: Button = get_node_or_null("TopRight/SpawnSpecialsButton")

var speed_button: Button
var current_speed_step := 0 # 0: 1.0x, 1: 1.5x, 2: 2.0x
const SPEED_STEPS: Array[float] = [1.0, 1.5, 2.0]

const MAX_LOG_LINES := 50

func _ready() -> void:
	if version_label:
		version_label.add_theme_font_override("font", KOREAN_FONT)
		version_label.text = "v" + GameManager.GAME_VERSION
	_setup_restart_button()
	_setup_spawn_specials_button()
	_setup_speed_button()
	EventBus.log_emitted.connect(_on_log_emitted)
	_add_log_line("🎮 게임 시작! (버전 v" + GameManager.GAME_VERSION + ")")

func _setup_restart_button() -> void:
	if restart_button == null:
		return
	restart_button.add_theme_font_override("font", KOREAN_FONT)
	restart_button.add_theme_font_size_override("font_size", 18)
	restart_button.text = "🔄 새로시작"
	
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.12, 0.12, 0.18, 0.88)
	style_normal.border_color = Color(1.0, 0.8, 0.25, 0.95)
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(10)
	style_normal.shadow_color = Color(0, 0, 0, 0.4)
	style_normal.shadow_size = 4
	
	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = Color(0.25, 0.2, 0.08, 0.95)
	style_hover.border_color = Color(1.0, 0.9, 0.4, 1.0)
	style_hover.set_border_width_all(2)
	style_hover.set_corner_radius_all(10)
	style_hover.shadow_color = Color(1.0, 0.8, 0.2, 0.4)
	style_hover.shadow_size = 6

	var style_pressed := StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.4, 0.3, 0.05, 0.95)
	style_pressed.border_color = Color(1.0, 0.95, 0.6, 1.0)
	style_pressed.set_border_width_all(2)
	style_pressed.set_corner_radius_all(10)

	restart_button.add_theme_stylebox_override("normal", style_normal)
	restart_button.add_theme_stylebox_override("hover", style_hover)
	restart_button.add_theme_stylebox_override("pressed", style_pressed)
	restart_button.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	restart_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))

	if not restart_button.pressed.is_connected(_on_restart_button_pressed):
		restart_button.pressed.connect(_on_restart_button_pressed)

func _setup_spawn_specials_button() -> void:
	if spawn_specials_button == null:
		return
	spawn_specials_button.add_theme_font_override("font", KOREAN_FONT)
	spawn_specials_button.add_theme_font_size_override("font_size", 16)
	spawn_specials_button.text = "🎁 아이템 랜덤 배치"

	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.1, 0.2, 0.25, 0.88)
	style_normal.border_color = Color(0.3, 0.85, 1.0, 0.95)
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(10)
	style_normal.shadow_color = Color(0, 0, 0, 0.4)
	style_normal.shadow_size = 4

	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = Color(0.15, 0.3, 0.4, 0.95)
	style_hover.border_color = Color(0.5, 0.95, 1.0, 1.0)
	style_hover.set_border_width_all(2)
	style_hover.set_corner_radius_all(10)

	spawn_specials_button.add_theme_stylebox_override("normal", style_normal)
	spawn_specials_button.add_theme_stylebox_override("hover", style_hover)
	spawn_specials_button.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))

	if not spawn_specials_button.pressed.is_connected(_on_spawn_specials_button_pressed):
		spawn_specials_button.pressed.connect(_on_spawn_specials_button_pressed)

func _setup_speed_button() -> void:
	speed_button = get_node_or_null("TopRight/SpeedButton")
	if speed_button == null:
		speed_button = Button.new()
		speed_button.name = "SpeedButton"
		var top_right := get_node_or_null("TopRight")
		if top_right:
			top_right.add_child(speed_button)
		else:
			add_child(speed_button)

	speed_button.add_theme_font_override("font", KOREAN_FONT)
	speed_button.add_theme_font_size_override("font_size", 16)
	speed_button.custom_minimum_size = Vector2(160, 42)
	
	# Force Default Speed to 2단계 (1.5x) on game startup
	if not GameManager.default_speed_initialized:
		GameManager.default_speed_initialized = true
		current_speed_step = 1
		Engine.time_scale = 1.5
	else:
		var current_scale := Engine.time_scale
		if is_equal_approx(current_scale, 1.0):
			current_speed_step = 0
		elif is_equal_approx(current_scale, 2.0):
			current_speed_step = 2
		else:
			current_speed_step = 1

	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.12, 0.22, 0.12, 0.88)
	style_normal.border_color = Color(0.4, 0.9, 0.4, 0.95)
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(10)
	style_normal.shadow_color = Color(0, 0, 0, 0.4)
	style_normal.shadow_size = 4

	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = Color(0.2, 0.4, 0.2, 0.95)
	style_hover.border_color = Color(0.6, 1.0, 0.6, 1.0)
	style_hover.set_border_width_all(2)
	style_hover.set_corner_radius_all(10)

	speed_button.add_theme_stylebox_override("normal", style_normal)
	speed_button.add_theme_stylebox_override("hover", style_hover)
	speed_button.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))

	if not speed_button.pressed.is_connected(_on_speed_button_pressed):
		speed_button.pressed.connect(_on_speed_button_pressed)

	_update_speed_button_ui()

func _on_speed_button_pressed() -> void:
	current_speed_step = (current_speed_step + 1) % SPEED_STEPS.size()
	var new_speed: float = SPEED_STEPS[current_speed_step]
	Engine.time_scale = new_speed
	_update_speed_button_ui()
	_add_log_line("⚡ 게임 배속 변경: %.1fx (1단계:1.0x -> 2단계:1.5x -> 3단계:2.0x)" % new_speed)

func _update_speed_button_ui() -> void:
	if speed_button:
		var speed_val: float = SPEED_STEPS[current_speed_step]
		speed_button.text = "⚡ 배속: %.1fx" % speed_val

func _on_spawn_specials_button_pressed() -> void:
	spawn_specials_requested.emit()

func _on_restart_button_pressed() -> void:
	restart_requested.emit()
	GameManager.change_scene("res://scenes/screens/game_board_screen.tscn")

func _on_log_emitted(message: String, category: String) -> void:
	_add_log_line(message, category)

func _add_log_line(text: String, category: String = "") -> void:
	if log_vbox == null:
		return
	var label := Label.new()
	label.add_theme_font_override("font", KOREAN_FONT)
	label.add_theme_font_size_override("font_size", 24)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if text.begins_with("[에러]") or category == "error":
		label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	elif text.begins_with("[아이템"):
		label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	elif text.begins_with("[매치]"):
		label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))

	label.text = text
	log_vbox.add_child(label)

	while log_vbox.get_child_count() > MAX_LOG_LINES:
		var child := log_vbox.get_child(0)
		log_vbox.remove_child(child)
		child.queue_free()

	await get_tree().process_frame
	if is_instance_valid(scroll_container):
		var v_bar := scroll_container.get_v_scroll_bar()
		if v_bar:
			scroll_container.scroll_vertical = int(v_bar.max_value)
