class_name TimerTableGenerator
extends RefCounted
## Generates a deceptive modifier table each round, and uses the solver to
## GUARANTEE fairness: a readable property-mix clears the target, while the
## greedy "chase the biggest base" player misses it.
##
## Core trick: the high-base properties (THE ONE, STRAIGHT) are the obvious
## grab — so the generator traps them (void), forcing the reader onto humble
## buffed properties. Occasionally a bait card (+big pts on a trapped property)
## adds a contradiction. Difficulty scales the target and buff sizes.

const HIGH_BASE := [&"the_one", &"straight"]
const LOW := [&"odd", &"even", &"round"]

const PROP_TEXT := {
	&"odd": "ODD", &"even": "EVEN", &"round": "ROUND",
	&"straight": "STRAIGHT", &"the_one": "01:00 (THE ONE)",
}


## Returns {cards, target, stops, best, naive} or a best-effort fallback.
## `boss` makes it meaner: BOTH high-base grabs are always trapped and the target
## sits higher between spam and optimum. It still passes the same fairness gates,
## so a boss board is provably winnable-not-trivial like any other.
static func generate(rng: RandomNumberGenerator, difficulty: int = 1, boss: bool = false) -> Dictionary:
	var stops: int = 3
	var target_ratio: float = 0.50 if boss else 0.40
	for _attempt in 400:
		var cards: Array = []

		# 1) Trap the top base property (THE ONE) always, STRAIGHT often — so the
		#    obvious grab is a void. A boss traps STRAIGHT every time too.
		cards.append(_void(&"the_one"))
		if boss or rng.randf() < 0.75:
			cards.append(_void(&"straight"))

		# 2) Buff two low properties — biased toward the EASY-to-hit ones
		#    (odd/even are ~50% windows) so execution is trivial and the game is
		#    the read, not the reflex. Round (a tight window) shows up less often.
		var buffed: Array = []
		if rng.randf() < 0.7:
			buffed = [&"odd", &"even"]
		else:
			buffed = [&"odd" if rng.randf() < 0.5 else &"even", &"round"]
		cards.append(_buff(buffed[0], rng, difficulty))
		cards.append(_buff(buffed[1], rng, difficulty))

		# 3) Optional contradiction bait: big points on a TRAPPED property.
		if rng.randf() < 0.5:
			var bait_prop: StringName = &"straight" if _has_void(cards, &"straight") else &"the_one"
			cards.append(TimerModCard.make(bait_prop, 200 + difficulty * 60, 0, 1.0, false,
				"%s\n+%d pts" % [PROP_TEXT[bait_prop], 200 + difficulty * 60]))

		_shuffle(cards, rng)

		var best: Dictionary = ModifierTable.solve(cards, stops)
		var naive: Dictionary = ModifierTable.naive(cards, stops)
		var spam: int = ModifierTable.best_spam(cards, stops)
		if best["score"] <= 0:
			continue
		# The mix must beat spamming by a clear margin, else there's no decision.
		if best["score"] < int(spam * 1.35):
			continue
		# Target sits BETWEEN the spam line and the optimum: spamming one property
		# can't reach it (a real mix is required), but a good-but-imperfect read
		# clears it comfortably — so it never feels unreachable.
		var target: int = int(round(float(spam) + target_ratio * (float(best["score"]) - float(spam))))
		if naive["score"] < target and target > spam and target >= 60:
			return {
				"cards": cards, "target": target, "stops": stops,
				"best": best, "naive": naive, "spam": spam, "buffed": buffed,
			}
	# Fallback: a guaranteed-solvable simple board.
	return _fallback(difficulty)


static func _void(prop: StringName) -> TimerModCard:
	return TimerModCard.make(prop, 0, 0, 1.0, true, "%s\nscore → 0" % PROP_TEXT[prop])


static func _buff(prop: StringName, rng: RandomNumberGenerator, difficulty: int) -> TimerModCard:
	# ROUND gets points (its base already has mult); ODD/EVEN get mult (+ some pts).
	if prop == &"round":
		var pts: int = rng.randi_range(120, 180) + difficulty * 20
		return TimerModCard.make(prop, pts, 0, 1.0, false, "ROUND\n+%d pts" % pts)
	var mult: int = rng.randi_range(5, 9) + difficulty
	var pts2: int = rng.randi_range(30, 60)
	return TimerModCard.make(prop, pts2, mult, 1.0, false,
		"%s\n+%d pts, +%d mult" % [PROP_TEXT[prop], pts2, mult])


static func _has_void(cards: Array, prop: StringName) -> bool:
	for c: TimerModCard in cards:
		if c.condition == prop and c.voids:
			return true
	return false


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t


static func _fallback(difficulty: int) -> Dictionary:
	var cards: Array = [
		_void(&"straight"),
		TimerModCard.make(&"round", 150, 0, 1.0, false, "ROUND\n+150 pts"),
		TimerModCard.make(&"odd", 40, 6, 1.0, false, "ODD\n+40 pts, +6 mult"),
	]
	var best: Dictionary = ModifierTable.solve(cards, 3)
	return {
		"cards": cards, "target": int(best["score"] * 0.72), "stops": 3,
		"best": best, "naive": ModifierTable.naive(cards, 3), "buffed": [&"round", &"odd"],
	}
