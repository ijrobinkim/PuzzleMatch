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
	assert_false(tile.bonus_overlay.visible)

func test_setup_with_bomb_bonus_shows_overlay_frame_1():
	tile.setup(Vector2i(0, 0), 0, BoardModel.BONUS_BOMB, 100.0)
	var overlay: Sprite2D = tile.bonus_overlay
	assert_true(overlay.visible)
	assert_not_null(overlay.texture)

func test_setup_with_striped_col_rotates_overlay_90_degrees():
	tile.setup(Vector2i(0, 0), 0, BoardModel.BONUS_ROCKET_V, 100.0)
	var overlay: Sprite2D = tile.bonus_overlay
	assert_true(overlay.visible)
	assert_not_null(overlay.texture)

func test_reset_hides_bonus_and_restores_scale():
	tile.setup(Vector2i(0, 0), 0, BoardModel.BONUS_BOMB, 100.0)
	tile.scale = Vector2.ZERO
	tile.reset()
	assert_false(tile.bonus_overlay.visible)
	assert_eq(tile.scale, Vector2.ONE)
