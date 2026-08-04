class_name GameHUD
extends CanvasLayer

const KOREAN_FONT: Font = preload("res://assets/fonts/malgun.ttf")

@onready var version_label: Label = $TopCenter/VersionPanel/VersionLabel
@onready var scroll_container: ScrollContainer = $BottomFull/LogPanel/MarginContainer/ScrollContainer
@onready var log_vbox: VBoxContainer = $BottomFull/LogPanel/MarginContainer/ScrollContainer/LogVBox

const MAX_LOG_LINES := 50

func _ready() -> void:
	if version_label:
		version_label.add_theme_font_override("font", KOREAN_FONT)
		version_label.text = "v" + GameManager.GAME_VERSION
	EventBus.log_emitted.connect(_on_log_emitted)
	_add_log_line("🎮 게임 시작! (버전 v" + GameManager.GAME_VERSION + ")")

func _on_log_emitted(message: String, category: String) -> void:
	_add_log_line(message, category)

func _add_log_line(text: String, category: String = "") -> void:
	if log_vbox == null:
		return
	var label := Label.new()
	label.add_theme_font_override("font", KOREAN_FONT)
	label.add_theme_font_size_override("font_size", 18)
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
