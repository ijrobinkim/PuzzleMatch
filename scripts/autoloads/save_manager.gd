extends Node
## Persists player progress and settings to user://.

const SAVE_PATH := "user://save_data.json"

var data: Dictionary = {
	"currencies": {"coins": 0, "gems": 0},
	"level_progress": {},
	"renovation_progress": {},
	"settings": {"music_volume": 1.0, "sfx_volume": 1.0},
}


func save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))


func load_data() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		data = parsed
		return true
	return false


func get_currency(currency_id: String) -> int:
	return data.get("currencies", {}).get(currency_id, 0)


func add_currency(currency_id: String, amount: int) -> void:
	if not data.has("currencies"):
		data["currencies"] = {}
	data["currencies"][currency_id] = get_currency(currency_id) + amount
	EventBus.currency_changed.emit(currency_id, data["currencies"][currency_id])
