extends Control
## The settings screen: audio levels + the screen-shake toggle.
##
## Built as a self-contained OVERLAY with a `closed` signal rather than a
## destination scene, so the exact same node works from the main menu and from
## the pause menu (where it must keep running while the tree is paused).
## Every change writes through to Settings immediately — there is no "apply"
## step to forget.

signal closed

@onready var _master: HSlider = $Panel/Box/Master/Slider
@onready var _music: HSlider = $Panel/Box/Music/Slider
@onready var _sfx: HSlider = $Panel/Box/Sfx/Slider
@onready var _shake: CheckButton = $Panel/Box/Shake/Toggle
@onready var _vhs: CheckButton = $Panel/Box/Vhs/Toggle
@onready var _fisheye: CheckButton = $Panel/Box/Fisheye/Toggle
@onready var _pixelate: CheckButton = $Panel/Box/Pixelate/Toggle
@onready var _master_val: Label = $Panel/Box/Master/Value
@onready var _music_val: Label = $Panel/Box/Music/Value
@onready var _sfx_val: Label = $Panel/Box/Sfx/Value


func _ready() -> void:
	# Must stay interactive while the game tree is paused (opened from pause).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pull_from_settings()
	_master.value_changed.connect(func(v: float) -> void:
		Settings.set_master_volume(v)
		_refresh_labels())
	_music.value_changed.connect(func(v: float) -> void:
		Settings.set_music_volume(v)
		_refresh_labels())
	_sfx.value_changed.connect(func(v: float) -> void:
		Settings.set_sfx_volume(v)
		_refresh_labels())
	_shake.toggled.connect(func(on: bool) -> void:
		Settings.set_screen_shake(on)
		_refresh_labels())
	_vhs.toggled.connect(func(on: bool) -> void:
		Settings.set_vhs_effect(on)
		_refresh_labels())
	_fisheye.toggled.connect(func(on: bool) -> void:
		Settings.set_fisheye_effect(on)
		_refresh_labels())
	_pixelate.toggled.connect(func(on: bool) -> void:
		Settings.set_pixelate_effect(on)
		_refresh_labels())
	$Panel/Box/Row/Back.pressed.connect(_close)
	$Panel/Box/Row/Reset.pressed.connect(_on_reset)
	# Stay in sync if anything else changes a setting (Reset, or a future
	# keybind). _pull_from_settings uses the no_signal setters, so this can't
	# feed back into itself.
	Settings.changed.connect(_pull_from_settings)
	_master.grab_focus()


## Mirror the stored settings into the widgets without re-emitting changes.
func _pull_from_settings() -> void:
	_master.set_value_no_signal(Settings.master_volume)
	_music.set_value_no_signal(Settings.music_volume)
	_sfx.set_value_no_signal(Settings.sfx_volume)
	_shake.set_pressed_no_signal(Settings.screen_shake)
	_vhs.set_pressed_no_signal(Settings.vhs_effect)
	_fisheye.set_pressed_no_signal(Settings.fisheye_effect)
	_pixelate.set_pressed_no_signal(Settings.pixelate_effect)
	_refresh_labels()


func _refresh_labels() -> void:
	_master_val.text = "%d%%" % roundi(Settings.master_volume * 100.0)
	_music_val.text = "%d%%" % roundi(Settings.music_volume * 100.0)
	_sfx_val.text = "%d%%" % roundi(Settings.sfx_volume * 100.0)
	_shake.text = "On" if Settings.screen_shake else "Off"
	_vhs.text = "On" if Settings.vhs_effect else "Off"
	_fisheye.text = "On" if Settings.fisheye_effect else "Off"
	_pixelate.text = "On" if Settings.pixelate_effect else "Off"


func _on_reset() -> void:
	Settings.reset_to_defaults()
	_pull_from_settings()


func _close() -> void:
	closed.emit()


func _input(event: InputEvent) -> void:
	# Esc backs out of options (the pause menu defers to us while we're open).
	if event.is_action_pressed(&"cancel"):
		get_viewport().set_input_as_handled()
		_close()
