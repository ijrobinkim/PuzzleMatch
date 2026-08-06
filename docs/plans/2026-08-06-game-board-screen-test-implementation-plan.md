# GameBoardScreenTest Implementation Plan

> **For Antigravity:** REQUIRED WORKFLOW: Use `.agent/workflows/execute-plan.md` to execute this plan in single-flow mode.

**Goal:** Create `game_board_screen_test` (scene, script, and unit test) pre-filling the top half (32 cells) of an 8x8 match-3 board with `box` obstacle elements and providing interactive test controls for game mechanics verification.

**Architecture:** Build `game_board_screen_test.tscn` and `game_board_screen_test.gd` based on `game_board_screen`. Programmatically instantiate a `LevelData` object with 8x8 grid, top 4 rows filled with `box` elements, set `target_objectives` to 32 boxes, and add a CanvasLayer test UI panel with interactive action buttons (Damage All Boxes, Pass Turn, Restart, Spawn Specials).

**Tech Stack:** Godot 4.x GDScript, GUT Unit Test Framework.

---

### Task 1: Create GameBoardScreenTest Unit Test (TDD RED)

**Files:**
- Create: `tests/unit/test_game_board_screen_test.gd`

**Step 1: Write the failing test**

```gdscript
# tests/unit/test_game_board_screen_test.gd
extends GutTest

func test_game_board_screen_test_instantiation_and_box_setup():
	var scene: PackedScene = load("res://scenes/screens/game_board_screen_test.tscn")
	assert_not_null(scene, "game_board_screen_test.tscn scene should exist")
	var screen = scene.instantiate()
	assert_not_null(screen, "screen instance should be created")
	add_child(screen)
	
	# Verify board view & model
	assert_not_null(screen._board_view, "board_view node should exist")
	assert_not_null(screen._board_view.model, "board model should be initialized")
	
	# Verify top half (y=0..3) filled with boxes (32 boxes total)
	var box_count := 0
	for x in 8:
		for y in 4:
			var cell := Vector2i(x, y)
			var elem = screen._board_view.model.get_element(cell)
			if elem != null and elem.element_id == "box":
				box_count += 1
	assert_eq(box_count, 32, "Top 4 rows (32 cells) should be pre-filled with box elements")
	
	# Verify target objectives
	assert_eq(screen._board_view.model.target_objectives.get("box", 0), 32, "Box objective target should be 32")
	
	screen.free()
```

**Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=tests/unit/test_game_board_screen_test.gd`
Expected: FAIL (scene `res://scenes/screens/game_board_screen_test.tscn` not found)

**Step 3: Commit**

```bash
git add tests/unit/test_game_board_screen_test.gd
git commit -m "test: add failing test for GameBoardScreenTest instantiation and box setup"
```

---

### Task 2: Create GameBoardScreenTest Controller Script and Scene (TDD GREEN)

**Files:**
- Create: `scripts/ui/game_board_screen_test.gd`
- Create: `scenes/screens/game_board_screen_test.tscn`

**Step 1: Write script implementation**

```gdscript
# res://scripts/ui/game_board_screen_test.gd
extends Node2D

@onready var _board_view: BoardView = $BoardView
@onready var _overlay: LevelResultOverlay = $LevelResultOverlay
@onready var _hud: GameHUD = $GameHUD
@onready var _status_label: Label = $TestControlCanvas/TestPanel/StatusLabel

var _top_cover: ColorRect
var _bottom_cover: ColorRect
var _test_level: LevelData

func _ready() -> void:
	EventBus.level_completed.connect(func(_id, _stars): _overlay.show_result(true))
	EventBus.level_failed.connect(func(_id): _overlay.show_result(false))
	_overlay.restart_requested.connect(func(): GameManager.change_scene("res://scenes/screens/game_board_screen_test.tscn"))
	
	if _hud:
		_hud.spawn_specials_requested.connect(func():
			if _board_view and _board_view.model:
				_board_view.model.spawn_random_special_items()
		)

	_setup_test_level()
	_setup_covers()
	_board_view.start_level(_test_level)
	_center_board()
	_update_status("상자 반절(32개) 배치 레벨 테스트 준비 완료!")

func _setup_test_level() -> void:
	_test_level = LevelData.new()
	_test_level.level_id = "test_boxes_half"
	_test_level.grid_width = 8
	_test_level.grid_height = 8
	_test_level.move_limit = 30
	_test_level.tile_type_count = 5
	_test_level.target_objectives = {"box": 32}

	var initial_elems: Array = []
	for x in 8:
		for y in 4:
			initial_elems.append({
				"x": x,
				"y": y,
				"id": "box"
			})
	_test_level.initial_elements = initial_elems

func _setup_covers() -> void:
	var bg_color: Color = RenderingServer.get_default_clear_color()
	
	_top_cover = ColorRect.new()
	_top_cover.color = bg_color
	_top_cover.z_index = 1
	add_child(_top_cover)
	
	_bottom_cover = ColorRect.new()
	_bottom_cover.color = bg_color
	_bottom_cover.z_index = 1
	add_child(_bottom_cover)
	
	if _board_view:
		move_child(_top_cover, _board_view.get_index() + 1)
		move_child(_bottom_cover, _board_view.get_index() + 2)

func _center_board() -> void:
	var board_size := Vector2(_test_level.grid_width, _test_level.grid_height) * BoardView.CELL_SIZE
	var viewport_size := get_viewport_rect().size
	_board_view.position = ((viewport_size - board_size) / 2).round()

	if _top_cover:
		_top_cover.position = Vector2.ZERO
		_top_cover.size = Vector2(viewport_size.x, _board_view.position.y)

	if _bottom_cover:
		var start_y: float = _board_view.position.y + board_size.y
		_bottom_cover.position = Vector2(0, start_y)
		_bottom_cover.size = Vector2(viewport_size.x, viewport_size.y - start_y)

func _on_damage_boxes_pressed() -> void:
	if _board_view and _board_view.model:
		var damaged_count := 0
		var active_elems: Array = _board_view.model.elements_map.values().duplicate()
		for elem in active_elems:
			if is_instance_valid(elem) and elem.element_id == "box":
				_board_view.model.damage_element_at(elem.grid_position, 1)
				damaged_count += 1
		_update_status("전체 상자 %d개에 1 데미지 적용!" % damaged_count)

func _on_pass_turn_pressed() -> void:
	if _board_view and _board_view.model:
		_board_view.model._on_turn_passed()
		_update_status("1 턴 경과!")

func _on_restart_pressed() -> void:
	GameManager.change_scene("res://scenes/screens/game_board_screen_test.tscn")

func _on_spawn_specials_pressed() -> void:
	if _board_view and _board_view.model:
		_board_view.model.spawn_random_special_items()
		_update_status("특수 아이템 랜덤 생성 완료!")

func _update_status(msg: String) -> void:
	if _status_label:
		_status_label.text = msg
```

**Step 2: Create scene file (`scenes/screens/game_board_screen_test.tscn`)**

```tscn
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/ui/game_board_screen_test.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/board/board_view.tscn" id="2"]
[ext_resource type="PackedScene" path="res://scenes/ui/level_result_overlay.tscn" id="3"]
[ext_resource type="PackedScene" path="res://scenes/ui/game_hud.tscn" id="4"]

[node name="GameBoardScreenTest" type="Node2D"]
script = ExtResource("1")

[node name="BoardView" parent="." instance=ExtResource("2")]

[node name="GameHUD" parent="." instance=ExtResource("4")]

[node name="LevelResultOverlay" parent="." instance=ExtResource("3")]

[node name="TestControlCanvas" type="CanvasLayer" parent="."]
layer = 10

[node name="TestPanel" type="HBoxContainer" parent="TestControlCanvas"]
offset_left = 20.0
offset_top = 20.0
offset_right = 1260.0
offset_bottom = 70.0
theme_override_constants/separation = 12

[node name="DamageButton" type="Button" parent="TestControlCanvas/TestPanel"]
layout_mode = 2
text = "💥 상자 전체 피격"

[node name="TurnButton" type="Button" parent="TestControlCanvas/TestPanel"]
layout_mode = 2
text = "⏳ 1턴 경과"

[node name="SpecialsButton" type="Button" parent="TestControlCanvas/TestPanel"]
layout_mode = 2
text = "💣 특수 아이템 생성"

[node name="RestartButton" type="Button" parent="TestControlCanvas/TestPanel"]
layout_mode = 2
text = "🔄 레벨 리셋"

[node name="StatusLabel" type="Label" parent="TestControlCanvas/TestPanel"]
layout_mode = 2
size_flags_horizontal = 3
text = "상자 테스트 레벨 준비 중..."

[connection signal="pressed" from="TestControlCanvas/TestPanel/DamageButton" to="." method="_on_damage_boxes_pressed"]
[connection signal="pressed" from="TestControlCanvas/TestPanel/TurnButton" to="." method="_on_pass_turn_pressed"]
[connection signal="pressed" from="TestControlCanvas/TestPanel/SpecialsButton" to="." method="_on_spawn_specials_pressed"]
[connection signal="pressed" from="TestControlCanvas/TestPanel/RestartButton" to="." method="_on_restart_pressed"]
```

**Step 3: Run test to verify it passes**

Run unit test to confirm `test_game_board_screen_test_instantiation_and_box_setup` passes.

**Step 4: Commit**

```bash
git add scripts/ui/game_board_screen_test.gd scenes/screens/game_board_screen_test.tscn tests/unit/test_game_board_screen_test.gd
git commit -m "feat: add GameBoardScreenTest with 32 top-half box elements and interactive test panel"
```

---

### Execution Handoff

Plan complete and saved to `docs/plans/2026-08-06-game-board-screen-test-implementation-plan.md`.
Next step: run `.agent/workflows/execute-plan.md` to execute this plan task-by-task in single-flow mode.
