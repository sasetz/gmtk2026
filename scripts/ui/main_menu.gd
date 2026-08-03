extends Control
## The main menu screen. The cat button starts a run; options live in the
## always-visible corner button (handled by the SceneController), and credits are
## reached from inside the options menu. It just reports which button was pressed.

signal play_pressed

@onready var _play: PushButton = $Buttons/Play
@onready var _transition_timer: Timer = $OnPlayTimer


func _ready() -> void:
	_play.grab_focus()


## Space (or a click anywhere) starts the run. Unhandled input only, and on the
## way DOWN: is_action() is true for the release as well, so this fired twice and
## started the run twice over, and a click on the Play button counted again on
## top of the button's own press.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"press"):
		get_viewport().set_input_as_handled()
		_on_play_pressed()


func _on_play_pressed() -> void:
	_transition_timer.one_shot = true
	_transition_timer.timeout.connect(func (): play_pressed.emit())
	_transition_timer.start()
