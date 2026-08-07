# tests/unit/test_element_factory.gd
extends GutTest

func test_element_factory_registration_and_creation():
	var factory = load("res://scripts/managers/element_factory.gd").new()
	
	# Test creating unregistered element returns null
	var unknown = factory.create_element("non_existent_element")
	assert_null(unknown)
	
	# Test default built-in elements creation out-of-the-box
	var box_element = factory.create_element("box")
	assert_not_null(box_element)
	assert_true(box_element is BaseElement)
	assert_eq(box_element.element_id, "box")
	box_element.free()
	
	# Register custom element script
	factory.register_element_script("custom_elem", load("res://scripts/elements/base_element.gd"))
	
	var custom_element = factory.create_element("custom_elem")
	assert_not_null(custom_element)
	assert_true(custom_element is BaseElement)
	assert_eq(custom_element.element_id, "custom_elem")
	
	custom_element.free()
	factory.free()

