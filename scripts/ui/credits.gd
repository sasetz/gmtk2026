extends Control
## Credits overlay. The roster lives in credits.tscn as static nodes; this just
## handles closing. Emits `closed` so the main menu can pop it off.

signal closed


func _ready() -> void:
	$Panel/Box/Back.grab_focus()


func _on_back_pressed() -> void:
	closed.emit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
