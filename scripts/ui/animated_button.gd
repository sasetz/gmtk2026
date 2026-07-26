class_name AnimatedButton
extends Control
## A button drawn from a SpriteFrames sheet: it rests on `idle` and plays `click`
## once when pressed, stopping on the last frame rather than looping.
##
## SpriteFrames belongs to AnimatedSprite2D, which is a Node2D and does not lay
## out inside Control containers, so the frames are stepped by hand onto a
## TextureRect instead. That keeps the button a normal Control that anchors and
## sizes like every other one.

signal pressed

const IDLE: StringName = &"idle"
const CLICK: StringName = &"click"

@export var frames: SpriteFrames: set = set_frames
## Text under the button, if any.
@export var text: String = "": set = set_text
## Played on press. The button sounds itself, so UiSound leaves it alone.
@export var sound: StringName = &"btn_cat"

@onready var _art: TextureRect = $Art
@onready var _button: TextureButton = $Hit
@onready var _label: Label = $Label

var _anim: StringName = IDLE
var _frame: int = 0
var _time: float = 0.0
var _playing: bool = false


func _ready() -> void:
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
	_anim = IDLE
	_frame = 0
	_playing = false
	_show_frame()
	# The art dictates the button's size, so the hit area follows it.
	var tex: Texture2D = _current_texture()
	if tex != null:
		custom_minimum_size = tex.get_size()


func _process(delta: float) -> void:
	if not _playing or frames == null:
		return
	var speed: float = maxf(0.01, frames.get_animation_speed(_anim))
	_time += delta
	if _time < 1.0 / speed:
		return
	_time = 0.0
	_frame += 1
	if _frame >= frames.get_frame_count(_anim):
		# Hold on the last frame: the click plays through and stops.
		_frame = maxi(0, frames.get_frame_count(_anim) - 1)
		_playing = false
		_rest()
		return
	_show_frame()


## Back to the resting pose once a click has played out.
func _rest() -> void:
	_anim = IDLE
	_frame = 0
	_show_frame()


func _on_pressed() -> void:
	Audio.play_sfx(sound)
	play_click()
	pressed.emit()


## Run the click animation from the top.
func play_click() -> void:
	if frames == null or not frames.has_animation(CLICK):
		return
	_anim = CLICK
	_frame = 0
	_time = 0.0
	_playing = true
	_show_frame()


func _current_texture() -> Texture2D:
	if frames == null or not frames.has_animation(_anim):
		return null
	if _frame >= frames.get_frame_count(_anim):
		return null
	return frames.get_frame_texture(_anim, _frame)


func _show_frame() -> void:
	var tex: Texture2D = _current_texture()
	if tex != null:
		_art.texture = tex


func set_disabled(on: bool) -> void:
	_button.disabled = on
	modulate.a = 0.5 if on else 1.0


func is_disabled() -> bool:
	return _button.disabled
