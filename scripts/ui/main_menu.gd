extends Control
## The main menu screen. It doesn't navigate itself — it just reports which
## button was pressed; the SceneController decides what happens next. Button
## signals are bound in main_menu.tscn.

signal play_pressed
signal options_pressed
signal credits_pressed
signal quit_pressed

@onready var _play: Button = $Buttons/Play
@onready var _quit: Button = $Buttons/Quit


func _ready() -> void:
	# There's no meaningful "quit" in a browser tab.
	_quit.visible = OS.get_name() != "Web"
	_play.grab_focus()


func _on_play_pressed() -> void:
	Audio.play_sfx(&"ui_click")
	play_pressed.emit()


func _on_options_pressed() -> void:
	Audio.play_sfx(&"ui_click")
	options_pressed.emit()


func _on_credits_pressed() -> void:
	Audio.play_sfx(&"ui_click")
	credits_pressed.emit()


func _on_quit_pressed() -> void:
	Audio.play_sfx(&"ui_click")
	quit_pressed.emit()
