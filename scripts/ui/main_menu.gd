extends Control
## The main menu screen. The cat button starts a run; options live in the
## always-visible corner button (handled by the SceneController), and credits are
## reached from inside the options menu. It just reports which button was pressed.

signal play_pressed
signal options_pressed
signal credits_pressed
signal quit_pressed

@onready var _play: TextureButton = $Play
@onready var _quit: Button = $Quit


func _ready() -> void:
	# There's no meaningful "quit" in a browser tab.
	_quit.visible = OS.get_name() != "Web"
	UiSound.attach(self, &"ui_click", ["Play"])
	UiSound.play_on(_play, &"btn_cat")
	_play.grab_focus()


func _on_play_pressed() -> void:
	play_pressed.emit()


func _on_quit_pressed() -> void:
	quit_pressed.emit()
