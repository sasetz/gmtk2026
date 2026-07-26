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

## Targets follow an authored curve rather than whatever the dice produced, so
## the climb is steady; the stopwatches are then scaled to be able to meet it.
const TARGET_BASE: float = 50.0
const LAP_GROWTH: float = 1.7
const ROUND_WEIGHT: Array[float] = [1.0, 1.8, 2.6]
const BOSS_WEIGHT: float = 4.0
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
## Targets never go backwards over a run.
var _last_target: int = 0


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
	if index_in_lap == rounds_per_lap - 1:
		return _boss_round(lap)
	return _normal_round(lap, index_in_lap)


func _normal_round(lap: int, index_in_lap: int) -> RoundDef:
	var r := RoundDef.new()
	r.display_name = "Round %d" % (index_in_lap + 1)
	var count: int = _stopwatch_count(lap, index_in_lap)
	for i in count:
		r.stopwatches.append(_make_stopwatch(lap, _positive_count(lap), 0))
	r.target = _next_target(lap, ROUND_WEIGHT[mini(index_in_lap, ROUND_WEIGHT.size() - 1)])
	_fit_to_target(r.stopwatches, r.target)
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
	r.target = _next_target(lap, BOSS_WEIGHT)
	_fit_to_target(r.stopwatches, r.target)
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
	s.clicks = _click_count(shape[1], t)
	s.rate = _rate(shape[2])
	s.face = FACE_POOL[rng.randi_range(0, FACE_POOL.size() - 1)]
	s.combos = ComboCatalog.roll_combos(rng,
		mini(positives, MAX_POSITIVE_COMBOS), mini(negatives, MAX_NEGATIVE_COMBOS))
	return s


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

## Roughly what a stopwatch pays if the player lands about half of its locks on
## each positive combo. Used to keep targets in step with what the round can
## actually produce.
func _par_score(s: StopwatchDef) -> int:
	var landed: float = maxf(1.0, float(s.clicks) * 0.5)
	var points: float = 0.0
	var mult: float = 1.0
	for combo: ComboDef in s.combos:
		if combo.negative:
			continue
		points += float(combo.bonus_points) * landed
		mult += float(combo.bonus_mult) * landed
	return int(points * mult)


## The next target on the curve: it climbs with the lap and with the round's
## place in that lap, snaps to a round number, wobbles slightly, and never drops
## below the previous round's.
func _next_target(lap: int, weight: float) -> int:
	var goal: float = TARGET_BASE * pow(LAP_GROWTH, float(tier(lap) - 1)) * weight
	var step: int = 50 if goal < 500.0 else 100
	var snapped: int = int(round(goal / float(step))) * step
	snapped += step * rng.randi_range(0, 1)        # a little random
	snapped = maxi(snapped, _last_target + step)   # always a step forward
	_last_target = snapped
	return snapped


## Grow (or trim) the round's stopwatches until they can plausibly pay the
## target: more locks means more combo hits, and each stopwatch keeps enough
## clock to make them.
func _fit_to_target(stopwatches: Array[StopwatchDef], target: int) -> void:
	if stopwatches.is_empty():
		return
	for pass_index in 60:
		var par: int = 0
		for s: StopwatchDef in stopwatches:
			par += _par_score(s)
		if par >= int(target * 0.9) and par <= int(target * 1.6):
			break
		if par < int(target * 0.9):
			var lightest: StopwatchDef = _pick_by_clicks(stopwatches, true)
			if lightest.clicks >= MAX_CLICKS:
				break
			lightest.clicks += 1
		else:
			var heaviest: StopwatchDef = _pick_by_clicks(stopwatches, false)
			if heaviest.clicks <= MIN_CLICKS:
				break
			heaviest.clicks -= 1
	for s: StopwatchDef in stopwatches:
		s.duration_ms = maxi(s.duration_ms, s.clicks * _ms_per_click(s))


## How much clock a stopwatch needs per lock, given the combos riding on it.
func _ms_per_click(s: StopwatchDef) -> int:
	for c: ComboDef in s.combos:
		if not c.negative and c.digits.is_empty():
			return MS_PER_CLICK_STRAIGHT
	return MS_PER_CLICK


func _pick_by_clicks(stopwatches: Array[StopwatchDef], fewest: bool) -> StopwatchDef:
	var best: StopwatchDef = stopwatches[0]
	for s: StopwatchDef in stopwatches:
		if (s.clicks < best.clicks) == fewest and s.clicks != best.clicks:
			best = s
	return best


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
