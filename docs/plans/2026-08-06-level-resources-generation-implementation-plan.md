# Royal Kingdom Levels 1-5 Resource Data Generation Implementation Plan

> **For Antigravity:** REQUIRED WORKFLOW: Use `.agent/workflows/execute-plan.md` to execute this plan in single-flow mode.

**Goal:** Build Godot 4 Resource files (`level_001.tres` ~ `level_005.tres`) for Royal Kingdom tutorial level progression and verify with unit tests.

---

### Task 12: Create Royal Kingdom Levels 1-5 `.tres` Level Resources and Test Suite

**Files:**
- Create: `resources/levels/level_001.tres`
- Create: `resources/levels/level_002.tres`
- Create: `resources/levels/level_003.tres`
- Create: `resources/levels/level_004.tres`
- Create: `resources/levels/level_005.tres`
- Test: `tests/unit/test_royal_kingdom_levels.gd`

**Step 1: Write failing unit test for Levels 1-5 resource loading**

```gdscript
# tests/unit/test_royal_kingdom_levels.gd
extends GutTest

func test_royal_kingdom_levels_loading():
	var level_1: LevelData = load("res://resources/levels/level_001.tres")
	assert_not_null(level_1)
	assert_eq(level_1.target_objectives.get("box", 0), 4)
	
	var level_4: LevelData = load("res://resources/levels/level_004.tres")
	assert_not_null(level_4)
	assert_true(level_4.target_objectives.has("snow"))
```

**Step 2: Run test to verify it fails (RED)**

**Step 3: Write `.tres` Resource definitions for Levels 1 to 5 (GREEN)**

**Step 4: Run test to verify it passes (GREEN)**

**Step 5: Commit**
