class_name ComboCatalog
extends RefCounted
## Builds the pool of combos. The DataGenerator draws from here to dress
## stopwatches: positive combos for normal rounds, negatives layered on for
## bosses. Every call returns fresh instances so per-stopwatch state never
## bleeds across rounds.


## The positive combos a normal stopwatch can roll.
static func positives() -> Array[ComboDef]:
	var pool: Array[ComboDef] = []
	pool.append(_named(ComboEven.new(), &"even", "Even", "Locks on even decimals.", 0, 1))
	pool.append(_named(ComboOdd.new(), &"odd", "Odd", "Locks on odd decimals.", 0, 1))
	pool.append(_named(ComboRound.new(), &"round", "Round", "Locks on a round number.", 20, 0))
	pool.append(_named(ComboStraight.new(), &"straight", "Straight", "Locks step up in order.", 0, 4))
	for d in 10:
		var c := ComboDigit.new()
		c.digit = d
		pool.append(_named(c, StringName("ends_%d" % d), "Ends %d" % d,
			"Locks ending in .%d." % d, 15, 0))
	return pool


## The negative combos layered onto boss stopwatches.
static func negatives() -> Array[ComboDef]:
	var pool: Array[ComboDef] = []
	pool.append(_named(ComboOdd.new(), &"no_odd", "No Odd", "Odd locks cost mult.", 0, -1, true))
	pool.append(_named(ComboEven.new(), &"no_even", "No Even", "Even locks cost mult.", 0, -1, true))
	for d in 10:
		var c := ComboDigit.new()
		c.digit = d
		pool.append(_named(c, StringName("avoid_%d" % d), "Avoid %d" % d,
			"Locks ending in .%d cost points." % d, -20, 0, true))
	return pool


static func _named(c: ComboDef, id: StringName, name: String, desc: String,
		points: int, mult: int, negative: bool = false) -> ComboDef:
	c.id = id
	c.display_name = name
	c.description = desc
	c.bonus_points = points
	c.bonus_mult = mult
	c.negative = negative
	return c
