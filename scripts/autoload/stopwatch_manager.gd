extends Node
# Lifetime: stopwatch
## Owns all the time data for the one stopwatch in play: the clock counting down
## from its duration, the locked-in times, the active combos and buttons, and the
## points / mult / xmult it builds up. Cards push points and mult in during play;
## combos and buttons resolve when it scores (points x mult x xmult). The result
## goes to RoundManager.

var current: StopwatchDef
var clicks: Array[int] = []          # remaining time at each lock, milliseconds
var combos: Array[ComboDef] = []
var points: int = 0
var mult: int = 1
var xmult: float = 1.0
var score: int = 0
var running: bool = false
var remaining_ms: int = 0

var _active_buttons: Array[ButtonDef] = []
var _button_fired: Array[bool] = []
var _extra_clicks: int = 0
var _slow_time: float = 0.0
var _slow_factor: float = 1.0


func _process(delta: float) -> void:
	if not running:
		return
	var rate: float = current.rate
	if _slow_time > 0.0:
		_slow_time -= delta
		rate *= _slow_factor
	remaining_ms -= int(delta * 1000.0 * rate)
	if remaining_ms <= 0:
		remaining_ms = 0
		_finish()


func begin(def: StopwatchDef) -> void:
	current = def
	combos = def.combos
	clicks = []
	points = 0
	mult = 1
	xmult = 1.0
	score = 0
	remaining_ms = def.duration_ms
	_extra_clicks = 0
	_slow_time = 0.0
	_slow_factor = 1.0
	running = true
	_active_buttons = RoundManager.active_buttons().duplicate()
	RoundManager.consume_active()
	# Cards react to stopwatch_started (flat mult, xmult, extra locks).
	EventBus.stopwatch_started.emit()
	# Buttons fold in their always-on part now, so it shows in the live mult.
	_button_fired.clear()
	for b: ButtonDef in _active_buttons:
		_button_fired.append(b.on_begin())


func click() -> void:
	if not running:
		return
	clicks.append(remaining_ms)
	points += _lock_points(remaining_ms)
	EventBus.stopwatch_clicked.emit()
	if clicks.size() >= total_clicks():
		_finish()


func total_clicks() -> int:
	return current.clicks + _extra_clicks


func remaining_clicks() -> int:
	return maxi(0, total_clicks() - clicks.size())


func add_points(amount: int) -> void:
	points += amount


func add_mult(amount: int) -> void:
	mult += amount


func add_xmult(factor: float) -> void:
	xmult *= factor


func add_click_capacity(amount: int) -> void:
	_extra_clicks += amount


func slow(factor: float, seconds: float) -> void:
	_slow_factor = factor
	_slow_time = seconds


func reset() -> void:
	running = false
	current = null
	clicks = []
	combos = []
	points = 0
	mult = 1
	xmult = 1.0
	score = 0
	remaining_ms = 0
	_active_buttons = []
	_button_fired = []
	_extra_clicks = 0


## Baseline: reward locking near a whole second (tenth-of-a-second precision).
func _lock_points(ms: int) -> int:
	var frac: int = ms % 1000
	if frac > 500:
		frac = 1000 - frac
	return maxi(0, 100 - frac / 5)


func _finish() -> void:
	running = false
	for combo: ComboDef in combos:
		var n: int = combo.hits(clicks)
		if n > 0:
			points += combo.bonus_points * n
			mult += combo.bonus_mult * n
			EventBus.combo_triggered.emit(combo)
	for i in _active_buttons.size():
		if _active_buttons[i].on_finish():
			_button_fired[i] = true
		if _button_fired[i]:
			EventBus.button_fired.emit(_active_buttons[i])
	mult = maxi(0, mult)
	score = int(points * mult * xmult)
	RoundManager.add_score(score)
	EventBus.stopwatch_ended.emit()
