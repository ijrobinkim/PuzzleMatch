# res://scripts/elements/spawner_element.gd
class_name SpawnerElement
extends BaseElement

signal items_spawned(spawner: SpawnerElement, item_id: String, count: int)

@export var item_to_spawn: String = ""
@export var spawn_count: int = 1

func spawn_items() -> Array[String]:
	var result: Array[String] = []
	for i in range(spawn_count):
		result.append(item_to_spawn)
	items_spawned.emit(self, item_to_spawn, spawn_count)
	return result
