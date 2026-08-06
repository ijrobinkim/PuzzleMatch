# GameBoardScreenTest (Box Half-Filled Board Test Screen) Design Document

## 1. Overview
`GameBoardScreenTest` is a specialized test screen based on `GameBoardScreen`. It initializes an 8x8 match-3 puzzle board with the top 4 rows (32 out of 64 cells) pre-filled with `box` obstacle elements. It includes UI action buttons for testing match-3 damage propagation, special item creation/triggering, turn passing, and objective win/loss condition flows.

## 2. Architecture & Components

### 2.1 Scene Structure (`scenes/screens/game_board_screen_test.tscn`)
- `GameBoardScreenTest` (Node2D, attached to `res://scripts/ui/game_board_screen_test.gd`)
  - `BoardView` (Instance of `res://scenes/board/board_view.tscn`)
  - `GameHUD` (Instance of `res://scenes/ui/game_hud.tscn`)
  - `LevelResultOverlay` (Instance of `res://scenes/ui/level_result_overlay.tscn`)
  - `TestControlCanvas` (CanvasLayer)
    - `TestPanel` (Panel / HBoxContainer at top of screen)
      - `DamageAllButton` (Button: "💥 상자 피격")
      - `PassTurnButton` (Button: "⏳ 턴 경과")
      - `RestartButton` (Button: "🔄 다시 시작")
      - `SpawnSpecialsButton` (Button: "💣 특수 아이템 생성")
      - `StatusLabel` (Label: Current test state log)

### 2.2 Controller Logic (`scripts/ui/game_board_screen_test.gd`)
1. **Level Initialization**:
   - Construct runtime `LevelData` instance (8x8 grid, 30 moves, 5 tile types).
   - Set target objectives: `target_objectives = {"box": 32}`.
   - Populate `initial_elements`: Array of 32 dictionaries `{"x": x, "y": y, "id": "box"}` for `x in 0..7` and `y in 0..3`.
2. **Board centering & cover mask setup**:
   - Reuses `_setup_covers()` and `_center_board()` logic from `GameBoardScreen`.
3. **Signal Connections**:
   - Connect HUD and Test Canvas button signals to test actions.
   - Listen to `EventBus.level_completed` and `EventBus.level_failed` to display `LevelResultOverlay`.

## 3. Test Functionality Coverage
- **Adjacent Match Damage**: Matching tiles adjacent to box obstacles reduces box HP and removes them when HP reach 0.
- **Special Item Impact**: Rocket, Bomb, and Spinner explosions properly damage box obstacles in their blast radius.
- **Objective Tracking**: Destroying boxes updates objective counter in `GameHUD` and triggers `level_completed` signal upon reaching 0 remaining boxes.
- **Manual Debug Controls**: Buttons allow forcing 1 damage to all active boxes, advancing turns, or restarting the level.

## 4. File Deliverables
1. `scenes/screens/game_board_screen_test.tscn`
2. `scripts/ui/game_board_screen_test.gd`
3. `tests/unit/test_game_board_screen_test.gd`
