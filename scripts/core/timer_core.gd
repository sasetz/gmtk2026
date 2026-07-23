class_name TimerCore
extends Node
## The countdown clock, and the single source of truth for a press's time value.
##
## Authoritative time comes from Time.get_ticks_usec() (integer microseconds),
## never accumulated delta — monotonic and frame-rate-independent (research #1).
## A press is timestamped the instant press() is called; call it straight from
## _input (not _process) so the scored value is as close to the physical press
## as possible (research #2).

signal started
## ms = the locked time in integer milliseconds; index = which lock (0-based).
signal pressed(ms: int, index: int)
signal expired

var running: bool = false
var duration_us: int = 0
var tier: int = 1
var press_budget: int = 4

# Effective-time integrator. The authoritative source is still the wall clock
# (Time.get_ticks_usec, immune to Engine.time_scale), but we integrate consumed
# time at a rate so Slow Reveal can genuinely bend the countdown without giving
# up microsecond precision at the press moment.
var _last_us: int = 0
var _consumed_us: float = 0.0
var _rate: float = .5
var _slow_until_us: int = 0
var _slow_rate: float = 1.0

var presses: Array[int] = []


func configure(duration_ms: int, press_count: int, precision_tier: int, rate: float) -> void:
	duration_us = duration_ms * 1000
	press_budget = press_count
	tier = precision_tier
	_rate = rate
	presses.clear()
	running = false


## The first button press starts the clock; it is not itself a scored lock.
func start() -> void:
	if running:
		return
	running = true
	_last_us = Time.get_ticks_usec()
	_consumed_us = 0.0
	_slow_until_us = 0
	started.emit()


## Crawl the countdown for `real_seconds` of wall time at `factor` speed
## (Slow Reveal). Effective time consumed during the window is scaled down.
func slow(factor: float, real_seconds: float) -> void:
	_advance()
	_slow_rate = factor
	_slow_until_us = Time.get_ticks_usec() + int(real_seconds * 1_000_000.0)


## Integrate consumed time up to now, splitting at the slow-window boundary so a
## query that straddles it is exact.
func _advance() -> void:
	if not running:
		return
	var now: int = Time.get_ticks_usec()
	if now <= _last_us:
		push_error("TimerCore: the clock is running irregularly!")
		return
	if _slow_until_us > _last_us:
		var boundary: int = mini(_slow_until_us, now)
		_consumed_us += float(boundary - _last_us) * _slow_rate * _rate
		_last_us = boundary
	if now > _last_us:
		_consumed_us += float(now - _last_us) * _rate
		_last_us = now


## Lock in the current time. Returns the integer-ms value, or -1 if the clock
## isn't running / the press budget is spent. Call from _input for accuracy.
func press() -> int:
	if not running or presses.size() >= press_budget:
		return -1
	var ms: int = remaining_ms()
	presses.append(ms)
	pressed.emit(ms, presses.size() - 1)
	if presses.size() >= press_budget:
		_finish()
	return ms


func remaining_us() -> int:
	if not running:
		return duration_us
	_advance()
	return maxi(0, duration_us - int(_consumed_us))


func remaining_ms() -> int:
	return remaining_us() / 1000


func presses_left() -> int:
	return press_budget - presses.size()


func _process(_delta: float) -> void:
	if running and remaining_us() <= 0:
		_finish()
		expired.emit()


func _finish() -> void:
	running = false
