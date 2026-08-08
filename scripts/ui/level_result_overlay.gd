class_name LevelResultOverlay
extends CanvasLayer

signal restart_requested
signal next_level_requested
signal stage_start_finished

@onready var _dim: ColorRect = get_node_or_null("Dim")
@onready var _label: Label = $PanelContainer/VBoxContainer/ResultLabel
@onready var _restart_button: Button = $PanelContainer/VBoxContainer/RestartButton
@onready var _next_button: Button = get_node_or_null("PanelContainer/VBoxContainer/NextButton")

const KOREAN_FONT: Font = preload("res://assets/fonts/malgun.ttf")
const AUTO_ADVANCE_DELAY: float = 2.5
const STAGE_START_DELAY: float = 2.5

var _auto_advance_timer: Timer
var _stage_start_timer: Timer

func _ready() -> void:
	visible = false
	_setup_buttons()

func _setup_buttons() -> void:
	if _restart_button:
		_restart_button.add_theme_font_override("font", KOREAN_FONT)
		_restart_button.add_theme_font_size_override("font_size", 22)
		_restart_button.text = "🔄 다시하기"
		if not _restart_button.pressed.is_connected(_on_restart_pressed):
			_restart_button.pressed.connect(_on_restart_pressed)

	if _next_button == null:
		var parent_vbox = get_node_or_null("PanelContainer/VBoxContainer")
		if parent_vbox:
			_next_button = Button.new()
			_next_button.name = "NextButton"
			_next_button.add_theme_font_override("font", KOREAN_FONT)
			_next_button.add_theme_font_size_override("font_size", 22)
			_next_button.text = "▶️ 다음 스테이지"
			parent_vbox.add_child(_next_button)

	if _next_button and not _next_button.pressed.is_connected(_on_next_pressed):
		_next_button.pressed.connect(_on_next_pressed)

	if _auto_advance_timer == null:
		_auto_advance_timer = Timer.new()
		_auto_advance_timer.one_shot = true
		_auto_advance_timer.wait_time = AUTO_ADVANCE_DELAY
		add_child(_auto_advance_timer)
		_auto_advance_timer.timeout.connect(_on_next_pressed)

	if _stage_start_timer == null:
		_stage_start_timer = Timer.new()
		_stage_start_timer.one_shot = true
		_stage_start_timer.wait_time = STAGE_START_DELAY
		add_child(_stage_start_timer)
		_stage_start_timer.timeout.connect(_on_stage_start_timeout)

func _on_restart_pressed() -> void:
	_auto_advance_timer.stop()
	visible = false
	restart_requested.emit()

func _on_next_pressed() -> void:
	_auto_advance_timer.stop()
	visible = false
	next_level_requested.emit()

func _on_stage_start_timeout() -> void:
	visible = false
	stage_start_finished.emit()

func show_result(won: bool) -> void:
	show_result_stage(won, 1, false)

func show_result_stage(won: bool, stage_idx: int = 1, is_final: bool = false) -> void:
	_setup_buttons()
	_auto_advance_timer.stop()
	_stage_start_timer.stop()

	if _dim:
		_dim.color = Color(0, 0, 0, 0.55)

	if _restart_button:
		_restart_button.visible = true

	if _label:
		_label.add_theme_font_override("font", KOREAN_FONT)
		_label.add_theme_font_size_override("font_size", 26)
		if won:
			if is_final:
				_label.text = "🎉 축하합니다!\n모든 30개 스테이지 클리어! 🏆"
			else:
				_label.text = "🎯 미션 완료!\nSTAGE %d 클리어!" % stage_idx
		else:
			_label.text = "😢 STAGE %d 실패" % stage_idx

	if _next_button:
		_next_button.visible = won and not is_final

	visible = true

	if won and not is_final:
		_auto_advance_timer.start()

func show_stage_start(stage_idx: int) -> void:
	_setup_buttons()
	_auto_advance_timer.stop()
	_stage_start_timer.stop()

	if _dim:
		_dim.color = Color(0, 0, 0, 0.35)

	if _restart_button:
		_restart_button.visible = false
	if _next_button:
		_next_button.visible = false

	if _label:
		_label.add_theme_font_override("font", KOREAN_FONT)
		_label.add_theme_font_size_override("font_size", 30)
		_label.text = "🚩 STAGE %d 시작!" % stage_idx

	visible = true
	_stage_start_timer.start()
