# Match-3 Board Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first playable match-3 board for RoyalPuzzle — swap-based matching, striped/bomb bonus tiles, move limit vs. score objective, and cascading refills, rendered with placeholder art from the `sprite-gen` skill.

**Architecture:** `BoardModel` is a plain `RefCounted` GDScript class holding grid state and all match/cascade/bonus/deadlock logic, fully decoupled from the scene tree so it's unit-testable with GUT without instancing scenes. `BoardView` (a `Node2D`) owns a pool of `Tile` nodes, renders `BoardModel` state, subscribes to its signals to animate cascades, and translates drag/tap input into `BoardModel.attempt_swap()` calls.

**Tech Stack:** Godot 4.7 (GDScript), GUT (Godot Unit Test) for `BoardModel` tests, `sprite-gen` skill for placeholder art.

## Global Constraints

- Engine target is Godot 4.7 with the GL Compatibility renderer (already configured in `project.godot`) — every scene/script must work under it.
- Reuse the existing `EventBus` autoload signals exactly as already declared in `scripts/autoloads/event_bus.gd` — do not change their signatures: `tiles_matched(tile_type: int, count: int, board_position: Vector2i)`, `board_shuffled`, `move_used(moves_remaining: int)`, `level_started(level_id: String)`, `level_completed(level_id: String, stars: int)`, `level_failed(level_id: String)`.
- `BoardModel` must have zero `Node`/scene-tree dependencies — it's constructed with `.new()` and driven entirely through method calls and signals, so tests never need to instance a scene.
- Out of scope for this slice (per the approved spec): color-bomb bonus tile, direct swap-to-activate for existing bonus tiles (they only trigger by being matched into a new run), `SaveManager`/currency integration, level select / multiple levels.
- File layout follows the existing split structure: scripts in `scripts/board/`, `scripts/resources/`, `scripts/ui/`; scenes in `scenes/board/`, `scenes/screens/`; resources in `resources/levels/`; tests in `tests/unit/`.

---

### Task 1: Vendor and configure the GUT test framework

**Files:**
- Create: `addons/gut/` (vendored from upstream, contents not hand-written)
- Modify: `project.godot` (add `[editor_plugins]` section)
- Create: `.gutconfig.json`
- Create: `tests/unit/test_sanity.gd`

**Interfaces:**
- Produces: a working `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit` command every later task's tests are run with.

- [ ] **Step 1: Download and vendor the GUT addon**

```bash
cd "E:/1111_WORK/000000_Project/RoyalPuzzle"
curl -fL -o /tmp/gut.zip https://github.com/bitwes/Gut/archive/refs/tags/v9.6.1.zip
unzip -q /tmp/gut.zip -d /tmp/gut_src
mkdir -p addons
cp -r /tmp/gut_src/Gut-9.6.1/addons/gut addons/gut
rm -rf /tmp/gut.zip /tmp/gut_src
```

- [ ] **Step 2: Enable the plugin in `project.godot`**

Add this section (order relative to other sections doesn't matter):

```ini
[editor_plugins]

enabled=PackedStringArray("res://addons/gut/plugin.cfg")
```

- [ ] **Step 3: Add `.gutconfig.json` at the project root**

```json
{
    "dirs": ["res://tests/unit"],
    "include_subdirs": true
}
```

- [ ] **Step 4: Write a sanity test**

Create `tests/unit/test_sanity.gd`:

```gdscript
extends GutTest

func test_sanity():
	assert_eq(1 + 1, 2)
```

- [ ] **Step 5: Run it and verify GUT is wired up correctly**

Run: `"/c/Program Files/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`

Expected: output includes a summary line showing `1` test run, `1` passed, `0` failed, and the process exits with code 0.

- [ ] **Step 6: Commit**

```bash
git add addons/gut project.godot .gutconfig.json tests/unit/test_sanity.gd
git commit -m "Add GUT test framework"
```

---

### Task 2: LevelData resource and a test level instance

**Files:**
- Create: `scripts/resources/level_data.gd`
- Create: `resources/levels/level_001.tres`
- Test: `tests/unit/test_level_data.gd`

**Interfaces:**
- Produces: `class_name LevelData extends Resource` with exported fields `level_id: String`, `grid_width: int`, `grid_height: int`, `tile_type_count: int`, `move_limit: int`, `objective: int`. Every later task that constructs a `BoardModel` takes a `LevelData` instance.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/unit/test_level_data.gd
extends GutTest

func test_level_001_has_expected_values():
	var level: LevelData = load("res://resources/levels/level_001.tres")
	assert_eq(level.level_id, "level_001")
	assert_eq(level.grid_width, 8)
	assert_eq(level.grid_height, 8)
	assert_eq(level.tile_type_count, 6)
	assert_eq(level.move_limit, 20)
	assert_eq(level.objective, 1000)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"/c/Program Files/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_level_data.gd -gexit`
Expected: FAIL — `res://resources/levels/level_001.tres` does not exist.

- [ ] **Step 3: Create `scripts/resources/level_data.gd`**

```gdscript
class_name LevelData
extends Resource

@export var level_id: String = ""
@export var grid_width: int = 8
@export var grid_height: int = 8
@export var tile_type_count: int = 6
@export var move_limit: int = 20
@export var objective: int = 1000
```

- [ ] **Step 4: Create `resources/levels/level_001.tres`**

```ini
[gd_resource type="Resource" script_class="LevelData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/level_data.gd" id="1"]

[resource]
script = ExtResource("1")
level_id = "level_001"
grid_width = 8
grid_height = 8
tile_type_count = 6
move_limit = 20
objective = 1000
```

- [ ] **Step 5: Run test to verify it passes**

Run: `"/c/Program Files/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_level_data.gd -gexit`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add scripts/resources/level_data.gd resources/levels/level_001.tres tests/unit/test_level_data.gd
git commit -m "Add LevelData resource and test level"
```

---

### Task 3: Generate placeholder tile art with sprite-gen

**Files:**
- Create: `assets/sprites/board/tiles.png` (+ import metadata)
- Create: `assets/sprites/board/bonus_overlay.png` (+ import metadata)

**Interfaces:**
- Produces: `assets/sprites/board/tiles.png` — a horizontal sprite sheet, 6 frames, each a distinct flat-colored gem/candy-style icon on a transparent background, square frames (e.g. 128×128 per frame, 768×128 total).
- Produces: `assets/sprites/board/bonus_overlay.png` — a horizontal sprite sheet, 2 frames, same per-frame size as `tiles.png`: frame 0 is a diagonal-stripe motif (for striped bonus tiles), frame 1 is a star/burst motif (for bomb tiles), both on a transparent background so they composite over a tile icon.

- [ ] **Step 1: Invoke the sprite-gen skill**

Run the `sprite-gen` skill with this request: generate a 6-frame horizontal sprite sheet of simple, flat-colored, high-contrast gem/candy icons (distinct hues — e.g. red, blue, green, yellow, purple, orange), 128×128 per frame, transparent background, saved to `assets/sprites/board/tiles.png`; and a separate 2-frame horizontal sprite sheet of bonus overlay icons at the same 128×128 frame size with a transparent background — frame 0 a diagonal stripe motif, frame 1 a star/burst motif — saved to `assets/sprites/board/bonus_overlay.png`.

- [ ] **Step 2: Verify the generated files**

Confirm both files exist and open them (or check reported dimensions) to confirm `tiles.png` is 768×128 (6×128) and `bonus_overlay.png` is 256×128 (2×128), each frame visually distinct.

- [ ] **Step 3: Let Godot import the new textures**

Run: `"/c/Program Files/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . --quit`
Expected: no import errors printed; `.png.import` files are generated next to both PNGs.

- [ ] **Step 4: Commit**

```bash
git add assets/sprites/board/tiles.png assets/sprites/board/tiles.png.import assets/sprites/board/bonus_overlay.png assets/sprites/board/bonus_overlay.png.import
git commit -m "Add placeholder board art via sprite-gen"
```

---

### Task 4: BoardModel — grid initialization, bounds, accessors

**Files:**
- Create: `scripts/board/board_model.gd`
- Test: `tests/unit/test_board_model_grid.gd`

**Interfaces:**
- Produces: `class_name BoardModel extends RefCounted`, constructed as `BoardModel.new(level_data: LevelData, rng_seed: int = -1)`. Public fields `width: int`, `height: int`, `tile_type_count: int`, `types: Array` (`types[x][y] -> int`), `bonuses: Array` (`bonuses[x][y] -> String`), `moves_remaining: int`, `score: int`, `objective: int`, `is_busy: bool`. Public methods `is_in_bounds(cell: Vector2i) -> bool`, `get_tile_type(cell: Vector2i) -> int`, `get_bonus_kind(cell: Vector2i) -> String`.
- Consumes: `LevelData` fields from Task 2.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/unit/test_board_model_grid.gd
extends GutTest

func _make_level(w: int, h: int, types: int) -> LevelData:
	var level := LevelData.new()
	level.grid_width = w
	level.grid_height = h
	level.tile_type_count = types
	level.move_limit = 20
	level.objective = 1000
	return level

func test_grid_has_correct_dimensions():
	var board := BoardModel.new(_make_level(5, 7, 6), 1)
	assert_eq(board.width, 5)
	assert_eq(board.height, 7)
	for x in 5:
		assert_eq(board.types[x].size(), 7)

func test_all_tile_types_are_in_range():
	var board := BoardModel.new(_make_level(8, 8, 6), 1)
	for x in 8:
		for y in 8:
			var t: int = board.get_tile_type(Vector2i(x, y))
			assert_true(t >= 0 and t < 6)

func test_is_in_bounds():
	var board := BoardModel.new(_make_level(4, 4, 6), 1)
	assert_true(board.is_in_bounds(Vector2i(0, 0)))
	assert_true(board.is_in_bounds(Vector2i(3, 3)))
	assert_false(board.is_in_bounds(Vector2i(4, 0)))
	assert_false(board.is_in_bounds(Vector2i(-1, 0)))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"/c/Program Files/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_board_model_grid.gd -gexit`
Expected: FAIL — `BoardModel` does not exist.

- [ ] **Step 3: Implement `scripts/board/board_model.gd`**

```gdscript
class_name BoardModel
extends RefCounted

const BONUS_NONE := ""
const BONUS_STRIPED_ROW := "striped_row"
const BONUS_STRIPED_COL := "striped_col"
const BONUS_BOMB := "bomb"
const EMPTY_TYPE := -1

var width: int
var height: int
var tile_type_count: int
var types: Array = []
var bonuses: Array = []
var moves_remaining: int
var score: int = 0
var objective: int
var is_busy: bool = false
var _rng := RandomNumberGenerator.new()

func _init(level_data: LevelData, rng_seed: int = -1) -> void:
	width = level_data.grid_width
	height = level_data.grid_height
	tile_type_count = level_data.tile_type_count
	moves_remaining = level_data.move_limit
	objective = level_data.objective
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	_fill_random_grid()

func _fill_random_grid() -> void:
	types.clear()
	bonuses.clear()
	for x in width:
		var col_types: Array = []
		var col_bonuses: Array = []
		for y in height:
			col_types.append(_rng.randi() % tile_type_count)
			col_bonuses.append(BONUS_NONE)
		types.append(col_types)
		bonuses.append(col_bonuses)

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height

func get_tile_type(cell: Vector2i) -> int:
	return types[cell.x][cell.y]

func get_bonus_kind(cell: Vector2i) -> String:
	return bonuses[cell.x][cell.y]
```

- [ ] **Step 4: Run test to verify it passes**

Run: `"/c/Program Files/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_board_model_grid.gd -gexit`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add scripts/board/board_model.gd tests/unit/test_board_model_grid.gd
git commit -m "Add BoardModel grid init, bounds, accessors"
```

---

### Task 5: BoardModel — match detection (`find_matches`)

**Files:**
- Modify: `scripts/board/board_model.gd`
- Test: `tests/unit/test_board_model_matches.gd`

**Interfaces:**
- Produces: `find_matches() -> Array`, where each element is a `Dictionary` `{"cells": Array[Vector2i], "bonus_kind": String, "bonus_pos": Vector2i}`. Reads directly from `types`/`bonuses`, so tests set `board.types` directly after construction to get deterministic grids.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/unit/test_board_model_matches.gd
extends GutTest

func _make_level(w: int, h: int, types: int) -> LevelData:
	var level := LevelData.new()
	level.grid_width = w
	level.grid_height = h
	level.tile_type_count = types
	level.move_limit = 20
	level.objective = 1000
	return level

func _flat_board(w: int, h: int, rows: Array) -> BoardModel:
	# rows[y] is an Array of ints, top row first.
	var board := BoardModel.new(_make_level(w, h, 6), 1)
	for x in w:
		for y in h:
			board.types[x][y] = rows[y][x]
			board.bonuses[x][y] = BoardModel.BONUS_NONE
	return board

func test_no_match_on_varied_grid():
	var board := _flat_board(4, 4, [
		[0, 1, 2, 3],
		[1, 2, 3, 0],
		[2, 3, 0, 1],
		[3, 0, 1, 2],
	])
	assert_eq(board.find_matches().size(), 0)

func test_horizontal_three_match_has_no_bonus():
	var board := _flat_board(4, 1, [[0, 0, 0, 1]])
	var matches := board.find_matches()
	assert_eq(matches.size(), 1)
	assert_eq(matches[0]["bonus_kind"], BoardModel.BONUS_NONE)
	assert_eq(matches[0]["cells"].size(), 3)

func test_horizontal_four_match_creates_striped_row():
	var board := _flat_board(5, 1, [[0, 0, 0, 0, 1]])
	var matches := board.find_matches()
	assert_eq(matches.size(), 1)
	assert_eq(matches[0]["bonus_kind"], BoardModel.BONUS_STRIPED_ROW)

func test_vertical_four_match_creates_striped_col():
	var board := _flat_board(1, 5, [[0], [0], [0], [0], [1]])
	var matches := board.find_matches()
	assert_eq(matches.size(), 1)
	assert_eq(matches[0]["bonus_kind"], BoardModel.BONUS_STRIPED_COL)

func test_l_shape_match_creates_bomb():
	# Horizontal run of 3 at y=2, vertical run of 3 at x=0, sharing cell (0,2).
	var board := _flat_board(3, 3, [
		[0, 1, 1],
		[0, 1, 1],
		[0, 0, 0],
	])
	var matches := board.find_matches()
	assert_eq(matches.size(), 1)
	assert_eq(matches[0]["bonus_kind"], BoardModel.BONUS_BOMB)
	assert_eq(matches[0]["bonus_pos"], Vector2i(0, 2))

func test_five_in_a_line_creates_bomb():
	var board := _flat_board(5, 1, [[0, 0, 0, 0, 0]])
	var matches := board.find_matches()
	assert_eq(matches.size(), 1)
	assert_eq(matches[0]["bonus_kind"], BoardModel.BONUS_BOMB)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"/c/Program Files/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_board_model_matches.gd -gexit`
Expected: FAIL — `find_matches` does not exist.

- [ ] **Step 3: Add `find_matches()` to `scripts/board/board_model.gd`**

```gdscript
func find_matches() -> Array:
	var runs: Array = []
	for y in height:
		var run_start := 0
		for x in range(1, width + 1):
			var same := x < width and types[x][y] == types[run_start][y]
			if not same:
				var length := x - run_start
				if length >= 3:
					var cells: Array = []
					for rx in range(run_start, x):
						cells.append(Vector2i(rx, y))
					runs.append({"cells": cells, "dir": "h", "length": length})
				run_start = x
	for x in width:
		var run_start := 0
		for y in range(1, height + 1):
			var same := y < height and types[x][y] == types[x][run_start]
			if not same:
				var length := y - run_start
				if length >= 3:
					var cells: Array = []
					for ry in range(run_start, y):
						cells.append(Vector2i(x, ry))
					runs.append({"cells": cells, "dir": "v", "length": length})
				run_start = y

	if runs.is_empty():
		return []

	var parent: Array = []
	for i in runs.size():
		parent.append(i)

	var find_root := func(start_i: int) -> int:
		var i := start_i
		while parent[i] != i:
			i = parent[i]
		return i

	for i in runs.size():
		for j in range(i + 1, runs.size()):
			var shares := false
			for cell in runs[i]["cells"]:
				if runs[j]["cells"].has(cell):
					shares = true
					break
			if shares:
				var ri: int = find_root.call(i)
				var rj: int = find_root.call(j)
				if ri != rj:
					parent[ri] = rj

	var groups_by_root: Dictionary = {}
	for i in runs.size():
		var root: int = find_root.call(i)
		if not groups_by_root.has(root):
			groups_by_root[root] = []
		groups_by_root[root].append(runs[i])

	var matches: Array = []
	for root in groups_by_root.keys():
		var member_runs: Array = groups_by_root[root]
		var all_cells: Array = []
		var has_h := false
		var has_v := false
		var max_len := 0
		var longest_run: Dictionary = member_runs[0]
		for run in member_runs:
			if run["dir"] == "h":
				has_h = true
			else:
				has_v = true
			if run["length"] > max_len:
				max_len = run["length"]
				longest_run = run
			for cell in run["cells"]:
				if not all_cells.has(cell):
					all_cells.append(cell)

		var bonus_kind := BONUS_NONE
		var bonus_pos: Vector2i = longest_run["cells"][int(longest_run["cells"].size() / 2)]

		if max_len >= 5 or (has_h and has_v):
			bonus_kind = BONUS_BOMB
			if has_h and has_v:
				for run_a in member_runs:
					if run_a["dir"] != "h":
						continue
					for run_b in member_runs:
						if run_b["dir"] != "v":
							continue
						for cell in run_a["cells"]:
							if run_b["cells"].has(cell):
								bonus_pos = cell
		elif max_len == 4:
			bonus_kind = BONUS_STRIPED_ROW if longest_run["dir"] == "h" else BONUS_STRIPED_COL

		matches.append({"cells": all_cells, "bonus_kind": bonus_kind, "bonus_pos": bonus_pos})

	return matches
```

- [ ] **Step 4: Run test to verify it passes**

Run: `"/c/Program Files/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_board_model_matches.gd -gexit`
Expected: PASS (6 tests)

- [ ] **Step 5: Commit**

```bash
git add scripts/board/board_model.gd tests/unit/test_board_model_matches.gd
git commit -m "Add BoardModel match detection with bonus-tile classification"
```

---

### Task 6: BoardModel — no-initial-match guarantee

**Files:**
- Modify: `scripts/board/board_model.gd`
- Test: `tests/unit/test_board_model_initial_state.gd`

**Interfaces:**
- Modifies: `_init()` now loops `_fill_random_grid()` until `find_matches()` is empty.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/unit/test_board_model_initial_state.gd
extends GutTest

func _make_level(w: int, h: int, types: int) -> LevelData:
	var level := LevelData.new()
	level.grid_width = w
	level.grid_height = h
	level.tile_type_count = types
	level.move_limit = 20
	level.objective = 1000
	return level

func test_initial_board_never_has_a_match():
	for seed_value in range(20):
		var board := BoardModel.new(_make_level(8, 8, 6), seed_value)
		assert_eq(board.find_matches().size(), 0, "seed %d produced an initial match" % seed_value)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"/c/Program Files/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_board_model_initial_state.gd -gexit`
Expected: FAIL for at least one seed (random fill can produce runs of 3+ by chance).

- [ ] **Step 3: Update `_init()` in `scripts/board/board_model.gd`**

Replace the body of `_init` (keep everything up to and including the `_fill_random_grid()` call, then add the loop):

```gdscript
func _init(level_data: LevelData, rng_seed: int = -1) -> void:
	width = level_data.grid_width
	height = level_data.grid_height
	tile_type_count = level_data.tile_type_count
	moves_remaining = level_data.move_limit
	objective = level_data.objective
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	_fill_random_grid()
	while not find_matches().is_empty():
		_fill_random_grid()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `"/c/Program Files/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_board_model_initial_state.gd -gexit`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/board/board_model.gd tests/unit/test_board_model_initial_state.gd
git commit -m "Guarantee BoardModel never starts with a pre-existing match"
```

---

### Task 7: BoardModel — `attempt_swap` with minimal clear-only resolution

**Files:**
- Modify: `scripts/board/board_model.gd`
- Test: `tests/unit/test_board_model_swap.gd`

**Interfaces:**
- Produces: signals `swap_rejected(a: Vector2i, b: Vector2i)`, `move_consumed(moves_remaining: int)`, `level_completed`, `level_failed`. Method `attempt_swap(a: Vector2i, b: Vector2i) -> bool`. Internal `_resolve_cascade()` (minimal version in this task — only clears matched cells to `EMPTY_TYPE`, no gravity/refill/looping yet; Task 8 replaces its body).

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/unit/test_board_model_swap.gd
extends GutTest

func _make_level(w: int, h: int, types: int, move_limit: int = 20, objective: int = 1000000) -> LevelData:
	var level := LevelData.new()
	level.grid_width = w
	level.grid_height = h
	level.tile_type_count = types
	level.move_limit = move_limit
	level.objective = objective
	return level

func _flat_board(w: int, h: int, rows: Array, move_limit: int = 20, objective: int = 1000000) -> BoardModel:
	var board := BoardModel.new(_make_level(w, h, 6, move_limit, objective), 1)
	for x in w:
		for y in h:
			board.types[x][y] = rows[y][x]
			board.bonuses[x][y] = BoardModel.BONUS_NONE
	return board

func test_swap_that_creates_a_match_is_accepted_and_clears_cells():
	# Swapping (2,0) and (2,1) makes row 0 read [0,0,0,1] -> a match.
	var board := _flat_board(4, 2, [
		[0, 0, 1, 1],
		[2, 2, 0, 3],
	])
	var result := board.attempt_swap(Vector2i(2, 0), Vector2i(2, 1))
	assert_true(result)
	assert_eq(board.get_tile_type(Vector2i(0, 0)), BoardModel.EMPTY_TYPE)
	assert_eq(board.moves_remaining, 19)

func test_swap_that_creates_no_match_is_rejected_and_reverted():
	var board := _flat_board(4, 2, [
		[0, 1, 2, 3],
		[1, 2, 3, 0],
	])
	var watcher := watch_signals(board)
	var result := board.attempt_swap(Vector2i(0, 0), Vector2i(1, 0))
	assert_false(result)
	assert_eq(board.get_tile_type(Vector2i(0, 0)), 0)
	assert_eq(board.get_tile_type(Vector2i(1, 0)), 1)
	assert_eq(board.moves_remaining, 20)
	assert_signal_emitted(board, "swap_rejected")

func test_non_adjacent_swap_is_rejected():
	var board := _flat_board(4, 2, [
		[0, 1, 2, 3],
		[1, 2, 3, 0],
	])
	var result := board.attempt_swap(Vector2i(0, 0), Vector2i(2, 0))
	assert_false(result)

func test_level_fails_when_moves_run_out_without_reaching_objective():
	var board := _flat_board(4, 2, [
		[0, 0, 1, 1],
		[2, 2, 0, 3],
	], 1, 1000000)
	var watcher := watch_signals(board)
	board.attempt_swap(Vector2i(2, 0), Vector2i(2, 1))
	assert_eq(board.moves_remaining, 0)
	assert_signal_emitted(board, "level_failed")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"/c/Program Files/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_board_model_swap.gd -gexit`
Expected: FAIL — `attempt_swap` does not exist.

- [ ] **Step 3: Add signals and `attempt_swap`/`_resolve_cascade` to `scripts/board/board_model.gd`**

Add these signal declarations near the top of the file (below the `const` block):

```gdscript
signal swap_rejected(a: Vector2i, b: Vector2i)
signal cascade_step(step: Dictionary)
signal cascade_finished
signal move_consumed(moves_remaining: int)
signal score_changed(score: int)
signal level_completed
signal level_failed
signal board_reshuffled
```

Add these methods:

```gdscript
func attempt_swap(a: Vector2i, b: Vector2i) -> bool:
	if is_busy:
		return false
	if not is_in_bounds(a) or not is_in_bounds(b):
		return false
	if absi(a.x - b.x) + absi(a.y - b.y) != 1:
		return false
	_swap_cells(a, b)
	if find_matches().is_empty():
		_swap_cells(a, b)
		swap_rejected.emit(a, b)
		return false
	moves_remaining -= 1
	move_consumed.emit(moves_remaining)
	is_busy = true
	_resolve_cascade()
	is_busy = false
	if score >= objective:
		level_completed.emit()
	elif moves_remaining <= 0:
		level_failed.emit()
	return true

func _swap_cells(a: Vector2i, b: Vector2i) -> void:
	var t: int = types[a.x][a.y]
	types[a.x][a.y] = types[b.x][b.y]
	types[b.x][b.y] = t
	var bo: String = bonuses[a.x][a.y]
	bonuses[a.x][a.y] = bonuses[b.x][b.y]
	bonuses[b.x][b.y] = bo

func _resolve_cascade() -> void:
	var matches := find_matches()
	while not matches.is_empty():
		for m in matches:
			for cell in m["cells"]:
				types[cell.x][cell.y] = EMPTY_TYPE
				bonuses[cell.x][cell.y] = BONUS_NONE
		matches = find_matches()
	cascade_finished.emit()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `"/c/Program Files/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_board_model_swap.gd -gexit`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add scripts/board/board_model.gd tests/unit/test_board_model_swap.gd
git commit -m "Add BoardModel attempt_swap with minimal clear-only resolution"
```

---

### Task 8: BoardModel — full cascade: bonus creation, chain triggers, gravity, refill, scoring

**Files:**
- Modify: `scripts/board/board_model.gd`
- Test: `tests/unit/test_board_model_cascade.gd`

**Interfaces:**
- Replaces: `_resolve_cascade()` body from Task 7 with the full version below.
- Produces: `_expand_bonus_triggers(cleared: Dictionary) -> Dictionary`, `_apply_gravity(cleared_cells: Array) -> Array`, `_refill_empty_cells() -> Array`. `cascade_step` now emits a `Dictionary` with keys `"matches"` (`Array` of `{"type": int, "count": int, "position": Vector2i}`), `"cleared"` (`Array[Vector2i]`), `"bonuses"` (`Array` of `{"pos": Vector2i, "kind": String}`, final post-gravity positions), `"falls"` (`Array` of `{"from": Vector2i, "to": Vector2i}`), `"refills"` (`Array` of `{"pos": Vector2i, "type": int}`).
- `score` now increases by 10 per cleared cell; `score_changed(score: int)` emits each cascade iteration.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/unit/test_board_model_cascade.gd
extends GutTest

func _make_level(w: int, h: int, types: int, move_limit: int = 20, objective: int = 1000000) -> LevelData:
	var level := LevelData.new()
	level.grid_width = w
	level.grid_height = h
	level.tile_type_count = types
	level.move_limit = move_limit
	level.objective = objective
	return level

func _flat_board(w: int, h: int, rows: Array, move_limit: int = 20, objective: int = 1000000) -> BoardModel:
	var board := BoardModel.new(_make_level(w, h, 6, move_limit, objective), 1)
	for x in w:
		for y in h:
			board.types[x][y] = rows[y][x]
			board.bonuses[x][y] = BoardModel.BONUS_NONE
	return board

func test_cascade_clears_no_empty_cells_remain():
	var board := _flat_board(4, 2, [
		[0, 0, 1, 1],
		[2, 2, 0, 3],
	])
	board.attempt_swap(Vector2i(2, 0), Vector2i(2, 1))
	for x in 4:
		for y in 2:
			assert_ne(board.get_tile_type(Vector2i(x, y)), BoardModel.EMPTY_TYPE)

func test_cascade_applies_gravity_before_refill():
	# Column 0: clearing (0,2) should pull (0,0) and (0,1) down by one.
	var board := _flat_board(1, 3, [[5], [4], [3]])
	board.types[0][2] = BoardModel.EMPTY_TYPE
	var falls: Array = board._apply_gravity([])
	assert_eq(board.get_tile_type(Vector2i(0, 2)), 4)
	assert_eq(board.get_tile_type(Vector2i(0, 1)), 5)
	assert_eq(board.get_tile_type(Vector2i(0, 0)), BoardModel.EMPTY_TYPE)

func test_score_increases_by_ten_per_cleared_cell():
	var board := _flat_board(4, 2, [
		[0, 0, 1, 1],
		[2, 2, 0, 3],
	])
	board.attempt_swap(Vector2i(2, 0), Vector2i(2, 1))
	# Exactly 3 cells match here, but refilled tiles could coincidentally
	# chain into another match, so assert the invariant (multiple of 10,
	# at least the 3-cell clear) rather than an exact value tied to RNG output.
	assert_true(board.score >= 30)
	assert_eq(board.score % 10, 0)

func test_four_match_spawns_striped_bonus_on_board():
	# rng_seed=1 is fixed for determinism. If this ever fails because a
	# refilled tile happens to chain-clear the new bonus tile in the same
	# cascade, try rng_seed 2, 3, ... until the assertion is stable.
	var board := _flat_board(5, 2, [
		[0, 0, 0, 1, 2],
		[3, 4, 5, 0, 4],
	])
	board.attempt_swap(Vector2i(3, 0), Vector2i(3, 1))
	var found_bonus := false
	for x in 5:
		for y in 2:
			if board.get_bonus_kind(Vector2i(x, y)) == BoardModel.BONUS_STRIPED_ROW:
				found_bonus = true
	assert_true(found_bonus)

func test_triggering_a_striped_tile_clears_its_row():
	# Manually place a striped_row bonus at (1,0), then match it into a new run.
	var board := _flat_board(4, 2, [
		[0, 0, 0, 1],
		[5, 4, 3, 2],
	])
	board.bonuses[1][0] = BoardModel.BONUS_STRIPED_ROW
	board.attempt_swap(Vector2i(3, 0), Vector2i(3, 1))
	# Row 0 should be fully cleared and refilled (bonus flag reset on every
	# cell); row 1 has nothing above it to fall into it, so it must be
	# byte-for-byte unchanged. Both checks are independent of RNG output.
	for x in 4:
		assert_eq(board.get_bonus_kind(Vector2i(x, 0)), BoardModel.BONUS_NONE, "row 0 cell x=%d should have been cleared and refilled" % x)
	assert_eq(board.get_tile_type(Vector2i(0, 1)), 5)
	assert_eq(board.get_tile_type(Vector2i(1, 1)), 4)
	assert_eq(board.get_tile_type(Vector2i(2, 1)), 3)
	assert_eq(board.get_tile_type(Vector2i(3, 1)), 1)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"/c/Program Files/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_board_model_cascade.gd -gexit`
Expected: FAIL — no gravity/refill/bonus behavior yet, scores stay 0.

- [ ] **Step 3: Replace `_resolve_cascade()` and add helper methods in `scripts/board/board_model.gd`**

```gdscript
const POINTS_PER_TILE := 10

func _resolve_cascade() -> void:
	var matches := find_matches()
	while not matches.is_empty():
		var match_infos: Array = []
		var cleared: Dictionary = {}
		var bonus_spawns: Array = []
		for m in matches:
			var anchor: Vector2i = m["cells"][0]
			match_infos.append({
				"type": types[anchor.x][anchor.y],
				"count": m["cells"].size(),
				"position": m["bonus_pos"] if m["bonus_kind"] != BONUS_NONE else anchor,
			})
			for cell in m["cells"]:
				cleared[cell] = true
			if m["bonus_kind"] != BONUS_NONE:
				bonus_spawns.append({"pos": m["bonus_pos"], "kind": m["bonus_kind"]})

		cleared = _expand_bonus_triggers(cleared)

		for spawn in bonus_spawns:
			cleared.erase(spawn["pos"])

		score += cleared.size() * POINTS_PER_TILE
		score_changed.emit(score)

		var cleared_cells: Array = cleared.keys()
		var falls := _apply_gravity(cleared_cells)
		var refills := _refill_empty_cells()

		for spawn in bonus_spawns:
			var final_pos: Vector2i = spawn["pos"]
			for f in falls:
				if f["from"] == spawn["pos"]:
					final_pos = f["to"]
					break
			bonuses[final_pos.x][final_pos.y] = spawn["kind"]
			spawn["pos"] = final_pos

		cascade_step.emit({
			"matches": match_infos,
			"cleared": cleared_cells,
			"bonuses": bonus_spawns,
			"falls": falls,
			"refills": refills,
		})

		matches = find_matches()

	cascade_finished.emit()

func _expand_bonus_triggers(cleared: Dictionary) -> Dictionary:
	var changed := true
	while changed:
		changed = false
		for cell in cleared.keys():
			var kind: String = bonuses[cell.x][cell.y]
			if kind == BONUS_NONE:
				continue
			var extra: Array = []
			if kind == BONUS_STRIPED_ROW:
				for x in width:
					extra.append(Vector2i(x, cell.y))
			elif kind == BONUS_STRIPED_COL:
				for y in height:
					extra.append(Vector2i(cell.x, y))
			elif kind == BONUS_BOMB:
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						var c := Vector2i(cell.x + dx, cell.y + dy)
						if is_in_bounds(c):
							extra.append(c)
			for c in extra:
				if not cleared.has(c):
					cleared[c] = true
					changed = true
	return cleared

func _apply_gravity(cleared_cells: Array) -> Array:
	var falls: Array = []
	for cell in cleared_cells:
		types[cell.x][cell.y] = EMPTY_TYPE
		bonuses[cell.x][cell.y] = BONUS_NONE
	for x in width:
		var write_y := height - 1
		for y in range(height - 1, -1, -1):
			if types[x][y] == EMPTY_TYPE:
				continue
			if write_y != y:
				types[x][write_y] = types[x][y]
				bonuses[x][write_y] = bonuses[x][y]
				falls.append({"from": Vector2i(x, y), "to": Vector2i(x, write_y)})
			write_y -= 1
		for empty_y in range(write_y, -1, -1):
			types[x][empty_y] = EMPTY_TYPE
			bonuses[x][empty_y] = BONUS_NONE
	return falls

func _refill_empty_cells() -> Array:
	var refills: Array = []
	for x in width:
		for y in height:
			if types[x][y] == EMPTY_TYPE:
				var new_type := _rng.randi() % tile_type_count
				types[x][y] = new_type
				bonuses[x][y] = BONUS_NONE
				refills.append({"pos": Vector2i(x, y), "type": new_type})
	return refills
```

- [ ] **Step 4: Run test to verify it passes**

Run: `"/c/Program Files/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_board_model_cascade.gd -gexit`
Expected: PASS (5 tests)

- [ ] **Step 5: Run the full test suite to check for regressions**

Run: `"/c/Program Files/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: all tests across every file still pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/board/board_model.gd tests/unit/test_board_model_cascade.gd
git commit -m "Add full BoardModel cascade: gravity, refill, bonus triggers, scoring"
```

---

### Task 9: BoardModel — deadlock detection and reshuffle

**Files:**
- Modify: `scripts/board/board_model.gd`
- Test: `tests/unit/test_board_model_deadlock.gd`

**Interfaces:**
- Produces: `has_any_valid_move() -> bool`, `reshuffle() -> void` (emits `board_reshuffled`).
- Modifies: `_init()` reshuffles if the fresh board has no valid move; `_resolve_cascade()` reshuffles after settling if the board is deadlocked.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/unit/test_board_model_deadlock.gd
extends GutTest

func _make_level(w: int, h: int, types: int) -> LevelData:
	var level := LevelData.new()
	level.grid_width = w
	level.grid_height = h
	level.tile_type_count = types
	level.move_limit = 20
	level.objective = 1000000
	return level

func test_checkerboard_of_two_colors_has_no_valid_move():
	var board := BoardModel.new(_make_level(4, 4, 6), 1)
	for x in 4:
		for y in 4:
			board.types[x][y] = (x + y) % 2
	assert_false(board.has_any_valid_move())

func test_grid_with_a_possible_match_has_a_valid_move():
	var board := BoardModel.new(_make_level(4, 1, 6), 1)
	board.types[0][0] = 0
	board.types[1][0] = 0
	board.types[2][0] = 1
	board.types[3][0] = 0
	assert_true(board.has_any_valid_move())

func test_reshuffle_produces_a_board_with_no_match_and_a_valid_move():
	var board := BoardModel.new(_make_level(6, 6, 6), 1)
	var watcher := watch_signals(board)
	board.reshuffle()
	assert_eq(board.find_matches().size(), 0)
	assert_true(board.has_any_valid_move())
	assert_signal_emitted(board, "board_reshuffled")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"/c/Program Files/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_board_model_deadlock.gd -gexit`
Expected: FAIL — `has_any_valid_move`/`reshuffle` do not exist.

- [ ] **Step 3: Add deadlock detection and reshuffle to `scripts/board/board_model.gd`**

```gdscript
func has_any_valid_move() -> bool:
	for x in width:
		for y in height:
			if x + 1 < width and _would_swap_match(Vector2i(x, y), Vector2i(x + 1, y)):
				return true
			if y + 1 < height and _would_swap_match(Vector2i(x, y), Vector2i(x, y + 1)):
				return true
	return false

func _would_swap_match(a: Vector2i, b: Vector2i) -> bool:
	_swap_cells(a, b)
	var has_match := not find_matches().is_empty()
	_swap_cells(a, b)
	return has_match

func reshuffle() -> void:
	var flat_types: Array = []
	for x in width:
		for y in height:
			flat_types.append(types[x][y])
	var attempts := 0
	while attempts < 100:
		flat_types.shuffle()
		var i := 0
		for x in width:
			for y in height:
				types[x][y] = flat_types[i]
				i += 1
		if find_matches().is_empty() and has_any_valid_move():
			board_reshuffled.emit()
			return
		attempts += 1
	_fill_random_grid()
	while not find_matches().is_empty() or not has_any_valid_move():
		_fill_random_grid()
	board_reshuffled.emit()
```

Then update `_init()` to reshuffle if the fresh board is deadlocked (add after the existing `while not find_matches().is_empty(): _fill_random_grid()` loop):

```gdscript
	if not has_any_valid_move():
		reshuffle()
```

And update `_resolve_cascade()`'s final line — replace `cascade_finished.emit()` with:

```gdscript
	if not has_any_valid_move():
		reshuffle()
	cascade_finished.emit()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `"/c/Program Files/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_board_model_deadlock.gd -gexit`
Expected: PASS (3 tests)

- [ ] **Step 5: Run the full test suite to check for regressions**

Run: `"/c/Program Files/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/board/board_model.gd tests/unit/test_board_model_deadlock.gd
git commit -m "Add BoardModel deadlock detection and reshuffle"
```

---

### Task 10: Tile scene and script

**Files:**
- Create: `scenes/board/tile.tscn`
- Create: `scripts/board/tile.gd`
- Test: `tests/unit/test_tile.gd`

**Interfaces:**
- Consumes: `assets/sprites/board/tiles.png`, `assets/sprites/board/bonus_overlay.png` (Task 3); `BoardModel.BONUS_NONE/STRIPED_ROW/STRIPED_COL/BOMB` string constants (Task 4/5).
- Produces: `class_name Tile extends Node2D` with `cell: Vector2i`, `tile_type: int`, methods `setup(p_cell: Vector2i, p_type: int, bonus_kind: String, cell_size: float) -> void`, `reset() -> void`, `animate_move_to(target_cell: Vector2i, cell_size: float, duration: float = 0.2) -> void`, `animate_clear(duration: float = 0.15) -> void`, `animate_spawn(duration: float = 0.15) -> void`.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/unit/test_tile.gd
extends GutTest

var tile: Tile

func before_each():
	tile = preload("res://scenes/board/tile.tscn").instantiate()
	add_child_autofree(tile)

func test_setup_sets_type_and_position():
	tile.setup(Vector2i(2, 3), 4, BoardModel.BONUS_NONE, 100.0)
	assert_eq(tile.tile_type, 4)
	assert_eq(tile.position, Vector2(200, 300))
	assert_false(tile.get_node("BonusOverlay").visible)

func test_setup_with_bomb_bonus_shows_overlay_frame_1():
	tile.setup(Vector2i(0, 0), 0, BoardModel.BONUS_BOMB, 100.0)
	var overlay: Sprite2D = tile.get_node("BonusOverlay")
	assert_true(overlay.visible)
	assert_eq(overlay.frame, 1)

func test_setup_with_striped_col_rotates_overlay_90_degrees():
	tile.setup(Vector2i(0, 0), 0, BoardModel.BONUS_STRIPED_COL, 100.0)
	var overlay: Sprite2D = tile.get_node("BonusOverlay")
	assert_true(overlay.visible)
	assert_eq(overlay.frame, 0)
	assert_eq(overlay.rotation_degrees, 90.0)

func test_reset_hides_bonus_and_restores_scale():
	tile.setup(Vector2i(0, 0), 0, BoardModel.BONUS_BOMB, 100.0)
	tile.scale = Vector2.ZERO
	tile.reset()
	assert_false(tile.get_node("BonusOverlay").visible)
	assert_eq(tile.scale, Vector2.ONE)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"/c/Program Files/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_tile.gd -gexit`
Expected: FAIL — `tile.tscn` does not exist.

- [ ] **Step 3: Create `scripts/board/tile.gd`**

```gdscript
class_name Tile
extends Node2D

@onready var sprite: Sprite2D = $Sprite
@onready var bonus_overlay: Sprite2D = $BonusOverlay

var cell: Vector2i
var tile_type: int = -1

func setup(p_cell: Vector2i, p_type: int, bonus_kind: String, cell_size: float) -> void:
	cell = p_cell
	tile_type = p_type
	position = Vector2(cell.x, cell.y) * cell_size
	sprite.frame = p_type
	bonus_overlay.rotation_degrees = 0.0
	match bonus_kind:
		BoardModel.BONUS_NONE:
			bonus_overlay.visible = false
		BoardModel.BONUS_BOMB:
			bonus_overlay.visible = true
			bonus_overlay.frame = 1
		BoardModel.BONUS_STRIPED_ROW:
			bonus_overlay.visible = true
			bonus_overlay.frame = 0
		BoardModel.BONUS_STRIPED_COL:
			bonus_overlay.visible = true
			bonus_overlay.frame = 0
			bonus_overlay.rotation_degrees = 90.0

func reset() -> void:
	tile_type = -1
	bonus_overlay.visible = false
	scale = Vector2.ONE
	modulate = Color.WHITE

func animate_move_to(target_cell: Vector2i, cell_size: float, duration: float = 0.2) -> void:
	cell = target_cell
	var tween := create_tween()
	tween.tween_property(self, "position", Vector2(target_cell.x, target_cell.y) * cell_size, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func animate_clear(duration: float = 0.15) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

func animate_spawn(duration: float = 0.15) -> void:
	scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
```

- [ ] **Step 4: Create `scenes/board/tile.tscn`**

Build in the editor (or hand-author) as: root `Node2D` named `Tile` with script `res://scripts/board/tile.gd`, one child `Sprite2D` named `Sprite` with `texture = res://assets/sprites/board/tiles.png`, `hframes = 6`, and one child `Sprite2D` named `BonusOverlay` with `texture = res://assets/sprites/board/bonus_overlay.png`, `hframes = 2`, `visible = false`.

```ini
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/board/tile.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/sprites/board/tiles.png" id="2"]
[ext_resource type="Texture2D" path="res://assets/sprites/board/bonus_overlay.png" id="3"]

[node name="Tile" type="Node2D"]
script = ExtResource("1")

[node name="Sprite" type="Sprite2D" parent="."]
texture = ExtResource("2")
hframes = 6

[node name="BonusOverlay" type="Sprite2D" parent="."]
texture = ExtResource("3")
hframes = 2
visible = false
```

- [ ] **Step 5: Run test to verify it passes**

Run: `"/c/Program Files/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_tile.gd -gexit`
Expected: PASS (4 tests)

- [ ] **Step 6: Commit**

```bash
git add scripts/board/tile.gd scenes/board/tile.tscn tests/unit/test_tile.gd
git commit -m "Add Tile scene with pooled setup/reset and Tween animations"
```

---

### Task 11: BoardView scene — render board and animate cascades

**Files:**
- Create: `scenes/board/board_view.tscn`
- Create: `scripts/board/board_view.gd`
- Test: `tests/unit/test_board_view_render.gd`

**Interfaces:**
- Consumes: `BoardModel` (Task 4-9), `Tile` (Task 10), `EventBus` autoload signals (already exist).
- Produces: `class_name BoardView extends Node2D`, method `start_level(level_data: LevelData) -> void`. Const `CELL_SIZE: float`.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/unit/test_board_view_render.gd
extends GutTest

func test_start_level_renders_one_tile_per_cell():
	var view: BoardView = preload("res://scenes/board/board_view.tscn").instantiate()
	add_child_autofree(view)
	var level := LevelData.new()
	level.grid_width = 4
	level.grid_height = 4
	level.tile_type_count = 6
	level.move_limit = 20
	level.objective = 1000
	view.start_level(level)
	var visible_tiles := 0
	for child in view.get_children():
		if child is Tile and child.visible:
			visible_tiles += 1
	assert_eq(visible_tiles, 16)

func test_rendered_tile_type_matches_model():
	var view: BoardView = preload("res://scenes/board/board_view.tscn").instantiate()
	add_child_autofree(view)
	var level := LevelData.new()
	level.grid_width = 3
	level.grid_height = 3
	level.tile_type_count = 6
	level.move_limit = 20
	level.objective = 1000
	view.start_level(level)
	for child in view.get_children():
		if child is Tile and child.visible:
			assert_eq(child.tile_type, view.model.get_tile_type(child.cell))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"/c/Program Files/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_board_view_render.gd -gexit`
Expected: FAIL — `board_view.tscn` does not exist.

- [ ] **Step 3: Create `scripts/board/board_view.gd`**

```gdscript
class_name BoardView
extends Node2D

const CELL_SIZE := 120.0
const TILE_SCENE: PackedScene = preload("res://scenes/board/tile.tscn")

var model: BoardModel
var _tile_pool: Array = []
var _cell_to_tile: Dictionary = {}

func start_level(level_data: LevelData) -> void:
	model = BoardModel.new(level_data)
	model.cascade_step.connect(_on_cascade_step)
	model.swap_rejected.connect(_on_swap_rejected)
	model.move_consumed.connect(func(remaining: int): EventBus.move_used.emit(remaining))
	model.level_completed.connect(func(): EventBus.level_completed.emit(level_data.level_id, 3))
	model.level_failed.connect(func(): EventBus.level_failed.emit(level_data.level_id))
	model.board_reshuffled.connect(func(): EventBus.board_shuffled.emit())
	EventBus.level_started.emit(level_data.level_id)
	_render_initial_board()

func _render_initial_board() -> void:
	for x in model.width:
		for y in model.height:
			var cell := Vector2i(x, y)
			var tile := _get_pooled_tile()
			tile.setup(cell, model.get_tile_type(cell), model.get_bonus_kind(cell), CELL_SIZE)
			tile.animate_spawn()
			_cell_to_tile[cell] = tile

func _get_pooled_tile() -> Tile:
	for tile in _tile_pool:
		if not tile.visible:
			tile.visible = true
			return tile
	var tile: Tile = TILE_SCENE.instantiate()
	add_child(tile)
	_tile_pool.append(tile)
	return tile

func _on_cascade_step(step: Dictionary) -> void:
	for match_info in step["matches"]:
		EventBus.tiles_matched.emit(match_info["type"], match_info["count"], match_info["position"])
	for cell in step["cleared"]:
		var tile: Tile = _cell_to_tile.get(cell)
		if tile:
			tile.animate_clear()
			tile.reset()
			tile.visible = false
			_cell_to_tile.erase(cell)
	for fall in step["falls"]:
		var tile: Tile = _cell_to_tile.get(fall["from"])
		if tile:
			_cell_to_tile.erase(fall["from"])
			_cell_to_tile[fall["to"]] = tile
			tile.animate_move_to(fall["to"], CELL_SIZE)
	for refill in step["refills"]:
		var tile := _get_pooled_tile()
		tile.setup(refill["pos"], refill["type"], "", CELL_SIZE)
		tile.animate_spawn()
		_cell_to_tile[refill["pos"]] = tile
	for spawn in step["bonuses"]:
		var tile: Tile = _cell_to_tile.get(spawn["pos"])
		if tile:
			tile.setup(spawn["pos"], model.get_tile_type(spawn["pos"]), spawn["kind"], CELL_SIZE)

func _on_swap_rejected(a: Vector2i, b: Vector2i) -> void:
	for cell in [a, b]:
		var tile: Tile = _cell_to_tile.get(cell)
		if tile:
			tile.animate_move_to(cell, CELL_SIZE)
```

- [ ] **Step 4: Create `scenes/board/board_view.tscn`**

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/board/board_view.gd" id="1"]

[node name="BoardView" type="Node2D"]
script = ExtResource("1")
```

- [ ] **Step 5: Run test to verify it passes**

Run: `"/c/Program Files/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_board_view_render.gd -gexit`
Expected: PASS (2 tests)

- [ ] **Step 6: Commit**

```bash
git add scripts/board/board_view.gd scenes/board/board_view.tscn tests/unit/test_board_view_render.gd
git commit -m "Add BoardView: render board from model and animate cascade steps"
```

---

### Task 12: Input handling — drag and tap

**Files:**
- Modify: `scripts/board/board_view.gd`

**Interfaces:**
- Adds `_unhandled_input(event: InputEvent) -> void` and helper methods to `BoardView`, converging on the existing `model.attempt_swap(a, b)`.

- [ ] **Step 1: Add input state and handling to `scripts/board/board_view.gd`**

Add these fields near the top of the class (after `_cell_to_tile`):

```gdscript
var _selected_cell := Vector2i(-1, -1)
var _drag_start_cell := Vector2i(-1, -1)
var _drag_start_pos := Vector2.ZERO
const DRAG_THRESHOLD := 30.0
```

Add these methods:

```gdscript
func _cell_at_position(local_pos: Vector2) -> Vector2i:
	return Vector2i(int(local_pos.x / CELL_SIZE), int(local_pos.y / CELL_SIZE))

func _unhandled_input(event: InputEvent) -> void:
	if model == null or model.is_busy:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pressed: bool = event.is_pressed() if event is InputEventScreenTouch else (event as InputEventMouseButton).pressed
		var pos: Vector2 = event.position if event is InputEventScreenTouch else (event as InputEventMouseButton).position
		var cell := _cell_at_position(to_local(pos))
		if not model.is_in_bounds(cell):
			return
		if pressed:
			_drag_start_cell = cell
			_drag_start_pos = pos
		else:
			_handle_release(cell)
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if _drag_start_cell == Vector2i(-1, -1):
			return
		var pos: Vector2 = event.position if event is InputEventScreenDrag else (event as InputEventMouseMotion).position
		var delta: Vector2 = pos - _drag_start_pos
		if delta.length() >= DRAG_THRESHOLD:
			var dir := Vector2i(0, 0)
			if absf(delta.x) > absf(delta.y):
				dir = Vector2i(1 if delta.x > 0 else -1, 0)
			else:
				dir = Vector2i(0, 1 if delta.y > 0 else -1)
			var start := _drag_start_cell
			var target := start + dir
			_drag_start_cell = Vector2i(-1, -1)
			_selected_cell = Vector2i(-1, -1)
			model.attempt_swap(start, target)

func _handle_release(cell: Vector2i) -> void:
	var start := _drag_start_cell
	_drag_start_cell = Vector2i(-1, -1)
	if start != cell:
		return
	if _selected_cell == Vector2i(-1, -1):
		_selected_cell = cell
		return
	if _selected_cell == cell:
		_selected_cell = Vector2i(-1, -1)
		return
	var dist := absi(_selected_cell.x - cell.x) + absi(_selected_cell.y - cell.y)
	if dist == 1:
		model.attempt_swap(_selected_cell, cell)
		_selected_cell = Vector2i(-1, -1)
	else:
		_selected_cell = cell
```

- [ ] **Step 2: Run the full automated test suite to confirm no regressions**

Run: `"/c/Program Files/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: all tests still pass (input handling has no automated test — it's exercised manually in Task 14).

- [ ] **Step 3: Commit**

```bash
git add scripts/board/board_view.gd
git commit -m "Add drag and tap input handling to BoardView"
```

---

### Task 13: EventBus wiring, win/lose overlay, and the playable screen

**Files:**
- Create: `scenes/ui/level_result_overlay.tscn`
- Create: `scripts/ui/level_result_overlay.gd`
- Create: `scenes/screens/game_board_screen.tscn`
- Create: `scripts/ui/game_board_screen.gd`
- Modify: `project.godot` (`run/main_scene`)

**Interfaces:**
- Produces: `class_name LevelResultOverlay extends Control` with `show_result(won: bool) -> void`, `signal restart_requested`. `GameBoardScreen` instantiates `BoardView`, calls `start_level(preload("res://resources/levels/level_001.tres"))`, and shows the overlay on `EventBus.level_completed`/`level_failed`.

- [ ] **Step 1: Create `scripts/ui/level_result_overlay.gd`**

```gdscript
class_name LevelResultOverlay
extends Control

signal restart_requested

@onready var _label: Label = $PanelContainer/VBoxContainer/ResultLabel
@onready var _restart_button: Button = $PanelContainer/VBoxContainer/RestartButton

func _ready() -> void:
	hide()
	_restart_button.pressed.connect(func(): restart_requested.emit())

func show_result(won: bool) -> void:
	_label.text = "Cleared!" if won else "Failed"
	show()
```

- [ ] **Step 2: Create `scenes/ui/level_result_overlay.tscn`**

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/level_result_overlay.gd" id="1"]

[node name="LevelResultOverlay" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")

[node name="PanelContainer" type="PanelContainer" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
grow_horizontal = 2
grow_vertical = 2

[node name="VBoxContainer" type="VBoxContainer" parent="PanelContainer"]
layout_mode = 2

[node name="ResultLabel" type="Label" parent="PanelContainer/VBoxContainer"]
layout_mode = 2
horizontal_alignment = 1
text = "Cleared!"

[node name="RestartButton" type="Button" parent="PanelContainer/VBoxContainer"]
layout_mode = 2
text = "Restart"
```

- [ ] **Step 3: Create `scripts/ui/game_board_screen.gd`**

```gdscript
extends Node2D

const LEVEL_001: LevelData = preload("res://resources/levels/level_001.tres")

@onready var _board_view: BoardView = $BoardView
@onready var _overlay: LevelResultOverlay = $LevelResultOverlay

func _ready() -> void:
	EventBus.level_completed.connect(func(_id, _stars): _overlay.show_result(true))
	EventBus.level_failed.connect(func(_id): _overlay.show_result(false))
	_overlay.restart_requested.connect(func(): GameManager.change_scene("res://scenes/screens/game_board_screen.tscn"))
	_board_view.start_level(LEVEL_001)
```

- [ ] **Step 4: Create `scenes/screens/game_board_screen.tscn`**

```ini
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/ui/game_board_screen.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/board/board_view.tscn" id="2"]
[ext_resource type="PackedScene" path="res://scenes/ui/level_result_overlay.tscn" id="3"]

[node name="GameBoardScreen" type="Node2D"]
script = ExtResource("1")

[node name="BoardView" parent="." instance=ExtResource("2")]

[node name="LevelResultOverlay" parent="." instance=ExtResource("3")]
```

- [ ] **Step 5: Point the project at the new screen**

In `project.godot`, change:

```ini
run/main_scene="res://scenes/screens/main_menu.tscn"
```

to:

```ini
run/main_scene="res://scenes/screens/game_board_screen.tscn"
```

- [ ] **Step 6: Run the full automated test suite to confirm no regressions**

Run: `"/c/Program Files/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: all tests still pass.

- [ ] **Step 7: Commit**

```bash
git add scenes/ui/level_result_overlay.tscn scripts/ui/level_result_overlay.gd scenes/screens/game_board_screen.tscn scripts/ui/game_board_screen.gd project.godot
git commit -m "Wire EventBus, win/lose overlay, and playable game board screen"
```

---

### Task 14: Manual end-to-end verification

**Files:** none (verification only)

- [ ] **Step 1: Launch the project in the editor**

Use the `run` skill (or open the project in Godot and press F6/Play) to launch `scenes/screens/game_board_screen.tscn`.

- [ ] **Step 2: Verify basic rendering**

Confirm an 8×8 grid of tile icons renders, filling the portrait viewport reasonably, with no visible empty cells and no two adjacent tiles of the same type already matched.

- [ ] **Step 3: Verify drag-swap**

Drag a tile into an adjacent one that produces a match. Confirm: the swapped tiles animate into place, matched tiles scale out, tiles above fall to fill gaps, new tiles spawn from the top, and the move counter (check via a temporary print of `moves_remaining` if no UI counter exists yet) decreases by 1.

- [ ] **Step 4: Verify tap-select**

Tap one tile (it should visually stay in place — no dedicated highlight sprite exists yet, so confirm via behavior: tapping a second, adjacent tile performs a swap) then tap an adjacent tile to confirm the swap fires.

- [ ] **Step 5: Verify an invalid swap is rejected**

Drag a tile in a direction that does not create a match. Confirm it animates back to its original position and the move counter does not decrease.

- [ ] **Step 6: Verify a 4-match spawns a bonus tile**

Set up or play until a 4-in-a-row match occurs. Confirm a tile with the striped overlay appears at the resulting position, and that matching it into a later run clears its full row or column.

- [ ] **Step 7: Verify win/lose overlay**

Play until either the score reaches 1000 (the "Cleared!" overlay should appear immediately, even mid-move) or moves run out below 1000 score (the "Failed" overlay should appear). Confirm the Restart button reloads the board.

- [ ] **Step 8: Note any visual/gameplay issues as follow-up, not blocking**

This slice intentionally has no move counter or score UI (only internal state) — note that as expected/known, not a bug, since the spec scoped UI to the win/lose overlay only.
