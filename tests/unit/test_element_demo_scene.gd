# tests/unit/test_element_demo_scene.gd
extends GutTest

func test_element_demo_scene_instantiation():
	var scene: PackedScene = load("res://scenes/screens/element_test_demo.tscn")
	assert_not_null(scene)
	var demo = scene.instantiate()
	assert_not_null(demo)
	add_child(demo)
	assert_eq(demo.elements.size(), 7)
	demo.free()

