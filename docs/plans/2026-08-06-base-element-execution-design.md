# BaseElement TDD Execution Design

> **Date**: 2026-08-06
> **Topic**: Royal Kingdom BaseElement Core Framework & TDD Execution Design
> **Target Project**: `RoyalPuzzle` (Godot 4 Engine Match-3 Core)

---

## 1. Executive Summary

This document specifies the exact architecture, data model, signal contract, and TDD (Test-Driven Development) verification plan for `BaseElement`. `BaseElement` is the foundation Node2D class for all 35+ Royal Kingdom match-3 level elements/obstacles (Boxes, Columns, Ivy, Stone Walls, Dragon Boxes, etc.).

---

## 2. Architecture & Class Definition

### Class: `BaseElement` (`res://scripts/elements/base_element.gd`)
- **Inherits**: `Node2D`
- **Class Name**: `BaseElement`

### Exported Properties & State
- `@export var element_id: String = ""` - Identifier for element type (e.g., `"box"`, `"stone_wall"`).
- `@export var max_health: int = 1` - Total hits required to destroy the element.
- `@export var is_obstacle: bool = true` - Whether it blocks normal match-3 tile movement.
- `@export var allows_falling: bool = false` - Whether items can fall through this element's grid cell.
- `var current_health: int = 1` - Current layer health (initialized to `max_health` in `_ready()`).
- `var grid_position: Vector2i = Vector2i.ZERO` - Board grid coordinates `(x, y)`.

### Signals
- `signal element_damaged(element: BaseElement, current_health: int)`
  - Emitted whenever `take_damage()` is invoked and the element survives.
- `signal element_destroyed(element: BaseElement)`
  - Emitted when `current_health` reaches `0` or less, immediately before `queue_free()`.

### Key Methods
- `_ready() -> void`
  - Initializes `current_health = max_health`.
- `take_damage(amount: int = 1) -> void`
  - Decrements `current_health` by `amount`.
  - Emits `element_damaged(self, current_health)`.
  - If `current_health <= 0`, calls `destroy()`.
- `destroy() -> void`
  - Emits `element_destroyed(self)`.
  - Calls `queue_free()`.

---

## 3. TDD Test Plan (`tests/unit/test_base_element.gd`)

Using **GUT** (Godot Unit Testing framework):

```gdscript
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

---

## 4. Verification Workflow

1. **RED Stage**:
   Create `tests/unit/test_base_element.gd` without `base_element.gd`.
   Execute GUT runner:
   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gtest=tests/unit/test_base_element.gd
   ```
   *Expected Output*: Test failure / compilation error (script file missing).

2. **GREEN Stage**:
   Create `scripts/elements/base_element.gd` with minimal complete implementation.
   Execute GUT runner:
   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gtest=tests/unit/test_base_element.gd
   ```
   *Expected Output*: PASS (0 failures, 2 signal assertions passed).

3. **COMMIT Stage**:
   Commit both files to git repository:
   ```bash
   git add scripts/elements/base_element.gd tests/unit/test_base_element.gd
   git commit -m "feat: add BaseElement class and damage signals"
   ```
