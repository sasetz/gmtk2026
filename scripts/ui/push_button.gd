@tool
class_name PushButton
extends Button

@export var Sprite: AnimatedSprite2D
@export var Type: Enums.ButtonType:
	set(value):
		Type = value
		_update_frames()
	get:
		return Type


var _pressed := false

func _ready() -> void:
	_update_frames()

func _update_frames():
	Sprite.sprite_frames = ResourceCatalog.push_button_catalog[Type].sprite
	Sprite.play(&"idle")

func _on_mouse_entered() -> void:
	Sprite.play(&"hover")


func _on_mouse_exited() -> void:
	Sprite.play(&"idle")


func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"press"):
		get_viewport().set_input_as_handled()
		button_down.emit()
		Sprite.play(&"push")
		Audio.button(Type)
		pressed.emit()
		_pressed = true
	if event.is_action_released(&"press") and _pressed:
		_pressed = false
		get_viewport().set_input_as_handled()
		button_up.emit()
		Sprite.play(&"idle")
