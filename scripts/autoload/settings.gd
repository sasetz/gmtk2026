extends Node
## Audio levels for the session. Volumes are stored LINEAR (0..1, what a slider
## wants) and converted to dB on the way to the AudioServer — a linear slider
## mapped straight to dB feels wrong (all the useful range bunches at the top).
## Buses come from res://default_bus_layout.tres (Master / Music / SFX).
##
## Not persisted: this is a browser game, so settings just live for the session.

## Emitted when a volume changes, so open UI can refresh itself.
signal changed

var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
## Screen shake is the one effect most likely to bother people; Juice.shake
## checks this before doing anything.
var screen_shake: bool = true


func _ready() -> void:
	apply()


func set_screen_shake(on: bool) -> void:
	screen_shake = on
	changed.emit()


func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_bus("Master", master_volume)
	changed.emit()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_bus("Music", music_volume)
	changed.emit()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_bus("SFX", sfx_volume)
	changed.emit()


func apply() -> void:
	_apply_bus("Master", master_volume)
	_apply_bus("Music", music_volume)
	_apply_bus("SFX", sfx_volume)


## Linear 0..1 → dB, muting outright at zero (linear_to_db(0) is -inf).
func _apply_bus(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var silent: bool = linear <= 0.001
	AudioServer.set_bus_mute(idx, silent)
	AudioServer.set_bus_volume_db(idx, -80.0 if silent else linear_to_db(linear))
