# Advanced Dynamic Elements (Steam Bomb & Dragon Box) Implementation Plan

> **For Antigravity:** REQUIRED WORKFLOW: Use `.agent/workflows/execute-plan.md` to execute this plan in single-flow mode.

**Goal:** Implement Sprint 2 advanced Royal Kingdom dynamic elements (`SteamBombElement` turn-countdown bomb and `DragonBoxElement` 2-layer moving nest) in Godot 4 GDScript.

---

### Task 10: Create `SteamBombElement` (Turn Countdown Bomb) and Unit Test

**Files:**
- Create: `scripts/elements/concrete/steam_bomb_element.gd`
- Test: `tests/unit/test_steam_bomb_element.gd`

**Step 1: Write failing unit test for `SteamBombElement`**

```gdscript
# tests/unit/test_steam_bomb_element.gd
extends GutTest

func test_steam_bomb_countdown():
	var bomb = load("res://scripts/elements/concrete/steam_bomb_element.gd").new()
	bomb.turns_remaining = 3
	bomb.max_health = 1
	bomb._ready()
	
	watch_signals(bomb)
	bomb.on_turn_passed()
	assert_eq(bomb.turns_remaining, 2)
	assert_signal_emitted(bomb, "countdown_updated")
	
	bomb.on_turn_passed()
	bomb.on_turn_passed()
	assert_signal_emitted(bomb, "bomb_exploded")
	
	bomb.free()
```

**Step 2: Run test to verify it fails (RED)**

**Step 3: Write implementation for `SteamBombElement` (GREEN)**

**Step 4: Run test to verify it passes (GREEN)**

**Step 5: Commit**

---

### Task 11: Create `DragonBoxElement` (2-Layer Moving Nest) and Unit Test

**Files:**
- Create: `scripts/elements/concrete/dragon_box_element.gd`
- Test: `tests/unit/test_dragon_box_element.gd`

**Step 1: Write failing unit test for `DragonBoxElement`**

```gdscript
# tests/unit/test_dragon_box_element.gd
extends GutTest

func test_dragon_box_nest_stage_and_movement():
	var dragon_box = load("res://scripts/elements/concrete/dragon_box_element.gd").new()
	dragon_box.max_health = 3
	dragon_box._ready()
	
	watch_signals(dragon_box)
	dragon_box.take_damage(1)
	assert_signal_emitted(dragon_box, "nest_relocated")
	assert_eq(dragon_box.current_health, 2)
	
	dragon_box.free()
```

**Step 2: Run test to verify it fails (RED)**

**Step 3: Write implementation for `DragonBoxElement` (GREEN)**

**Step 4: Run test to verify it passes (GREEN)**

**Step 5: Commit**
