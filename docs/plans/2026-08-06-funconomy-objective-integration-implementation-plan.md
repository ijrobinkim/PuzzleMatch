# Funconomy Target Objective Victory System Implementation Plan

> **For Antigravity:** REQUIRED WORKFLOW: Use `.agent/workflows/execute-plan.md` to execute this plan in single-flow mode.

**Goal:** Implement automatic adjacent element damage during cascade and target objective victory checking in `BoardModel` based on Funconomy deconstruction insights.

---

### Task 8: Implement Target Objective Victory Tracking and Cascade Damage Trigger

**Files:**
- Modify: `scripts/board/board_model.gd`
- Test: `tests/unit/test_board_funconomy_objectives.gd`

**Step 1: Write failing unit test for target objective completion**

```gdscript
# tests/unit/test_board_funconomy_objectives.gd
extends GutTest

func test_target_objectives_completion_triggers_level_completed():
	var level = LevelData.new()
	level.grid_width = 4
	level.grid_height = 4
	level.move_limit = 10
	level.target_objectives = {"box": 1}
	
	var board = BoardModel.new(level, 42)
	var box = BoxElement.new()
	box.element_id = "box"
	box.grid_position = Vector2i(1, 1)
	board.set_element(Vector2i(1, 1), box)
	
	watch_signals(board)
	
	# Clear cell (1, 0) adjacent to (1, 1)
	board.damage_adjacent_elements([Vector2i(1, 0)])
	
	assert_true(board.is_objective_completed())
```

**Step 2: Run test to verify it fails (RED)**

**Step 3: Add `target_objectives_remaining` tracking and `is_objective_completed()` to `BoardModel` (GREEN)**

**Step 4: Run test to verify it passes (GREEN)**

**Step 5: Commit**
