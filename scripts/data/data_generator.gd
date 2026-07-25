class_name DataGenerator
extends RefCounted
## Hands out the random data points a run needs — rounds, stopwatches, buttons,
## cards — and scales the difficulty as the run goes on. RunManager owns one of
## these and holds its state. The numbers here are a baseline to tune later.

var rng: RandomNumberGenerator
var rounds_made: int = 0


func _init(run_rng: RandomNumberGenerator) -> void:
	rng = run_rng


## The round for a lap + its index within the lap. The last round of a lap is a
## boss. Difficulty climbs with how deep the run is.
func next_round(lap: int, index_in_lap: int, rounds_per_lap: int) -> RoundDef:
	rounds_made += 1
	var difficulty: int = (lap - 1) * rounds_per_lap + index_in_lap
	var boss: bool = index_in_lap == rounds_per_lap - 1
	var r := RoundDef.new()
	r.is_boss = boss
	r.display_name = "Boss" if boss else "Round %d" % (index_in_lap + 1)
	r.target = 150 * (difficulty + 1) * (2 if boss else 1)
	r.reward = 3 + index_in_lap + (2 if boss else 0)
	var count: int = 2 + index_in_lap
	for i in count:
		r.stopwatches.append(_make_stopwatch(difficulty))
	return r


func _make_stopwatch(difficulty: int) -> StopwatchDef:
	var s := StopwatchDef.new()
	s.rate = 1.0 + 0.1 * difficulty
	s.clicks = 3
	s.duration_ms = 5000
	# TODO: draw combos from a pool that widens with difficulty.
	return s


## The hand of consumable buttons dealt at the start of a round.
func deal_buttons(count: int) -> Array[ButtonDef]:
	var hand: Array[ButtonDef] = []
	for i in count:
		var b := ButtonDef.new()
		b.id = &"plus_mult"
		b.display_name = "+2 Mult"
		b.description = "Adds 2 mult to the stopwatch you spend it on."
		b.bonus_mult = 2
		hand.append(b)
	return hand


## The cards a fresh run starts with.
func starting_cards() -> Array[Card]:
	var c := CardDecimalDollars.new()
	c.id = &"decimal_dollars"
	c.display_name = "Decimal Dollars"
	c.description = "Earn $1 for each lock on a consecutive decimal second."
	c.cost = 4
	return [c]
