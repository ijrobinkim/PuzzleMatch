extends Node
## Music and SFX playback with independent volume buses.

@onready var _music_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var _sfx_players: Array[AudioStreamPlayer] = []

const SFX_POOL_SIZE := 8


func _ready() -> void:
	_music_player.bus = "Music"
	add_child(_music_player)
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)


func play_music(stream: AudioStream, fade_in: bool = true) -> void:
	_music_player.stream = stream
	_music_player.play()


func play_sfx(stream: AudioStream) -> void:
	for p in _sfx_players:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	# Pool exhausted; steal the first player.
	_sfx_players[0].stream = stream
	_sfx_players[0].play()


func set_music_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(linear))


func set_sfx_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(linear))
