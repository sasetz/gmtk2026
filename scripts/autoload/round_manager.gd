extends Node
# Lifetime: round
## Holds the running score and the hand of buttons for the current round, and
## tracks which buttons are active for the next stopwatch. When every stopwatch
## in the round has scored, it decides pass/fail against the target.

var round_def: RoundDef
var total_score: int = 0
var buttons: Array[ButtonDef] = []

var _active: Array[ButtonDef] = []
var _stopwatches_left: int = 0


func _ready() -> void:
	EventBus.stopwatch_ended.connect(_on_stopwatch_ended)


func begin(def: RoundDef, hand: Array[ButtonDef]) -> void:
	round_def = def
	buttons = hand
	total_score = 0
	_active.clear()
	_stopwatches_left = def.stopwatches.size()


func add_score(amount: int) -> void:
	total_score += amount


func set_button_active(button: ButtonDef, on: bool) -> void:
	if on:
		if not _active.has(button):
			_active.append(button)
	else:
		_active.erase(button)


func active_buttons() -> Array[ButtonDef]:
	return _active


## Spend the active buttons — called when a stopwatch starts.
func consume_active() -> void:
	for b in _active:
		buttons.erase(b)
	_active.clear()


func _on_stopwatch_ended() -> void:
	_stopwatches_left -= 1
	if _stopwatches_left <= 0:
		EventBus.round_scored.emit(total_score >= round_def.target)
