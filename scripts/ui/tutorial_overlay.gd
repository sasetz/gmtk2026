extends Control
## The tutorial overlay for the scripted first lap: a little creature that talks
## the player through it, a dim that lifts once it is their turn to play, and a
## hold-to-skip button so nobody skips it by accident.
##
## It only talks and points - the Tutorial autoload owns the script and the
## rounds, and the round screen does its own highlighting off the event bus.

const IDLE_FRAMES: Array[Texture2D] = [
	preload("res://assets/art/cards/card_back_1.tres"),
	preload("res://assets/art/cards/card_back_2.tres"),
	preload("res://assets/art/cards/card_back_3.tres"),
	preload("res://assets/art/cards/card_back_4.tres"),
]
const FRAME_TIME: float = 0.22
const HOLD_TO_SKIP: float = 1.2

@onready var _dim: ColorRect = $Dim
@onready var _creature: TextureRect = $Creature
@onready var _bubble: PanelContainer = $Bubble
@onready var _text: Label = $Bubble/Box/Text
@onready var _hint: Label = $Bubble/Box/Hint
@onready var _skip: Button = $Skip
@onready var _skip_fill: ColorRect = $Skip/Fill

var _lines: Array = []
var _line: int = 0
## True while lines are being read: the dim blocks the game underneath.
var _talking: bool = false
var _frame: float = 0.0
var _held: float = 0.0
var _bob: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.round_started.connect(_on_round_started)
	EventBus.round_result.connect(_on_round_result)
	_skip.button_down.connect(_press_skip)
	_skip.button_up.connect(_release_skip)
	_say(Tutorial.pre_lines())


func _process(delta: float) -> void:
	_animate(delta)
	if _held > 0.0:
		_held += delta
		_skip_fill.scale.x = clampf(_held / HOLD_TO_SKIP, 0.0, 1.0)
		if _held >= HOLD_TO_SKIP:
			_do_skip()


## Idle: cycle the frames and bob gently.
func _animate(delta: float) -> void:
	_frame += delta
	if _frame >= FRAME_TIME:
		_frame -= FRAME_TIME
		var next: int = (IDLE_FRAMES.find(_creature.texture) + 1) % IDLE_FRAMES.size()
		_creature.texture = IDLE_FRAMES[next]
	_bob += delta * 2.0
	_creature.position.y = _creature_home() + sin(_bob) * 3.0


func _creature_home() -> float:
	return size.y * 0.5 - 44.0


func _say(lines: Array) -> void:
	_lines = lines
	_line = 0
	if _lines.is_empty():
		_finish_talking()
		return
	_talking = true
	# The dim is only paint - this node does the blocking, so its own _gui_input
	# still sees the click that moves to the next line.
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.color.a = 0.72
	_bubble.visible = true
	EventBus.tutorial_highlight.emit(&"none")
	_show_line()


func _show_line() -> void:
	_text.text = str(_lines[_line])
	_hint.text = "Click to continue"
	Audio.play_sfx(&"speech")


## Any click moves to the next line; the last one hands the round over.
func _gui_input(event: InputEvent) -> void:
	if not _talking:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		accept_event()
		_advance()


func _advance() -> void:
	_line += 1
	if _line < _lines.size():
		_show_line()
		return
	_finish_talking()


## Done talking: lift the dim, point at what matters, let the player play.
func _finish_talking() -> void:
	_talking = false
	_lines = []
	# Hand the round back: clicks now fall through to the stopwatch underneath.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.color.a = 0.0
	_bubble.visible = false
	EventBus.tutorial_highlight.emit(Tutorial.highlight())


func _on_round_started() -> void:
	if not Tutorial.active:
		return
	_say(Tutorial.pre_lines())


func _on_round_result(won: bool, _is_boss: bool, _reward: int) -> void:
	if not Tutorial.active:
		return
	EventBus.tutorial_highlight.emit(&"none")
	if won:
		_say(Tutorial.post_lines())
	else:
		_say([Tutorial.FAIL_LINE])


func _press_skip() -> void:
	_held = 0.001


func _release_skip() -> void:
	_held = 0.0
	_skip_fill.scale.x = 0.0


func _do_skip() -> void:
	_release_skip()
	Audio.play_sfx(&"ui_cancel")
	EventBus.tutorial_highlight.emit(&"none")
	Tutorial.skip()
