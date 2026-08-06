# res://scripts/screens/element_test_demo.gd
extends Node2D

@onready var container: Node2D = $ElementContainer
@onready var status_label: Label = $CanvasLayer/StatusLabel

var elements: Array = []

func _ready() -> void:
	_setup_demo_elements()

func _setup_demo_elements() -> void:
	for child in container.get_children():
		child.queue_free()
	elements.clear()

	var factory = ElementFactory.new()
	var ids: Array[String] = ["box", "snow", "ivy", "column", "birdhouse", "steam_bomb", "dragon_box"]
	
	var spacing := 140.0
	var start_x := 100.0
	var start_y := 300.0

	for i in ids.size():
		var elem_id: String = ids[i]
		var elem: BaseElement = factory.create_element(elem_id)
		if elem:
			elem.position = Vector2(start_x + i * spacing, start_y)
			container.add_child(elem)
			elements.append(elem)

	_update_status("로열 킹덤 기믹 7종 데모 배치 완료! (상자, 눈, 담쟁이, 기둥, 새집, 증기폭발, 드래곤둥지)")

func _on_damage_all_pressed() -> void:
	for elem in elements:
		if is_instance_valid(elem) and elem.current_health > 0:
			elem.take_damage(1)
	_update_status("전체 기믹에 1 데미지 적용!")

func _on_pass_turn_pressed() -> void:
	for elem in elements:
		if is_instance_valid(elem) and elem.has_method("on_turn_passed"):
			elem.on_turn_passed()
	_update_status("1 턴 경과 (증기폭탄 카운트다운 감소)!")

func _update_status(msg: String) -> void:
	if status_label:
		status_label.text = msg
