# Royal Kingdom Level Feature Implementation Plan

> **For Antigravity:** REQUIRED WORKFLOW: Use `.agent/workflows/execute-plan.md` to execute this plan in single-flow mode.

**Goal:** Implement Royal Kingdom style level element framework and core level progression elements in Godot 4 (`RoyalPuzzle`).

**Architecture:** Create an extensible Node2D base class (`BaseElement`) with signals for damage/destruction, subclassed by `LayeredElement`, `SpreaderElement`, and `SpawnerElement`. Manage level level-layouts with `LevelData` Resource definitions.

**Tech Stack:** Godot 4.x (GDScript), GUT (Godot Unit Testing framework).

---

### Task 1: Create `BaseElement` and `LayeredElement` Core Classes

**Files:**
- Create: `scripts/elements/base_element.gd`
- Create: `scripts/elements/layered_element.gd`
- Test: `tests/unit/test_base_element.gd`

**Step 1: Write failing unit test for `BaseElement`**

```gdscript
# tests/unit/test_base_element.gd
extends GutTest

func test_base_element_damage_and_destruction():
	var element = load("res://scripts/elements/base_element.gd").new()
	element.max_health = 2
	element._ready()
	
	watch_signals(element)
	element.take_damage(1)
	assert_signal_emitted(element, "element_damaged")
	assert_eq(element.current_health, 1)
	
	element.take_damage(1)
	assert_signal_emitted(element, "element_destroyed")
	element.free()
```

**Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=tests/unit/test_base_element.gd`  
Expected: FAIL (File or class not found)

**Step 3: Write minimal implementation for `BaseElement`**

```gdscript
# res://scripts/elements/base_element.gd
class_name BaseElement
extends Node2D

signal element_damaged(element, current_health)
signal element_destroyed(element)

@export var element_id: String = ""
@export var max_health: int = 1
@export var is_obstacle: bool = true
@export var allows_falling: bool = false

var current_health: int = 1
var grid_position: Vector2i = Vector2i.ZERO

func _ready() -> void:
	current_health = max_health

func take_damage(amount: int = 1) -> void:
	current_health -= amount
	element_damaged.emit(self, current_health)
	if current_health <= 0:
		destroy()

func destroy() -> void:
	element_destroyed.emit(self)
	queue_free()
```

**Step 4: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=tests/unit/test_base_element.gd`  
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/elements/base_element.gd tests/unit/test_base_element.gd
git commit -m "feat: add BaseElement class and damage signals"
```

---

### Task 2: Create `LevelData` Resource and Element Registry

**Files:**
- Create: `scripts/resources/level_data.gd`
- Create: `scripts/managers/element_factory.gd`
- Test: `tests/unit/test_level_data.gd`

**Step 1: Write failing test for `LevelData`**

```gdscript
# tests/unit/test_level_data.gd
extends GutTest

func test_level_data_initialization():
	var level = load("res://scripts/resources/level_data.gd").new()
	level.level_id = 1
	level.max_moves = 20
	assert_eq(level.level_id, 1)
	assert_eq(level.max_moves, 20)
```

**Step 2: Run test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=tests/unit/test_level_data.gd`  
Expected: FAIL

**Step 3: Write minimal implementation for `LevelData`**

```gdscript
# res://scripts/resources/level_data.gd
class_name LevelData
extends Resource

@export var level_id: int = 1
@export var max_moves: int = 25
@export var grid_width: int = 9
@export var grid_height: int = 9
@export var target_objectives: Dictionary = {}
@export var initial_grid: Array = []
```

**Step 4: Run test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=tests/unit/test_level_data.gd`  
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/resources/level_data.gd tests/unit/test_level_data.gd
git commit -m "feat: add LevelData Resource definition"
```
