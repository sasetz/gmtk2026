extends Control
## The audio options overlay: master / music / SFX volume, screen shake, and a
## way into the credits. Signals are bound in the scene. Emits `closed` so the
## menu and pause menu can use it as an overlay, and `credits_requested` so the
## controller can swap in the credits.

signal closed
signal credits_requested

@onready var _master: HSlider = $Panel/Box/Master/Slider
@onready var _music: HSlider = $Panel/Box/Music/Slider
@onready var _sfx: HSlider = $Panel/Box/Sfx/Slider
@onready var _master_val: Label = $Panel/Box/Master/Value
@onready var _music_val: Label = $Panel/Box/Music/Value
@onready var _sfx_val: Label = $Panel/Box/Sfx/Value
@onready var _shake: CheckButton = $Panel/Box/Shake/Toggle
@onready var _back: Button = $Panel/Box/Buttons/Back


func _ready() -> void:
	# Must stay interactive while the tree is paused (opened from the pause menu).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_master.set_value_no_signal(Settings.master_volume)
	_music.set_value_no_signal(Settings.music_volume)
	_sfx.set_value_no_signal(Settings.sfx_volume)
	_shake.set_pressed_no_signal(Settings.screen_shake)
	_refresh_labels()
	_back.grab_focus()


func _on_master_changed(v: float) -> void:
	Settings.set_master_volume(v)
	_refresh_labels()


func _on_music_changed(v: float) -> void:
	Settings.set_music_volume(v)
	_refresh_labels()


func _on_sfx_changed(v: float) -> void:
	Settings.set_sfx_volume(v)
	_refresh_labels()


func _on_shake_toggled(on: bool) -> void:
	Settings.set_screen_shake(on)


func _on_back_pressed() -> void:
	closed.emit()


func _on_credits_pressed() -> void:
	credits_requested.emit()


func _refresh_labels() -> void:
	_master_val.text = "%d%%" % roundi(Settings.master_volume * 100.0)
	_music_val.text = "%d%%" % roundi(Settings.music_volume * 100.0)
	_sfx_val.text = "%d%%" % roundi(Settings.sfx_volume * 100.0)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
