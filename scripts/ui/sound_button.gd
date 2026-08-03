class_name SoundButton
extends BaseButton

@export var sfx_name: StringName = &"ui_click"

func _ready() -> void:
	pressed.connect(func (): Audio.sfx(sfx_name))
