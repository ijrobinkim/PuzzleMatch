# BoardModel Level Element Integration Implementation Plan

> **For Antigravity:** REQUIRED WORKFLOW: Use `.agent/workflows/execute-plan.md` to execute this plan in single-flow mode.

**Goal:** Integrate `BaseElement` grid mapping, adjacent match damage propagation, and falling block rules into `BoardModel`.

---

### Task 7: Integrate `BaseElement` Map and Damage Propagation in `BoardModel`

**Files:**
- Modify: `scripts/board/board_model.gd`
- Test: `tests/unit/test_board_element_integration.gd`

**Step 1: Write failing unit test for `BoardModel` element damage on match**

```gdscript
# tests/unit/test_board_element_integration.gd
extends GutTest

func test_adjacent_match_damages_element():
	var level = LevelData.new()
	level.grid_width = 5
	level.grid_height = 5
	level.move_limit = 20
	level.objective = 100
	
	var board = BoardModel.new(level, 42)
	var box = BoxElement.new()
	box.grid_position = Vector2i(2, 2)
	board.set_element(Vector2i(2, 2), box)
	
	assert_not_null(board.get_element(Vector2i(2, 2)))
	
	# Damage element adjacent to (2, 1)
	board.damage_adjacent_elements([Vector2i(2, 1)])
	assert_null(board.get_element(Vector2i(2, 2))) # Box health was 1, destroyed
	
	box.free()
```

**Step 2: Run test to verify it fails (RED)**

**Step 3: Add `elements` grid and `damage_adjacent_elements()` to `BoardModel` (GREEN)**

**Step 4: Run test to verify it passes (GREEN)**

**Step 5: Commit**
