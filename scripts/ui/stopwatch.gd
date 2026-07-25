extends PanelContainer
## One stopwatch view. It shows the running clock and its combos, and drives the
## StopwatchManager: the button starts the clock, then each press locks it in.
## Only one stopwatch runs at a time, so the others disable their start button
## while one is live.

@onready var _time: Label = $Box/Time
@onready var _combos: Label = $Box/Combos
@onready var _action: Button = $Box/Action

enum State { IDLE, RUNNING, DONE }

var def: StopwatchDef
var _state: State = State.IDLE
var _final_score: int = 0


func setup(d: StopwatchDef) -> void:
	def = d


func _ready() -> void:
	_combos.text = _combo_names()
	_action.pressed.connect(_on_pressed)
	EventBus.stopwatch_started.connect(_refresh)
	EventBus.stopwatch_clicked.connect(_on_any_clicked)
	EventBus.stopwatch_ended.connect(_on_any_ended)
	_time.text = _format(0)
	_refresh()


func _process(_delta: float) -> void:
	if _state == State.RUNNING:
		_time.text = _format(StopwatchManager.elapsed_ms)


func _on_pressed() -> void:
	if _state == State.IDLE:
		if StopwatchManager.running:
			return
		_state = State.RUNNING
		StopwatchManager.begin(def)
	elif _state == State.RUNNING:
		StopwatchManager.click()


func _on_any_clicked() -> void:
	if _state == State.RUNNING:
		_refresh()


func _on_any_ended() -> void:
	if _state == State.RUNNING:
		_state = State.DONE
		_final_score = StopwatchManager.score
		if not StopwatchManager.clicks.is_empty():
			_time.text = _format(StopwatchManager.clicks[-1])
	_refresh()


func _refresh() -> void:
	match _state:
		State.IDLE:
			_action.text = "Start"
			_action.disabled = StopwatchManager.running
		State.RUNNING:
			var left: int = def.clicks - StopwatchManager.clicks.size()
			_action.text = "Lock (%d)" % left
			_action.disabled = false
		State.DONE:
			_action.text = "Scored %d" % _final_score
			_action.disabled = true


func _combo_names() -> String:
	if def.combos.is_empty():
		return "No combos"
	var names: Array[String] = []
	for combo: ComboDef in def.combos:
		names.append(combo.display_name)
	return ", ".join(names)


func _format(ms: int) -> String:
	return "%d.%02d" % [ms / 1000, (ms % 1000) / 10]
