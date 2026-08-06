# SpawnerElement & Concrete Elements (Box, Snow, Ivy, Column, Birdhouse) Implementation Plan

> **For Antigravity:** REQUIRED WORKFLOW: Use `.agent/workflows/execute-plan.md` to execute this plan in single-flow mode.

**Goal:** Implement `SpawnerElement` subclass and concrete Royal Kingdom Level 1~20 elements (`BoxElement`, `SnowElement`, `IvyElement`, `ColumnElement`, `BirdhouseElement`) in Godot 4 GDScript.

---

### Task 5: Create `SpawnerElement` Subclass and Unit Test

**Files:**
- Create: `scripts/elements/spawner_element.gd`
- Test: `tests/unit/test_spawner_element.gd`

**Step 1: Write failing unit test for `SpawnerElement`**

```gdscript
# tests/unit/test_spawner_element.gd
extends GutTest

func test_spawner_element_spawn():
	var spawner = load("res://scripts/elements/spawner_element.gd").new()
	spawner.item_to_spawn = "bird"
	spawner.spawn_count = 2
	
	watch_signals(spawner)
	var items = spawner.spawn_items()
	assert_signal_emitted(spawner, "items_spawned")
	assert_eq(items.size(), 2)
	assert_eq(items[0], "bird")
	
	spawner.free()
```

**Step 2: Run test to verify it fails (RED)**

**Step 3: Write implementation for `SpawnerElement` (GREEN)**

```gdscript
# res://scripts/elements/spawner_element.gd
class_name SpawnerElement
extends BaseElement

signal items_spawned(spawner: SpawnerElement, item_id: String, count: int)

@export var item_to_spawn: String = ""
@export var spawn_count: int = 1

func spawn_items() -> Array[String]:
	var result: Array[String] = []
	for i in range(spawn_count):
		result.append(item_to_spawn)
	items_spawned.emit(self, item_to_spawn, spawn_count)
	return result
```

**Step 4: Run test to verify it passes (GREEN)**

**Step 5: Commit**

---

### Task 6: Create Concrete Element Classes (`BoxElement`, `SnowElement`, `IvyElement`) and Factory Registration

**Files:**
- Create: `scripts/elements/concrete/box_element.gd`
- Create: `scripts/elements/concrete/snow_element.gd`
- Create: `scripts/elements/concrete/ivy_element.gd`
- Test: `tests/unit/test_concrete_elements.gd`

**Step 1: Write failing test for concrete elements**

```gdscript
# tests/unit/test_concrete_elements.gd
extends GutTest

func test_box_snow_ivy_initialization():
	var box = load("res://scripts/elements/concrete/box_element.gd").new()
	assert_eq(box.element_id, "box")
	assert_true(box.is_obstacle)
	box.free()
	
	var snow = load("res://scripts/elements/concrete/snow_element.gd").new()
	assert_eq(snow.element_id, "snow")
	assert_false(snow.is_obstacle) # Snow is a bottom board layer tile
	snow.free()
	
	var ivy = load("res://scripts/elements/concrete/ivy_element.gd").new()
	assert_eq(ivy.element_id, "ivy")
	ivy.free()
```

**Step 2: Run test to verify it fails (RED)**

**Step 3: Write implementations for `BoxElement`, `SnowElement`, `IvyElement` (GREEN)**

**Step 4: Run test to verify it passes (GREEN)**

**Step 5: Commit**
