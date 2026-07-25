extends Node
# Lifetime: stopwatch
## Owns all the time data for the one stopwatch currently in play: the running
## clock, the locked-in click times, the active combos, and the points/mult it
## builds up. When the last lock is made it scores (points x mult) and hands the
## result to RoundManager. Cards read this and push points/mult back in.

var current: StopwatchDef
var clicks: Array[int] = []      # locked-in times, milliseconds
var combos: Array[ComboDef] = []
var points: int = 0
var mult: int = 1
var score: int = 0
var running: bool = false
var elapsed_ms: int = 0


func _process(delta: float) -> void:
	if not running:
		return
	elapsed_ms += int(delta * 1000.0 * current.rate)
	if elapsed_ms >= current.duration_ms:
		elapsed_ms -= current.duration_ms   # wrap the clock


func begin(def: StopwatchDef) -> void:
	current = def
	combos = def.combos
	clicks = []
	points = 0
	mult = 1
	score = 0
	elapsed_ms = 0
	running = true
	for b in RoundManager.active_buttons():
		points += b.bonus_points
		mult += b.bonus_mult
	RoundManager.consume_active()
	EventBus.stopwatch_started.emit()


func click() -> void:
	if not running:
		return
	clicks.append(elapsed_ms)
	points += _lock_points(elapsed_ms)
	EventBus.stopwatch_clicked.emit()
	if clicks.size() >= current.clicks:
		_finish()


func add_points(amount: int) -> void:
	points += amount


func add_mult(amount: int) -> void:
	mult += amount


func reset() -> void:
	running = false
	current = null
	clicks = []
	combos = []
	points = 0
	mult = 1
	score = 0
	elapsed_ms = 0


## Baseline: reward locking near a whole second (two-decimal precision). Real
## combo detection over the click pattern comes later.
func _lock_points(ms: int) -> int:
	var frac: int = ms % 1000
	if frac > 500:
		frac = 1000 - frac
	return maxi(0, 100 - frac / 5)


func _finish() -> void:
	running = false
	for combo in combos:
		points += combo.bonus_points
		mult += combo.bonus_mult
	score = points * mult
	RoundManager.add_score(score)
	EventBus.stopwatch_ended.emit()
