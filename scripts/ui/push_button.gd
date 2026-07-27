@tool
class_name PushButton
extends Control

@export var Sprite: AnimatedSprite2D
@export var Type: Enums.ButtonType:
	set(value):
		Type = value
		_update_frames()
	get:
		return Type

		

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
		Sprite.play(&"push")
	if event.is_action_released(&"press"):
		Sprite.play(&"idle")
