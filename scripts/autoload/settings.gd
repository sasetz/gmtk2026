extends Node
## Player settings: audio levels and accessibility toggles, persisted to
## user://settings.cfg so they survive a restart (and a web reload).
##
## Volumes are stored LINEAR (0..1) because that's what a slider wants, and
## converted to dB on the way to the AudioServer — a linear slider mapped
## straight to dB feels wrong (all the useful range bunches at the top).
## Buses come from res://default_bus_layout.tres (Master / Music / SFX), so
## audio added later only has to pick the right bus.

const PATH: String = "user://settings.cfg"

## Emitted whenever any setting changes, so open UI can refresh itself.
signal changed

var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 1.0
## Screen shake is the one effect most likely to bother people; Juice.shake
## checks this before doing anything.
var screen_shake: bool = true
## Global VHS tape look (scanlines, chroma split, grain, wobble). ScreenFX owns it.
var vhs_effect: bool = true
## Global fisheye/barrel bulge. Separate toggle — some players are fine with the
## tape grain but not with a warped image.
var fisheye_effect: bool = true
## Global chunky-pixel downsample. Separate toggle because it's the one effect
## that can cost legibility on the smallest text.
var pixelate_effect: bool = true


func _ready() -> void:
	load_settings()
	apply()


# --- mutators (each applies + saves, so callers stay one-liners) -------------

func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_bus("Master", master_volume)
	_touch()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_bus("SFX", sfx_volume)
	_touch()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_bus("Music", music_volume)
	_touch()


func set_screen_shake(on: bool) -> void:
	screen_shake = on
	_touch()


func set_vhs_effect(on: bool) -> void:
	vhs_effect = on
	_touch()


func set_fisheye_effect(on: bool) -> void:
	fisheye_effect = on
	_touch()


func set_pixelate_effect(on: bool) -> void:
	pixelate_effect = on
	_touch()


func _touch() -> void:
	save_settings()
	changed.emit()


# --- persistence ------------------------------------------------------------

func apply() -> void:
	_apply_bus("Master", master_volume)
	_apply_bus("SFX", sfx_volume)
	_apply_bus("Music", music_volume)


## Linear 0..1 → dB, muting outright at zero (linear_to_db(0) is -inf).
func _apply_bus(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var silent: bool = linear <= 0.001
	AudioServer.set_bus_mute(idx, silent)
	AudioServer.set_bus_volume_db(idx, -80.0 if silent else linear_to_db(linear))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("video", "screen_shake", screen_shake)
	cfg.set_value("video", "vhs_effect", vhs_effect)
	cfg.set_value("video", "fisheye_effect", fisheye_effect)
	cfg.set_value("video", "pixelate_effect", pixelate_effect)
	cfg.save(PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return  # first launch — keep the defaults above
	master_volume = clampf(float(cfg.get_value("audio", "master", 1.0)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", 1.0)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music", 1.0)), 0.0, 1.0)
	screen_shake = bool(cfg.get_value("video", "screen_shake", true))
	vhs_effect = bool(cfg.get_value("video", "vhs_effect", true))
	fisheye_effect = bool(cfg.get_value("video", "fisheye_effect", true))
	pixelate_effect = bool(cfg.get_value("video", "pixelate_effect", true))


## Restore factory defaults (the options menu's Reset).
func reset_to_defaults() -> void:
	master_volume = 1.0
	sfx_volume = 1.0
	music_volume = 1.0
	screen_shake = true
	vhs_effect = true
	fisheye_effect = true
	pixelate_effect = true
	apply()
	_touch()
