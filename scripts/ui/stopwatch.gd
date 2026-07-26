extends VBoxContainer
## One stopwatch view: a pixel-art stopwatch sprite with its combo badges above,
## the clock overlaid on its screen, remaining-lock pips, the live points/mult,
## and an activate button below. While running it wears the sprite's _pressed
## variant. Only one stopwatch runs at a time, so the others disable their button.

const FACES := {
	&"default": [preload("res://assets/art/stopwatches/stopwatch_default.tres"),
		preload("res://assets/art/stopwatches/stopwatch_default.tres")],
	&"grey": [preload("res://assets/art/stopwatches/stopwatch_grey.tres"),
		preload("res://assets/art/stopwatches/stopwatch_grey_pressed.tres")],
	&"purple": [preload("res://assets/art/stopwatches/stopwatch_purple.tres"),
		preload("res://assets/art/stopwatches/stopwatch_purple_pressed.tres")],
	&"pink": [preload("res://assets/art/stopwatches/stopwatch_pink.tres"),
		preload("res://assets/art/stopwatches/stopwatch_pink_pressed.tres")],
	&"digital": [preload("res://assets/art/stopwatches/stopwatch_digital.tres"),
		preload("res://assets/art/stopwatches/stopwatch_digital.tres")],
}

## The button a face is operated with, so a console watch has a console button.
const ACTION_FRAMES := {
	&"default": preload("res://assets/art/buttons/button_white_normal.tres"),
	&"grey": preload("res://assets/art/buttons/button_black_normal.tres"),
	&"purple": preload("res://assets/art/buttons/button_black_cat.tres"),
	&"pink": preload("res://assets/art/buttons/button_bumblegum.tres"),
	&"digital": preload("res://assets/art/buttons/button_black_normal.tres"),
}

@export var combo_chip_scene: PackedScene
@export var pip_scene: PackedScene

@onready var _badges: HBoxContainer = $Badges
@onready var _face: TextureRect = $Face
@onready var _time: Label = $Face/Time
@onready var _pips: HBoxContainer = $Pips
@onready var _score: Label = $Score
@onready var _action: AnimatedButton = $Action

enum State { IDLE, RUNNING, DONE }

## Ticking runs for the whole round, so it sits under everything else.
const TICK_DB: float = -8.0

const FILLED := Color(0.98, 0.86, 0.4)
const EMPTY := Color(0.2, 0.28, 0.26)

var def: StopwatchDef
var _state: State = State.IDLE
var _pip_nodes: Array[ColorRect] = []
var _chips: Array[Node] = []
var _base_tex: Texture2D
var _pressed_tex: Texture2D
## The tick this face makes - a console beeps, a cassette clicks.
var _tick: StringName = &"tick_normal"
## The clock second the last tick was played on, so each one sounds once.
var _ticked_second: int = -1


func setup(d: StopwatchDef) -> void:
	def = d


func _ready() -> void:
	var pair: Array = FACES.get(def.face, FACES[&"default"])
	_base_tex = pair[0]
	_pressed_tex = pair[1]
	_tick = Audio.tick_for_face(def.face)
	_face.texture = _base_tex
	_action.frames = ACTION_FRAMES.get(def.face, ACTION_FRAMES[&"default"])
	_build_badges()
	_build_pips(def.clicks)
	_time.text = _format(def.duration_ms)
	_score.text = ""
	_action.pressed.connect(_on_pressed)
	EventBus.stopwatch_started.connect(_on_any_started)
	EventBus.stopwatch_clicked.connect(_on_any_clicked)
	EventBus.stopwatch_ended.connect(_on_any_ended)
	_refresh()


func _process(_delta: float) -> void:
	if _state == State.RUNNING:
		_time.text = _format(StopwatchManager.remaining_ms)
		_update_score()
		_tick_clock()


## A running stopwatch ticks once per second of its own clock, from the moment it
## starts until it runs out. A lock freezes the clock, so the ticking pauses with
## it, and a slow rate ticks slower - the sound follows the watch, not real time.
func _tick_clock() -> void:
	var second: int = StopwatchManager.remaining_ms / 1000
	if second == _ticked_second:
		return
	_ticked_second = second
	Audio.play_sfx(_tick, 1.0, TICK_DB)


func _on_pressed() -> void:
	if _state == State.IDLE:
		if StopwatchManager.running:
			return
		_state = State.RUNNING
		_face.texture = _pressed_tex   # running animation: the _pressed variant
		_watch_badges(true)
		StopwatchManager.begin(def)
		_build_pips(StopwatchManager.total_clicks())
		_update_score()
		_refresh()
	elif _state == State.RUNNING:
		StopwatchManager.click()


func _on_any_started() -> void:
	_refresh()


func _on_any_clicked() -> void:
	if _state == State.RUNNING:
		_fill_pips(StopwatchManager.clicks.size())
		_update_score()
		_refresh()
		Shake.play(_time, 1.4)


func _on_any_ended() -> void:
	if _state == State.RUNNING:
		_state = State.DONE
		_face.texture = _base_tex
		_watch_badges(false)
		_fill_pips(StopwatchManager.clicks.size())
		if StopwatchManager.remaining_ms == 0:
			_time.text = _format(0)
		_score.text = "%d x%d = %d" % [StopwatchManager.points, StopwatchManager.mult, StopwatchManager.score]
	_refresh()


func _build_badges() -> void:
	for c: Node in _badges.get_children():
		c.queue_free()
	_chips.clear()
	for combo: ComboDef in def.combos:
		var chip := combo_chip_scene.instantiate()
		chip.setup(combo)
		_badges.add_child(chip)
		_chips.append(chip)


## Only the running stopwatch lights its badges up as combos become scorable.
func _watch_badges(on: bool) -> void:
	for chip: Node in _chips:
		chip.set_watching(on)


func _build_pips(count: int) -> void:
	for p: Node in _pips.get_children():
		p.queue_free()
	_pip_nodes.clear()
	for i in count:
		var pip: ColorRect = pip_scene.instantiate()
		pip.color = EMPTY
		_pips.add_child(pip)
		_pip_nodes.append(pip)


func _fill_pips(count: int) -> void:
	for i in _pip_nodes.size():
		_pip_nodes[i].color = FILLED if i < count else EMPTY


func _update_score() -> void:
	_score.text = "%d x%d" % [StopwatchManager.points, StopwatchManager.mult]


func _refresh() -> void:
	match _state:
		State.IDLE:
			_action.text = "Start"
			_action.set_disabled(StopwatchManager.running)
		State.RUNNING:
			_action.text = "Lock (%d)" % StopwatchManager.remaining_clicks()
			_action.set_disabled(false)
		State.DONE:
			_action.text = "Done"
			_action.set_disabled(true)


func _format(ms: int) -> String:
	return "%d.%d" % [ms / 1000, (ms % 1000) / 100]
