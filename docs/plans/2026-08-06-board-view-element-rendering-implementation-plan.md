# BoardView Element Visual Rendering Implementation Plan

> **For Antigravity:** REQUIRED WORKFLOW: Use `.agent/workflows/execute-plan.md` to execute this plan in single-flow mode.

**Goal:** Implement visual element instantiation, grid positioning, damage pulse animation, and destruction effects in `BoardView`.

---

### Task 9: Implement `BoardView` Element Rendering and Damage Animations

**Files:**
- Modify: `scripts/board/board_view.gd`
- Test: `tests/unit/test_board_view_element_render.gd`

**Step 1: Write failing unit test for `BoardView` element rendering**

```gdscript
# tests/unit/test_board_view_element_render.gd
extends GutTest

func test_board_view_renders_elements():
	var level = LevelData.new()
	level.grid_width = 4
	level.grid_height = 4
	
	var board_model = BoardModel.new(level, 42)
	var box = BoxElement.new()
	box.grid_position = Vector2i(1, 1)
	board_model.set_element(Vector2i(1, 1), box)
	
	var view = BoardView.new()
	view.setup(board_model, level)
	
	assert_true(view.has_element_node_at(Vector2i(1, 1)))
	
	view.free()
	box.free()
```

**Step 2: Run test to verify it fails (RED)**

**Step 3: Add `_element_nodes` container and `has_element_node_at()` to `BoardView` (GREEN)**

**Step 4: Run test to verify it passes (GREEN)**

**Step 5: Commit**
