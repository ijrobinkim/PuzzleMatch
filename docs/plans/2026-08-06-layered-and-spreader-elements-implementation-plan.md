# LayeredElement & SpreaderElement Implementation Plan

> **For Antigravity:** REQUIRED WORKFLOW: Use `.agent/workflows/execute-plan.md` to execute this plan in single-flow mode.

**Goal:** Implement `LayeredElement` (multi-layer obstacles like Box/Stone Wall) and `SpreaderElement` (spreading obstacles like Ivy/Honey) in Godot 4 GDScript.

---

### Task 3: Create `LayeredElement` Subclass and Unit Test

**Files:**
- Create: `scripts/elements/layered_element.gd`
- Test: `tests/unit/test_layered_element.gd`

**Step 1: Write failing unit test for `LayeredElement`**

```gdscript
# tests/unit/test_layered_element.gd
extends GutTest

func test_layered_element_layers():
	var element = load("res://scripts/elements/layered_element.gd").new()
	element.max_health = 3
	element._ready()
	
	assert_eq(element.current_layer, 3)
	element.take_damage(1)
	assert_eq(element.current_layer, 2)
	assert_eq(element.current_health, 2)
	
	element.take_damage(2)
	element.free()
```

**Step 2: Run test to verify it fails (RED)**

Run: `& "C:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest="res://tests/unit/test_layered_element.gd"`

**Step 3: Write implementation for `LayeredElement` (GREEN)**

```gdscript
# res://scripts/elements/layered_element.gd
class_name LayeredElement
extends BaseElement

signal layer_changed(element: LayeredElement, new_layer: int)

var current_layer: int:
	get:
		return current_health

func take_damage(amount: int = 1) -> void:
	super.take_damage(amount)
	if current_health > 0:
		layer_changed.emit(self, current_health)
```

**Step 4: Run test to verify it passes (GREEN)**

**Step 5: Commit**

---

### Task 4: Create `SpreaderElement` Subclass and Unit Test

**Files:**
- Create: `scripts/elements/spreader_element.gd`
- Test: `tests/unit/test_spreader_element.gd`

**Step 1: Write failing unit test for `SpreaderElement`**

```gdscript
# tests/unit/test_spreader_element.gd
extends GutTest

func test_spreader_element_spread():
	var element = load("res://scripts/elements/spreader_element.gd").new()
	element.max_health = 1
	element._ready()
	
	watch_signals(element)
	var targets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
	var chosen = element.try_spread(targets)
	assert_signal_emitted(element, "element_spread")
	assert_true(chosen in targets)
	
	element.free()
```

**Step 2: Run test to verify it fails (RED)**

**Step 3: Write implementation for `SpreaderElement` (GREEN)**

```gdscript
# res://scripts/elements/spreader_element.gd
class_name SpreaderElement
extends BaseElement

signal element_spread(element: SpreaderElement, target_position: Vector2i)

func try_spread(available_positions: Array[Vector2i]) -> Vector2i:
	if available_positions.is_empty():
		return Vector2i(-1, -1)
	
	var target = available_positions.pick_random()
	element_spread.emit(self, target)
	return target
```

**Step 4: Run test to verify it passes (GREEN)**

**Step 5: Commit**
