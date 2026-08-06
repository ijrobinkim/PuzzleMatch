# Element .tscn Scene Wrappers & Interactive Demo Implementation Plan

> **For Antigravity:** REQUIRED WORKFLOW: Use `.agent/workflows/execute-plan.md` to execute this plan in single-flow mode.

**Goal:** Create Godot `.tscn` scene files for all 7 Royal Kingdom elements and build an interactive demo scene (`element_test_demo.tscn`) for easy visual testing in Godot Editor.

---

### Task 13: Create Element `.tscn` Files and `element_test_demo.tscn` Demo Scene

**Files:**
- Create: `scenes/elements/box_element.tscn`
- Create: `scenes/elements/snow_element.tscn`
- Create: `scenes/elements/ivy_element.tscn`
- Create: `scenes/elements/column_element.tscn`
- Create: `scenes/elements/birdhouse_element.tscn`
- Create: `scenes/elements/steam_bomb_element.tscn`
- Create: `scenes/elements/dragon_box_element.tscn`
- Create: `scripts/screens/element_test_demo.gd`
- Create: `scenes/screens/element_test_demo.tscn`
- Test: `tests/unit/test_element_demo_scene.gd`

**Step 1: Write failing unit test for `element_test_demo` loading**

```gdscript
# tests/unit/test_element_demo_scene.gd
extends GutTest

func test_element_demo_scene_instantiation():
	var scene: PackedScene = load("res://scenes/screens/element_test_demo.tscn")
	assert_not_null(scene)
	var demo = scene.instantiate()
	assert_not_null(demo)
	demo.free()
```

**Step 2: Run test to verify it fails (RED)**

**Step 3: Create `.tscn` files and demo script/scene (GREEN)**

**Step 4: Run test to verify it passes (GREEN)**

**Step 5: Commit**
