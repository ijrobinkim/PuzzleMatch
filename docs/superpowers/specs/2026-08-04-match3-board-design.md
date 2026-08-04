# Match-3 Board — Design

## Goal

First playable slice of the match-3 board for RoyalPuzzle: swap-based matching with move limit, striped/bomb bonus tiles, and cascading refills. Placeholder art generated via the `sprite-gen` skill.

## Non-Goals (this slice)

- Castle renovation meta loop, currency rewards, `SaveManager` persistence
- Color-bomb ("clear all of one color") bonus tile — deferred, kept easy to add later since it resolves by color instead of position
- Level select / multiple levels — one hardcoded test `LevelData` resource is enough for now
- Full win/lose screens — a minimal Label + restart button overlay is sufficient

## Architecture

Board logic is a plain GDScript data model, fully decoupled from the scene tree, so match detection, cascading, and bonus-tile rules can be unit tested without instantiating nodes. A separate view layer renders that model and owns input.

```
LevelData (Resource)          — grid_width, grid_height, tile_type_count, move_limit, objective
BoardModel (RefCounted)       — grid state, match/cascade/bonus/deadlock logic, no node deps
BoardView (Node2D, board_view.tscn) — subscribes to BoardModel signals, owns Tile pool, handles input
Tile (Node2D, tile.tscn)      — sprite + Tween-driven swap/fall/clear animation, pooled/reused
```

**Files:**
- `scripts/resources/level_data.gd`, `resources/levels/level_001.tres`
- `scripts/board/board_model.gd`
- `scripts/board/board_view.gd`, `scenes/board/board_view.tscn`
- `scripts/board/tile.gd`, `scenes/board/tile.tscn`

**Data flow:** `BoardView` (input) → `BoardModel.attempt_swap()` (validates, mutates grid, resolves cascade) → signals → `BoardView` (plays animations) → on settle, `EventBus.tiles_matched` / `move_used` / `level_completed` / `level_failed` (already stubbed) → `GameManager` handles level transition.

## Gameplay Logic

**Match detection:** after a swap or a cascade refill, scan every cell for horizontal/vertical runs of 3+ identical tile types. Overlapping runs merge into one match group.

**Bonus tile rules:**
| Match shape | Result |
|---|---|
| 3 in a line | Cleared, no bonus |
| 4 in a line | Striped tile (clears its row or column when triggered) |
| 5+ in a line, or L/T shape | Bomb tile (clears surrounding 3×3 when triggered) |

**Cascade:** cleared/triggered cells → columns fall to fill gaps → empty cells refill from the top with random tile types → re-scan the whole board → repeat until no matches remain. Input is locked (`is_busy`) for the whole cascade.

**Move limit:** a swap only consumes a move if it produces a match; invalid swaps snap back with no cost. `LevelData.objective` is a `target_score: int`; each cleared tile (via `EventBus.tiles_matched`) adds a fixed point value to the running score. After every cascade settles, check score against target: if met, `level_completed` fires immediately regardless of moves remaining. Otherwise, once `moves_remaining` hits 0, `level_failed` fires.

**Deadlock handling:** after a cascade settles, if no possible swap on the board would produce a match, reshuffle the board without consuming a move. Cheap to implement, and without it the player can get permanently stuck — included in this slice.

## Input Handling

Both interaction styles are supported and converge on the same `BoardModel.attempt_swap(a, b)` call, so the model stays agnostic of input scheme:

- **Drag:** press on a tile records the start cell; once drag distance crosses a threshold in one of the 4 directions, immediately attempt a swap with that adjacent cell (no need to wait for release).
- **Tap:** press-release with no drag selects the tile (highlighted). Tapping a second, adjacent tile attempts a swap; tapping a non-adjacent tile just moves the selection.

All input is ignored while `is_busy` (cascade animating).

## Level Flow

1. Board scene loads `LevelData` (hardcoded `level_001.tres` for this slice).
2. `BoardModel` initializes a `grid_width`×`grid_height` grid from `tile_type_count` types, reshuffling if the initial layout already contains a match.
3. `EventBus.level_started` emits; `moves_remaining = LevelData.move_limit`, `score = 0`.
4. Each `EventBus.tiles_matched` adds to `score`; after every cascade settles, `score` is checked against `LevelData.objective` (see Move Limit above) to decide `level_completed`/`level_failed`.
5. `level_completed`/`level_failed` shows a minimal overlay (Label + restart button). No scene beyond the board is required for this slice.

`SaveManager` is untouched — there's no reward loop yet to persist.

## Testing

Because `BoardModel` has no node dependencies, match detection, cascade resolution, bonus-tile creation, move-limit accounting, and deadlock detection are covered with GDScript unit tests (GUT) against the model directly, without instantiating scenes. Tests are written alongside each piece of model logic during implementation.

## Asset Plan

`sprite-gen` skill generates: 6 tile-type icons, and 2 bonus overlay icons (striped, bomb). No particle VFX needed — clear/fall/swap feedback is Tween-driven (scale/fade), not a separate asset.
