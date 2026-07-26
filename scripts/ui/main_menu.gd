extends Control
## The main menu screen. The cat button starts a run; options live in the
## always-visible corner button (handled by the SceneController), and credits are
## reached from inside the options menu. It just reports which button was pressed.

signal play_pressed
signal options_pressed
signal credits_pressed
signal quit_pressed

@onready var _play: AnimatedButton = $Buttons/Play


func _ready() -> void:
	# There's no meaningful "quit" in a browser tab.
	# The cat buttons sound themselves; anything else here gets the usual click.
	UiSound.attach(self)
	_play.grab_focus()
	_play._label.hide()


func _on_play_pressed() -> void:
	play_pressed.emit()
