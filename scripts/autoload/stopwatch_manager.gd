extends Node
# Lifetime: stopwatch
## Owns all the time data for the one stopwatch in play: the clock counting down
## from its duration, the locked-in times, the active combos and buttons, and the
## points / mult / xmult it builds up. Cards push points and mult in during play;
## combos and buttons resolve when it scores (points x mult x xmult). The result
## goes to RoundManager.

## Seconds the clock freezes after a lock, so the player can read what they hit.
const FREEZE_TIME: float = 0.15

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
# You can't lock twice on the same decimal second. A press made on an
# already-locked decimal is buffered and fires the moment the decimal ticks over
# (a small coyote window so an eager press is never wasted).
var _last_lock_ds: int = -1          # decisecond of the last lock (remaining_ms / 100)
var _buffered: bool = false
var _freeze_time: float = 0.0        # clock is paused while this counts down


func _process(delta: float) -> void:
	if not running:
		return
	if _freeze_time > 0.0:
		_freeze_time -= delta
		return
	var rate: float = current.rate
	if _slow_time > 0.0:
		_slow_time -= delta
		rate *= _slow_factor
	remaining_ms -= int(delta * 1000.0 * rate)
	if remaining_ms < 0:
		remaining_ms = 0
	# A buffered press fires as soon as the decimal advances past the last lock.
	@warning_ignore("integer_division")
	if _buffered and remaining_ms / 100 != _last_lock_ds:
		_lock(remaining_ms)
		return
	if remaining_ms <= 0:
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
	_last_lock_ds = -1
	_buffered = false
	_freeze_time = 0.0
	running = true
	_active_buttons = RoundManager.active_buttons().duplicate()
	RoundManager.consume_active()
	# Cards react to stopwatch_started (flat mult, xmult, extra locks).
	EventBus.stopwatch_started.emit()
	# Buttons fold in their always-on part now, so it shows in the live mult.
	_button_fired.clear()
	for b: ButtonDef in _active_buttons:
		_button_fired.append(b.on_begin())


## A press from the player: lock now, or buffer it if the current decimal is
## already taken (it fires on the next decimal).
func click() -> void:
	if not running:
		return
	@warning_ignore("integer_division")
	if remaining_ms / 100 == _last_lock_ds:
		_buffered = true
		return
	_lock(remaining_ms)


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


## Nudge the lock just made to a different time (the rounding cards). Safe to
## call from a stopwatch_clicked handler - combos are scored afterwards.
func adjust_last_click(ms: int) -> void:
	if clicks.is_empty():
		return
	clicks[-1] = ms
	@warning_ignore("integer_division")
	_last_lock_ds = ms / 100


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
	_last_lock_ds = -1
	_buffered = false
	_freeze_time = 0.0


func _lock(ms: int) -> void:
	clicks.append(ms)
	@warning_ignore("integer_division")
	_last_lock_ds = ms / 100
	_buffered = false
	points += _lock_points(ms)
	_freeze_time = FREEZE_TIME
	EventBus.stopwatch_clicked.emit()
	if clicks.size() >= total_clicks():
		_finish()


## A lock is worth nothing on its own: points only come from combos, buttons and
## cards. Miss every bonus and the stopwatch scores zero.
func _lock_points(_ms: int) -> int:
	return 0


func _finish() -> void:
	running = false
	# A negative combo that lands voids the whole stopwatch, however well the
	# rest of it went.
	var voided: bool = false
	for combo: ComboDef in combos:
		var n: int = combo.hits(clicks)
		if n <= 0:
			continue
		EventBus.combo_triggered.emit(combo)
		if combo.negative:
			voided = true
		else:
			points += combo.bonus_points * n
			mult += combo.bonus_mult * n
	for i in _active_buttons.size():
		if _active_buttons[i].on_finish():
			_button_fired[i] = true
		if _button_fired[i]:
			EventBus.button_fired.emit(_active_buttons[i])
	mult = maxi(0, mult)
	score = 0 if voided else int(points * mult * xmult)
	RoundManager.add_score(score)
	EventBus.stopwatch_ended.emit()
