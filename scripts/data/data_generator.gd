class_name DataGenerator
extends RefCounted
## Rolls the data a run needs - rounds, stopwatches, buttons and shop cards - and
## ramps the difficulty lap by lap, topping out around lap 6.
##
## Stopwatches are built from archetypes crossing a duration (short / medium /
## long), a click count (low / medium / high) and a rate (slow / medium / fast).
## The base duration and click count grow with the lap, so later stopwatches run
## longer and take more locks, which is what lets them reach the bigger targets.
## The target itself is derived from what a round's stopwatches can realistically
## pay out, then snapped to a round number.

const FACE_POOL: Array[StringName] = [&"default", &"grey", &"purple", &"pink", &"digital"]

## Difficulty stops climbing here (issue: max difficulty around lap 5-7).
const MAX_TIER: int = 6
const MAX_STOPWATCHES: int = 3
const MAX_POSITIVE_COMBOS: int = 3
const MAX_NEGATIVE_COMBOS: int = 3
const BASE_MAX_BUTTONS: int = 3

enum Duration { SHORT, MEDIUM, LONG }
enum Clicks { LOW, MEDIUM, HIGH }
enum Rate { SLOW, MEDIUM, FAST }

## The five hand-picked stopwatch shapes from the balance issue.
const ARCHETYPES: Array = [
	[Duration.SHORT, Clicks.HIGH, Rate.MEDIUM],
	[Duration.LONG, Clicks.LOW, Rate.MEDIUM],
	[Duration.MEDIUM, Clicks.MEDIUM, Rate.MEDIUM],
	[Duration.LONG, Clicks.HIGH, Rate.FAST],
	[Duration.SHORT, Clicks.LOW, Rate.SLOW],
]

## Stopwatches per normal round, per lap. The last entry repeats for later laps.
const ROUND_SHAPES: Array = [
	[1, 1, 2],
	[1, 2, 2],
	[2, 2, 3],
	[2, 3, 3],
]

## A target is a fraction of what the round can realistically pay, so it is
## always reachable; it climbs because later rounds have more stopwatches, more
## combos and more locks. The fraction tightens as a lap goes on.
const ROUND_FACTOR: Array[float] = [0.6, 0.7, 0.8]
const BOSS_FACTOR: float = 0.85
## A target may never exceed this share of what perfect play would pay.
const CEILING_SHARE: float = 0.7
const MIN_TARGET: int = 10
const MAX_CLICKS: int = 12
const MIN_CLICKS: int = 2
## Clock milliseconds to allow per lock, so a stopwatch always has room for the
## locks it asks for. A Straight needs a whole second per step (each lock has to
## land one decimal further on), so it gets the roomier budget.
const MS_PER_CLICK: int = 500
const MS_PER_CLICK_STRAIGHT: int = 1000

var rng: RandomNumberGenerator
var rounds_made: int = 0
## Card ids already offered in the shop this run, so fresh cards are favoured.
var _offered: Dictionary = {}
## No round in a lap may ask for less than the one before it, and a new lap picks
## up from part of the last boss so the run keeps trending upwards.
var _floor: int = 0
var _last_boss: int = 0


func _init(run_rng: RandomNumberGenerator) -> void:
	rng = run_rng


## How hard the game should be on this lap. Climbs to MAX_TIER and stops.
func tier(lap: int) -> int:
	return mini(lap, MAX_TIER)


# --- rounds -----------------------------------------------------------------

## The round for a lap and its index within that lap. The last round of a lap is
## always the boss.
func next_round(lap: int, index_in_lap: int, rounds_per_lap: int) -> RoundDef:
	rounds_made += 1
	# A fresh lap opens easier than the boss that closed the last one, but not
	# all the way back to the start.
	if index_in_lap == 0:
		_floor = int(_last_boss * 0.6)
	if index_in_lap == rounds_per_lap - 1:
		var boss: RoundDef = _boss_round(lap)
		_last_boss = boss.target
		return boss
	return _normal_round(lap, index_in_lap)


func _normal_round(lap: int, index_in_lap: int) -> RoundDef:
	var r := RoundDef.new()
	r.display_name = "Round %d" % (index_in_lap + 1)
	var count: int = _stopwatch_count(lap, index_in_lap)
	for i in count:
		r.stopwatches.append(_make_stopwatch(lap, _positive_count(lap), 0))
	r.target = _target_for(r.stopwatches,
		ROUND_FACTOR[mini(index_in_lap, ROUND_FACTOR.size() - 1)], tier(lap))
	r.reward = 3 + index_in_lap
	return r


## The boss closing a lap: the hardest target, two or three stopwatches (always
## three from lap 2 on), and at least one voiding negative combo on each.
func _boss_round(lap: int) -> RoundDef:
	var r := RoundDef.new()
	r.is_boss = true
	r.display_name = "Boss"
	var count: int = 2 if lap <= 1 else MAX_STOPWATCHES
	var negatives: int = clampi(1 + (tier(lap) - 1) / 2, 1, MAX_NEGATIVE_COMBOS)
	for i in count:
		r.stopwatches.append(_make_stopwatch(lap, _positive_count(lap), negatives))
	r.target = _target_for(r.stopwatches, BOSS_FACTOR, tier(lap))
	r.reward = 6 + lap
	return r


func _stopwatch_count(lap: int, index_in_lap: int) -> int:
	var shape: Array = ROUND_SHAPES[mini(lap, ROUND_SHAPES.size()) - 1]
	return shape[mini(index_in_lap, shape.size() - 1)]


## Combos come in slowly: one on the first lap, up to three deep in a run.
func _positive_count(lap: int) -> int:
	var t: int = tier(lap)
	if t <= 1:
		return 1
	if t <= 3:
		return rng.randi_range(1, 2)
	return rng.randi_range(2, MAX_POSITIVE_COMBOS)


# --- stopwatches ------------------------------------------------------------

func _make_stopwatch(lap: int, positives: int, negatives: int) -> StopwatchDef:
	var t: int = tier(lap)
	var shape: Array = ARCHETYPES[rng.randi_range(0, ARCHETYPES.size() - 1)]
	var s := StopwatchDef.new()
	s.duration_ms = _duration_ms(shape[0], t)
	# Early rounds stay short and readable; the ceiling opens up lap by lap.
	s.clicks = clampi(_click_count(shape[1], t), MIN_CLICKS, _click_cap(t))
	s.rate = _rate(shape[2])
	s.face = FACE_POOL[rng.randi_range(0, FACE_POOL.size() - 1)]
	s.combos = ComboCatalog.roll_combos(rng,
		mini(positives, MAX_POSITIVE_COMBOS), mini(negatives, MAX_NEGATIVE_COMBOS))
	# However many locks it ended up with, leave enough clock to make them.
	s.duration_ms = maxi(s.duration_ms, s.clicks * _ms_per_click(s))
	return s


## The most locks a stopwatch may ask for on a given tier.
func _click_cap(t: int) -> int:
	return clampi(3 + t, 4, MAX_CLICKS)


## Base durations grow with the lap so later stopwatches have room for the locks
## needed to hit a bigger target.
func _duration_ms(duration: Duration, t: int) -> int:
	var step: int = t - 1
	match duration:
		Duration.SHORT:
			return 3000 + 300 * step
		Duration.LONG:
			return 8000 + 800 * step
		_:
			return 5000 + 500 * step


func _click_count(clicks: Clicks, t: int) -> int:
	var bonus: int = (t - 1) / 2      # the whole band shifts up every other lap
	match clicks:
		Clicks.LOW:
			return rng.randi_range(2, 3) + bonus
		Clicks.HIGH:
			return rng.randi_range(5, 7) + bonus
		_:
			return rng.randi_range(3, 5) + bonus


func _rate(rate: Rate) -> float:
	match rate:
		Rate.SLOW:
			return 0.5
		Rate.FAST:
			return 1.0
		_:
			return 0.7


# --- targets ----------------------------------------------------------------

## Roughly what a stopwatch pays a decent player, using each combo's own idea of
## how often it lands. Targets are derived from this, so it has to be honest.
func _par_score(s: StopwatchDef) -> int:
	var points: float = 0.0
	var mult: float = 1.0
	for combo: ComboDef in s.combos:
		if combo.negative:
			continue
		# Each combo knows how often it really lands - a straight fires once at
		# most, a named digit is one decimal in ten.
		var landed: float = combo.expected_hits(s.clicks)
		points += float(combo.bonus_points) * landed
		mult += float(combo.bonus_mult) * landed
	return int(points * mult)


## A fraction of what the round can realistically pay, snapped to a round number.
## Small targets snap to 25 so the opening rounds are not pushed up to 50.
##
## If that lands under the lap's floor the round is GROWN until it can pay more,
## rather than the target simply being raised - a target the stopwatches cannot
## reach is exactly what makes a round feel impossible.
func _target_for(stopwatches: Array[StopwatchDef], factor: float, tier_now: int) -> int:
	for attempt in 40:
		var goal: float = float(_par_total(stopwatches)) * factor
		if _snap(goal) >= _floor or not _grow(stopwatches, tier_now):
			break
	var target: int = maxi(_snap(float(_par_total(stopwatches)) * factor), _floor)
	# Never ask for more than perfect play could pay - being behind the curve is
	# far better than being impossible.
	target = mini(target, _snap(float(_ceiling_total(stopwatches)) * CEILING_SHARE))
	target = maxi(target, MIN_TARGET)
	_floor = target
	return target


## What the round pays if every lock lands on every combo riding on it.
func _ceiling_total(stopwatches: Array[StopwatchDef]) -> int:
	var total: int = 0
	for s: StopwatchDef in stopwatches:
		var points: int = 0
		var mult: int = 1
		for combo: ComboDef in s.combos:
			if combo.negative:
				continue
			var n: int = combo.max_hits(s.clicks)
			points += combo.bonus_points * n
			mult += combo.bonus_mult * n
		total += points * mult
	return total


func _par_total(stopwatches: Array[StopwatchDef]) -> int:
	var par: int = 0
	for s: StopwatchDef in stopwatches:
		par += _par_score(s)
	return par


func _snap(goal: float) -> int:
	var step: int = 10
	if goal >= 100.0:
		step = 25
	if goal >= 500.0:
		step = 100
	elif goal >= 200.0:
		step = 50
	return maxi(step, int(round(goal / float(step))) * step)


## Give the round one more lock, on whichever stopwatch has fewest. Returns false
## once every one of them has hit the tier's ceiling.
func _grow(stopwatches: Array[StopwatchDef], tier_now: int) -> bool:
	var cap: int = _click_cap(tier_now)
	var lightest: StopwatchDef = null
	for s: StopwatchDef in stopwatches:
		if s.clicks < cap and (lightest == null or s.clicks < lightest.clicks):
			lightest = s
	if lightest == null:
		return false
	lightest.clicks += 1
	lightest.duration_ms = maxi(lightest.duration_ms, lightest.clicks * _ms_per_click(lightest))
	return true


## How much clock a stopwatch needs per lock, given the combos riding on it.
func _ms_per_click(s: StopwatchDef) -> int:
	for c: ComboDef in s.combos:
		if not c.negative and c.digits.is_empty():
			return MS_PER_CLICK_STRAIGHT
	return MS_PER_CLICK


# --- buttons ----------------------------------------------------------------

## How many buttons a round deals: one to start with, then one per stopwatch, up
## to the cap (which cards can raise).
func button_count(lap: int, stopwatches: int, max_buttons: int) -> int:
	if tier(lap) <= 1 and stopwatches <= 1:
		return 1
	return clampi(stopwatches, 1, max_buttons)


func deal_buttons(count: int) -> Array[ButtonDef]:
	var hand: Array[ButtonDef] = []
	for i in count:
		var fresh: Array[ButtonDef] = ButtonCatalog.pool()
		hand.append(fresh[rng.randi_range(0, fresh.size() - 1)])
	return hand


# --- cards ------------------------------------------------------------------

## Cards offered in the shop. Owned cards are never offered, and cards the shop
## has not shown yet this run come first, so the deck keeps growing sideways.
func shop_cards(count: int, owned: Array[StringName]) -> Array[Card]:
	var fresh: Array[Card] = []
	var seen: Array[Card] = []
	for c: Card in CardCatalog.pool():
		if owned.has(c.id):
			continue
		if _offered.has(c.id):
			seen.append(c)
		else:
			fresh.append(c)
	_shuffle(fresh)
	_shuffle(seen)
	var picked: Array[Card] = (fresh + seen).slice(0, mini(count, fresh.size() + seen.size()))
	for c: Card in picked:
		_offered[c.id] = true
	return picked


## The cards a fresh run starts with.
func starting_cards() -> Array[Card]:
	var start: Array[Card] = []
	for c: Card in CardCatalog.pool():
		if c.id == &"decimal_dollars":
			start.append(c)
	return start


## Seeded Fisher-Yates so a run's shop is reproducible from its RNG.
func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
