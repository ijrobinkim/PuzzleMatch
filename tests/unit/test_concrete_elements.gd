# tests/unit/test_concrete_elements.gd
extends GutTest

func test_box_snow_ivy_column_birdhouse_initialization():
	var box = load("res://scripts/elements/concrete/box_element.gd").new()
	assert_eq(box.element_id, "box")
	assert_true(box.is_obstacle)
	box.free()
	
	var snow = load("res://scripts/elements/concrete/snow_element.gd").new()
	assert_eq(snow.element_id, "snow")
	assert_false(snow.is_obstacle) # Snow is a bottom board layer
	snow.free()
	
	var ivy = load("res://scripts/elements/concrete/ivy_element.gd").new()
	assert_eq(ivy.element_id, "ivy")
	ivy.free()
	
	var column = load("res://scripts/elements/concrete/column_element.gd").new()
	assert_eq(column.element_id, "column")
	assert_false(column.allows_falling)
	column.free()
	
	var birdhouse = load("res://scripts/elements/concrete/birdhouse_element.gd").new()
	assert_eq(birdhouse.element_id, "birdhouse")
	assert_eq(birdhouse.item_to_spawn, "bird")
	birdhouse.free()
