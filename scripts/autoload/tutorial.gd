extends Node
# Lifetime: run (the first lap)
## The scripted first lap. It hands RunManager hand-built rounds instead of
## generated ones and tells the overlay what to say and what to point at. A
## failed tutorial round is replayed with an encouraging line rather than ending
## the run, and once the last one is cleared the generator takes over.

## Rounds in the scripted lap.
const STEPS: int = 4

const FAIL_LINE: String = "Ah, almost hit it! Here, try again!"
const FINAL_LINE: String = "Nicely done! I think you can take it by yourself from here! Bye!"

## What the overlay should point at while a step is being played.
const HIGHLIGHTS: Array[StringName] = [&"stopwatch", &"stopwatch", &"button", &"card"]

## Lines shown before the round is handed over to the player.
const PRE_LINES: Array = [
	[
		"Greetings! Welcome to Balatro Count-Down! Here, you'll have to stop stopwatches on the right time!",
		"This is a stopwatch. Click to start it, then click again to stop it.",
	],
	["Here, try to click this one when the last digit is zero!"],
	[
		"Now, let's mix things up a bit! Here's a button.",
		"It is activated when you hit multiple clicks one after the other. You can click multiple times on a single stopwatch!",
	],
	["Now, try to score at least 500 with these two stopwatches! Here, have this card, it'll help you on round numbers!"],
]

## Lines shown once the round is over, before moving on.
const POST_LINES: Array = [
	[
		"Nice! When you click the stopwatch, you get points!",
		"But in order for those points to count, you need to score combos! This stopwatch didn't have any combos on it... Let's try a different one!",
	],
	[],
	[],
	[FINAL_LINE],
]

var active: bool = false
var step: int = 0

var _rng := RandomNumberGenerator.new()


func start() -> void:
	active = true
	step = 0
	_rng.randomize()


func skip() -> void:
	active = false
	EventBus.tutorial_finished.emit()


func finish() -> void:
	active = false
	EventBus.tutorial_finished.emit()


func pre_lines() -> Array:
	return PRE_LINES[mini(step, STEPS - 1)]


func post_lines() -> Array:
	return POST_LINES[mini(step, STEPS - 1)]


func highlight() -> StringName:
	return HIGHLIGHTS[mini(step, STEPS - 1)]


## The scripted round for the current step.
func round_def() -> RoundDef:
	match step:
		0:
			return _first()
		1:
			return _second()
		2:
			return _third()
		_:
			return _fourth()


## Round 1: a single slow stopwatch with one lock and no combos. It cannot be
## failed - its whole job is to show that locks alone score nothing.
func _first() -> RoundDef:
	var r := RoundDef.new()
	r.display_name = "Tutorial"
	r.target = 0
	r.reward = 2
	r.stopwatches = [_stopwatch(5000, 1, 0.5, [])] as Array[StopwatchDef]
	return r


## Round 2: the same stopwatch, now asking for a lock on a round number.
func _second() -> RoundDef:
	var r := RoundDef.new()
	r.display_name = "Tutorial"
	r.target = 10
	r.reward = 3
	r.stopwatches = [_stopwatch(5000, 1, 0.5, [_combo(ComboCatalog.Kind.ROUND)])] as Array[StopwatchDef]
	return r


## Round 3: three locks on an even stopwatch, plus the consecutive button. The
## target is out of reach without spending the button, which is the lesson.
func _third() -> RoundDef:
	var r := RoundDef.new()
	r.display_name = "Tutorial"
	r.target = 30
	r.reward = 4
	r.stopwatches = [_stopwatch(5000, 3, 0.5, [_combo(ComboCatalog.Kind.EVEN)])] as Array[StopwatchDef]
	return r


## Round 4: two stopwatches and a real target, with the Round Robin card handed
## over to help.
func _fourth() -> RoundDef:
	var r := RoundDef.new()
	r.display_name = "Tutorial"
	r.target = 500
	r.reward = 5
	# "Random combos from the generator", but re-rolled until they overlap on some
	# decimal. Otherwise the set can be so scattered that the 500 the script asks
	# for is out of reach and the player is stuck retrying the last step.
	var second := _stopwatch(3000, 5, 1.0, _anchored_combos())
	r.stopwatches = [
		_stopwatch(5000, 3, 0.5, [_combo(ComboCatalog.Kind.EVEN)]),
		second,
	] as Array[StopwatchDef]
	return r


## The hand dealt for the current step: only the third round gets a button, and
## it is always the consecutive one the script talks about.
func buttons() -> Array[ButtonDef]:
	if step != 2:
		return [] as Array[ButtonDef]
	for b: ButtonDef in ButtonCatalog.pool():
		if b.id == &"consecutive":
			return [b] as Array[ButtonDef]
	return [] as Array[ButtonDef]


## The card handed over for the current step, or null.
func card() -> Card:
	if step != 3:
		return null
	for c: Card in CardCatalog.pool():
		if c.id == &"round_robin":
			return c
	return null


## Three rolled combos that share a decimal, so locking well pays all of them at
## once and the final target is comfortably reachable.
func _anchored_combos() -> Array[ComboDef]:
	var best: Array[ComboDef] = []
	var best_overlap: int = -1
	for attempt in 20:
		var set: Array[ComboDef] = ComboCatalog.roll_combos(_rng, 3, 0)
		var overlap: int = _best_overlap(set)
		if overlap > best_overlap:
			best_overlap = overlap
			best = set
		if overlap >= 2:
			break
	return best


## The most positive combos in `set` that a single decimal satisfies.
func _best_overlap(set: Array[ComboDef]) -> int:
	var best: int = 0
	for d in 10:
		var n: int = 0
		for c: ComboDef in set:
			if not c.negative and c.digits.has(d):
				n += 1
		best = maxi(best, n)
	return best


func _combo(kind: ComboCatalog.Kind) -> ComboDef:
	return ComboCatalog.roll_positive_of_kind(_rng, kind)


func _stopwatch(duration: int, clicks: int, rate: float, combos: Array) -> StopwatchDef:
	var s := StopwatchDef.new()
	s.duration_ms = duration
	s.clicks = clicks
	s.rate = rate
	s.face = &"default"
	var typed: Array[ComboDef] = []
	for c: ComboDef in combos:
		typed.append(c)
	s.combos = typed
	return s
