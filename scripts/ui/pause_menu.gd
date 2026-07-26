extends Control
## The pause overlay. It's a plain screen the SceneController mounts while a run
## is paused — it just reports which button was pressed (or Esc). The controller
## owns pausing/unpausing and what each choice does. Button signals are bound in
## pause_menu.tscn.

signal resume_pressed
signal options_pressed
signal menu_pressed

@onready var _resume: AnimatedButton = $Panel/Box/Buttons/Resume


func _ready() -> void:
	UiSound.attach(self)
	_resume.grab_focus()


func _on_resume_pressed() -> void:
	resume_pressed.emit()


func _on_options_pressed() -> void:
	options_pressed.emit()


func _on_main_menu_pressed() -> void:
	menu_pressed.emit()


func _input(event: InputEvent) -> void:
	# Esc resumes (controller closes us).
	if event.is_action_pressed(&"cancel"):
		get_viewport().set_input_as_handled()
		resume_pressed.emit()
