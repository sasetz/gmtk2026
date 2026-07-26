class_name AnimatedButton
extends Control
## A button drawn from a SpriteFrames sheet. It behaves like a real key: it goes
## down under the pointer and comes back up when released, and the action fires
## on release like any other button.
##
## Only two frames of the sheet are used - fully up and fully down. Playing the
## whole five-frame sequence made every press feel delayed, and the in-between
## frames are never seen on a press this short anyway.
##
## SpriteFrames belongs to AnimatedSprite2D, which is a Node2D and does not lay
## out inside Control containers, so the frame is put on a TextureRect by hand.
## That keeps the button a normal Control that anchors and sizes like the rest.

signal pressed

const IDLE: StringName = &"idle"
const CLICK: StringName = &"click"

@export var frames: SpriteFrames: set = set_frames
## Text under the button, if any.
@export var text: String = "": set = set_text
## Played as the button goes down. The button sounds itself, so UiSound leaves it
## alone. Left empty it follows the sheet, so the noise matches the face.
@export var sound: StringName = &""

@onready var _art: TextureRect = $Art
@onready var _button: TextureButton = $Hit
@onready var _label: Label = $Label

var _down: bool = false


func _ready() -> void:
	_button.button_down.connect(_on_down)
	_button.button_up.connect(_on_up)
	_button.pressed.connect(_on_pressed)
	_apply_frames()
	_apply_text()


func set_frames(value: SpriteFrames) -> void:
	frames = value
	if is_node_ready():
		_apply_frames()


func set_text(value: String) -> void:
	text = value
	if is_node_ready():
		_apply_text()


func _apply_text() -> void:
	_label.text = text
	_label.visible = text != ""


func _apply_frames() -> void:
	if frames == null:
		return
	_down = false
	_show(false)
	# The art dictates the button's size, so the hit area follows it.
	var tex: Texture2D = _texture(false)
	if tex != null:
		custom_minimum_size = tex.get_size()


# --- press ------------------------------------------------------------------

func _on_down() -> void:
	if _down:
		return
	_down = true
	_show(true)
	Audio.play_sfx(press_sound())


func _on_up() -> void:
	# Fires even when the pointer slid off the button, so it can never stick down.
	_down = false
	_show(false)


func _on_pressed() -> void:
	pressed.emit()


## What this button sounds like: whatever it was given, or the sheet's own.
func press_sound() -> StringName:
	return sound if sound != &"" else Audio.sound_for_sheet(frames)


# --- frames -----------------------------------------------------------------

## Up is the resting frame; down is the last frame of the press, where the key
## has travelled all the way.
func _texture(down: bool) -> Texture2D:
	if frames == null:
		return null
	if down:
		if not frames.has_animation(CLICK) or frames.get_frame_count(CLICK) == 0:
			return null
		return frames.get_frame_texture(CLICK, frames.get_frame_count(CLICK) - 1)
	if not frames.has_animation(IDLE) or frames.get_frame_count(IDLE) == 0:
		return null
	return frames.get_frame_texture(IDLE, 0)


func _show(down: bool) -> void:
	var tex: Texture2D = _texture(down)
	if tex != null:
		_art.texture = tex


func is_down() -> bool:
	return _down


func set_disabled(on: bool) -> void:
	_button.disabled = on
	modulate.a = 0.5 if on else 1.0
	if on and _down:
		_on_up()


func is_disabled() -> bool:
	return _button.disabled
