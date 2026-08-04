extends Node
## Decoupled signal relay. Systems emit here; listeners connect here.
## Board and meta (kingdom renovation) systems never reference each other directly.

signal tiles_matched(tile_type: int, count: int, board_position: Vector2i)
signal board_shuffled
signal move_used(moves_remaining: int)
signal level_started(level_id: String)
signal level_completed(level_id: String, stars: int)
signal level_failed(level_id: String)

signal currency_changed(currency_id: String, new_amount: int)
signal renovation_task_completed(task_id: String)

signal log_emitted(message: String, category: String)
