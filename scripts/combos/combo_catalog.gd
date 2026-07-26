class_name ComboCatalog
extends RefCounted
## Rolls the combos that dress a stopwatch. Combos are drawn by KIND, not by
## instance: the ten "ends in N" combos share a single slot in the pool so they
## are no more likely to appear than any other combo. Positives pay points and
## mult; negatives void the whole stopwatch if they land.
##
## roll_combos() builds a set that is actually playable - no duplicates, and no
## negative that contradicts a positive or blocks so many digits that the
## stopwatch cannot be scored at all.

enum Kind { EVEN, ODD, ROUND, STRAIGHT, DIGIT }

const POSITIVE_KINDS: Array[Kind] = [Kind.EVEN, Kind.ODD, Kind.ROUND, Kind.STRAIGHT, Kind.DIGIT]
## Voiding on a straight is nearly unavoidable, so negatives stick to the
## digit-shaped kinds.
const NEGATIVE_KINDS: Array[Kind] = [Kind.EVEN, Kind.ODD, Kind.DIGIT]
## A stopwatch always has to leave at least this many decimals safe to lock on.
const MIN_FREE_DIGITS: int = 3
const TRIES: int = 12


## A coherent set of combos for one stopwatch: `positives` scoring ones followed
## by `negatives` voiding ones. May return fewer negatives than asked if no more
## can be added without making the stopwatch unplayable.
static func roll_combos(rng: RandomNumberGenerator, positives: int, negatives: int) -> Array[ComboDef]:
	var chosen: Array[ComboDef] = []
	for i in positives:
		var c: ComboDef = _try_pick(rng, POSITIVE_KINDS, chosen, false)
		if c != null:
			chosen.append(c)
	for i in negatives:
		var c: ComboDef = _try_pick(rng, NEGATIVE_KINDS, chosen, true)
		if c != null:
			chosen.append(c)
	return chosen


## One specific positive combo, for hand-authored stopwatches (the tutorial).
static func roll_positive_of_kind(rng: RandomNumberGenerator, kind: Kind) -> ComboDef:
	return _build(kind, rng, false)


static func _try_pick(rng: RandomNumberGenerator, kinds: Array[Kind],
		chosen: Array[ComboDef], negative: bool) -> ComboDef:
	for attempt in TRIES:
		var candidate: ComboDef = _build(kinds[rng.randi_range(0, kinds.size() - 1)], rng, negative)
		if _fits(candidate, chosen):
			return candidate
	return null


## Is `candidate` compatible with everything picked so far?
static func _fits(candidate: ComboDef, chosen: Array[ComboDef]) -> bool:
	for c: ComboDef in chosen:
		# Never the same combo twice (two "ends in N" differ by their digit).
		if c.id == candidate.id:
			return false
	var digits: Array[int] = candidate.digits
	if candidate.negative:
		for c: ComboDef in chosen:
			if c.negative:
				continue
			# A negative must not punish what a positive rewards, and a straight
			# walks through every parity, so only single digits can be banned
			# alongside one.
			if c.digits.is_empty():
				if digits.size() > 1:
					return false
			elif _overlaps(digits, c.digits):
				return false
		if 10 - _banned(chosen, digits).size() < MIN_FREE_DIGITS:
			return false
	else:
		for c: ComboDef in chosen:
			if c.negative and (_overlaps(digits, c.digits) or (digits.is_empty() and c.digits.size() > 1)):
				return false
			# Rewarding both parities at once means every lock scores - dull.
			if not c.negative and not digits.is_empty() and not c.digits.is_empty():
				if digits.size() == 5 and c.digits.size() == 5 and not _overlaps(digits, c.digits):
					return false
	return true


## Every digit banned once `extra` joins the negatives already chosen.
static func _banned(chosen: Array[ComboDef], extra: Array[int]) -> Array[int]:
	var all: Array[int] = extra.duplicate()
	for c: ComboDef in chosen:
		if not c.negative:
			continue
		for d: int in c.digits:
			if not all.has(d):
				all.append(d)
	return all


static func _overlaps(a: Array[int], b: Array[int]) -> bool:
	for d: int in a:
		if b.has(d):
			return true
	return false


static func _build(kind: Kind, rng: RandomNumberGenerator, negative: bool) -> ComboDef:
	match kind:
		Kind.EVEN:
			return _fill(ComboEven.new(), "even", "Even", "Locks on even decimals.",
				2, 2, negative, [0, 2, 4, 6, 8])
		Kind.ODD:
			return _fill(ComboOdd.new(), "odd", "Odd", "Locks on odd decimals.",
				2, 2, negative, [1, 3, 5, 7, 9])
		Kind.ROUND:
			return _fill(ComboRound.new(), "round", "Round", "Locks on a round number.",
				5, 2, negative, [0])
		Kind.STRAIGHT:
			return _fill(ComboStraight.new(), "straight", "Straight",
				"Locks step up in order.", 5, 2, negative, [])
		_:
			var digit: int = rng.randi_range(0, 9)
			var c := ComboDigit.new()
			c.digit = digit
			return _fill(c, "ends_%d" % digit, "Ends %d" % digit,
				"Locks ending in .%d." % digit, 3, 3, negative, [digit])


static func _fill(c: ComboDef, id: String, name: String, desc: String,
		points: int, mult: int, negative: bool, digits: Array[int]) -> ComboDef:
	c.negative = negative
	c.digits = digits
	if negative:
		c.id = StringName("no_" + id)
		c.display_name = "No " + name
		c.description = desc.replace("Locks", "Voids the stopwatch on locks")
		c.bonus_points = 0
		c.bonus_mult = 0
	else:
		c.id = StringName(id)
		c.display_name = name
		c.description = "%s +%d points, +%d mult each." % [desc, points, mult]
		c.bonus_points = points
		c.bonus_mult = mult
	return c
