extends PanelContainer
## One stopwatch view. Shows its combos as chips, the clock counting down, a row
## of pips for the remaining locks, and the live points/mult while it runs. It
## drives the StopwatchManager; only one stopwatch runs at a time, so the others
## disable their start button while one is live.

@export var combo_chip_scene: PackedScene
@export var pip_scene: PackedScene

@onready var _combos_box: HBoxContainer = $Box/Combos
@onready var _time: Label = $Box/Time
@onready var _pips: HBoxContainer = $Box/Pips
@onready var _score: Label = $Box/Score
@onready var _action: Button = $Box/Action

enum State { IDLE, RUNNING, DONE }

const FILLED := Color(0.98, 0.86, 0.4)
const EMPTY := Color(0.2, 0.28, 0.26)

var def: StopwatchDef
var _state: State = State.IDLE
var _pip_nodes: Array[ColorRect] = []
var _final_text: String = ""


func setup(d: StopwatchDef) -> void:
	def = d


func _ready() -> void:
	_build_combos()
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


func _on_pressed() -> void:
	if _state == State.IDLE:
		if StopwatchManager.running:
			return
		_state = State.RUNNING
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
		# Pop the clock so the locked time is easy to read during the freeze.
		Shake.play(_time, 1.4)


func _on_any_ended() -> void:
	if _state == State.RUNNING:
		_state = State.DONE
		_fill_pips(StopwatchManager.clicks.size())
		if StopwatchManager.remaining_ms == 0:
			_time.text = _format(0)
		_final_text = "%d x%d = %d" % [StopwatchManager.points, StopwatchManager.mult, StopwatchManager.score]
		_score.text = _final_text
	_refresh()


func _build_combos() -> void:
	for c: Node in _combos_box.get_children():
		c.queue_free()
	for combo: ComboDef in def.combos:
		var chip := combo_chip_scene.instantiate()
		chip.setup(combo)
		_combos_box.add_child(chip)


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
			_action.disabled = StopwatchManager.running
		State.RUNNING:
			_action.text = "Lock (%d)" % StopwatchManager.remaining_clicks()
			_action.disabled = false
		State.DONE:
			_action.text = "Done"
			_action.disabled = true


func _format(ms: int) -> String:
	return "%d.%d" % [ms / 1000, (ms % 1000) / 100]
