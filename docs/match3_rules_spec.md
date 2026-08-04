# Royal Kingdom Style Match-3 Game Rules & Logic Specification

## 1. Overview
This specification defines the core match-3 puzzle mechanics for `RoyalPuzzle`, benchmarked directly against **Royal Kingdom** (Dream Games). 

---

## 2. Grid & Tile Definitions
- **Grid Layout**: 2D Grid of size `width x height`.
- **Tile Types**: Colors indexed from `0` to `tile_type_count - 1`. Empty tiles are denoted as `-1` (`EMPTY_TYPE`).
- **Special Tiles (Bonuses)**:
  - `BONUS_NONE` (`""`): Normal color tile.
  - `BONUS_ROCKET_H` (`"rocket_h"`): Clears 1 full horizontal row.
  - `BONUS_ROCKET_V` (`"rocket_v"`): Clears 1 full vertical column.
  - `BONUS_SPINNER` (`"spinner"`): Clears surrounding 4 cross cells + launches a propeller to clear 1 target tile on board.
  - `BONUS_BOMB` (`"bomb"`): Clears a 3x3 area centered at the tile.
  - `BONUS_ELECTRO_BALL` (`"electro_ball"`): Clears all tiles of a targeted color on the board.

---

## 3. Match Detection & Special Tile Creation Rules
Matches are calculated by grouping connected runs of the same color tile.

### Creation Hierarchy & Priority:
1. **5 in a straight line** $\rightarrow$ **Electro Ball** (`BONUS_ELECTRO_BALL`)
2. **5+ in L, T, or + shape** $\rightarrow$ **Bomb / TNT** (`BONUS_BOMB`)
3. **4 in a 2x2 square** $\rightarrow$ **Spinner / Propeller** (`BONUS_SPINNER`)
4. **4 in a straight line**:
   - Horizontal match / swap $\rightarrow$ **Horizontal Rocket** (`BONUS_ROCKET_H`)
   - Vertical match / swap $\rightarrow$ **Vertical Rocket** (`BONUS_ROCKET_V`)
5. **3 in a straight line** $\rightarrow$ Normal match (Clears tiles, no bonus created).

### Special Tile Spawn Location:
- **Player Swap**: The created bonus tile spawns at the cell touched/moved by the player during the swap.
- **Cascade (Falling)**: The created bonus tile spawns at the intersection cell (for L/T shapes) or center cell.

---

## 4. Special Tile Activation Rules (Single Activation / Tap)
Players can tap a special tile directly or move it into a match to activate it:
1. **Rocket**: Clears the entire row (`rocket_h`) or column (`rocket_v`).
2. **Bomb**: Clears a 3x3 grid around the bomb location.
3. **Spinner**: Clears 4 adjacent cross cells (`up`, `down`, `left`, `right`), then flies to target and clear 1 random/objective tile.
4. **Electro Ball**: Selects the most abundant color tile on the board and clears all tiles of that color.

---

## 5. Special Tile Combination Rules (Swapping 2 Special Tiles Together)
Swapping two adjacent special tiles triggers a powerful combination effect regardless of their color:

| Special Tile A | Special Tile B | Combination Effect |
| :--- | :--- | :--- |
| **Rocket** | **Rocket** | Clears 1 full row **AND** 1 full column in a '+' cross shape centered at target swap cell. |
| **Rocket** | **Bomb** | Clears **3 full rows AND 3 full columns** in a large cross shape centered at target swap cell. |
| **Bomb** | **Bomb** | Clears a **5x5 grid area** (radius 2) centered at target swap cell. |
| **Spinner** | **Spinner** | Spawns **3 Spinners** that launch simultaneously to hit 3 target tiles. |
| **Spinner** | **Rocket** | Spinner flies to target tile and triggers a **Rocket cross (row + col clear)** at the target location. |
| **Spinner** | **Bomb** | Spinner flies to target tile and triggers a **Bomb 3x3 explosion** at the target location. |
| **Electro Ball** | **Electro Ball** | Clears the **ENTIRE BOARD** (1 layer clear on all cells). |
| **Electro Ball** | **Rocket / Bomb / Spinner** | Transforms **ALL tiles of the most common color** into copies of that special tile, then detonates all of them simultaneously! |
| **Electro Ball** | **Normal Color Tile** | Transforms **ALL tiles of that color** into Rockets/Spinners and detonates them! |

---

## 6. Cascade, Gravity, and Reshuffling
- **Cascade Cycle**:
  1. Clear matched/activated cells.
  2. Spawn any newly formed special tiles at designated spawn positions.
  3. Apply gravity (tiles drop vertically to fill empty spaces).
  4. Refill top empty cells with random tiles.
  5. Repeat match detection until no more matches or activations occur.
- **Valid Move Detection**:
  - Valid moves include: 3-color match swaps, any adjacent special tile swap, or single special tile tap.
- **Reshuffling**:
  - If no valid moves exist on the board, automatically shuffle tile types until at least 1 valid move exists without creating immediate matches.
