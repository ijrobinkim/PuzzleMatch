# tests/unit/test_spawner_element.gd
extends GutTest

func test_spawner_element_spawn():
	var spawner = load("res://scripts/elements/spawner_element.gd").new()
	spawner.item_to_spawn = "bird"
	spawner.spawn_count = 2
	
	watch_signals(spawner)
	var items = spawner.spawn_items()
	assert_signal_emitted(spawner, "items_spawned")
	assert_eq(items.size(), 2)
	assert_eq(items[0], "bird")
	
	spawner.free()
