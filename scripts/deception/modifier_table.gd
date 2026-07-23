class_name ModifierTable
extends RefCounted
## Resolves stopped times through the face-up table of conditional modifiers, and
## provides the solver the generator needs.
##
## Reuses the ORIGINAL engine: ScoringRules turns a stopped time into base
## {points, mult} + the properties it matched. Table cards then fire.
##
## Multi-stop rule: a BUFF card fires only the FIRST time its property is hit in
## a round (tracked via `fired`), so spamming one property is weak — you must hit
## a MIX of buffed properties. TRAP (void) cards fire every time. That's what
## makes multiple stops a real sequencing decision, not one repeated tap.

## Canonical time for each aimable property (what the player targets on a stop).
const CANON := {
	&"odd": [6300, 1],       # 06:3  odd only
	&"even": [6200, 1],      # 06:2  even only
	&"round": [3000, 1],     # 03:0  round only
	&"straight": [5500, 1],  # 05:5  straight + odd  (high base)
	&"the_one": [1000, 1],   # 01:0  round + THE ONE (highest base)
}
const AIMABLE := [&"odd", &"even", &"round", &"straight", &"the_one"]


## Fraction the score keeps the 2nd, 3rd… time the SAME kind of time is hit in a
## round. Punishes spamming one property, so multiple stops demand a real mix.
const REPEAT_DECAY: float = 0.4


## Resolve one stop. `fired` = buff cards already used this round; `hit_keys` =
## how many times each time-"kind" was already hit (for the repeat penalty). The
## caller appends `fired_cards` to `fired` and increments `hit_keys[key]`.
##
## `ctx` (optional DeceptionContext) layers the player's OWNED jokers onto the
## resolution: disabled traps are skipped, would-be-voids can be rescued
## (immunity), the first buff can echo, and score-jokers add to the stop. When
## `ctx` is null this runs the pure baseline the generator's solver/fuzz rely on,
## so board fairness is proven independently of any loadout.
static func resolve(time_ms: int, tier: int, cards: Array, fired: Array = [],
		hit_keys: Dictionary = {}, ctx: DeceptionContext = null) -> Dictionary:
	var base: Dictionary = ScoringRules.evaluate(time_ms, tier)
	var conditions: Array = []
	for c: Dictionary in base["conditions"]:
		conditions.append(c["name"])
	if base["bad"]:
		conditions.append(&"bad")
	var key: String = ",".join(conditions) if not conditions.is_empty() else "none"
	var first_of_kind: bool = int(hit_keys.get(key, 0)) == 0

	var points: int = int(base["points"])
	var mult: float = float(base["mult"])
	var voided: bool = false
	var steps: Array[String] = []
	var fired_cards: Array = []
	steps.append("stop %s → base %d × %d  (%s)" % [
		base["digits"]["display"], points, int(mult), key,
	])

	for card: TimerModCard in cards:
		if not card.fires_for(conditions):
			continue
		if ctx != null and card in ctx.disabled_cards:
			steps.append("%s DISABLED (Trap Cutter)" % card.text)
			continue
		if card.voids:
			if ctx != null and ctx.immunities_left > 0:
				ctx.immunities_left -= 1
				steps.append("⛑ %s: VOID ignored (Life Vest)" % card.text)
				continue
			voided = true
			steps.append("⚠ %s: VOID → 0" % card.text)
			continue
		if card in fired:
			steps.append("%s already used this round" % card.text)
			continue
		points += card.add_points
		mult += card.add_mult
		if not is_equal_approx(card.xmult, 1.0):
			mult *= card.xmult
		fired_cards.append(card)
		steps.append("%s → %d × %.0f" % [card.text, points, mult])
		# Echo: the first buff to fire this round fires again (JokerEcho).
		if ctx != null and ctx.echo_left > 0 and not ctx.echo_spent:
			for _e in ctx.echo_left:
				points += card.add_points
				mult += card.add_mult
				if not is_equal_approx(card.xmult, 1.0):
					mult *= card.xmult
			steps.append("↻ Echo: %s fires again → %d × %.0f" % [card.text, points, mult])
			ctx.echo_spent = true
			ctx.echo_left = 0

	# Score-jokers add to THIS stop (board order; xmult picks up the +mult to its
	# left), before the final multiply. A dead (voided) stop scores 0 regardless.
	if ctx != null and not voided:
		var stop_info := {
			"conditions": conditions, "key": key, "first_of_kind": first_of_kind,
			"voided": voided, "points": points, "mult": mult,
		}
		for j in ctx.jokers:
			var eff: Dictionary = j.on_stop(stop_info)
			if eff.is_empty():
				continue
			points += int(eff.get("points", 0))
			mult += float(eff.get("mult", 0.0))
			if eff.has("xmult"):
				mult *= float(eff["xmult"])
			stop_info["points"] = points
			stop_info["mult"] = mult
			steps.append("%s → %d × %.0f" % [j.display_name, points, mult])

	var score: float = 0.0 if voided else float(points) * mult
	var prior: int = int(hit_keys.get(key, 0))
	if prior > 0 and not voided:
		var decay: float = pow(REPEAT_DECAY, prior)
		steps.append("repeat (%d× this kind) → ×%.2f" % [prior + 1, decay])
		score *= decay

	return {
		"score": max(int(round(score)), 0),
		"points": points,
		"mult": mult,
		"voided": voided,
		"fired_cards": fired_cards,
		"key": key,
		"base_display": base["digits"]["display"],
		"conditions": conditions,
		"steps": steps,
	}


## Best achievable round score: the max over all length-`stops` sequences of
## aimable properties (order matters because buffs fire once). Returns
## {score, seq}. This is what a perfect reader could get.
static func solve(cards: Array, stops: int) -> Dictionary:
	var best: int = -1
	var best_seq: Array = []
	for seq: Array in _sequences(stops):
		var fired: Array = []
		var hit_keys: Dictionary = {}
		var total: int = 0
		for prop: StringName in seq:
			var t: Array = CANON[prop]
			var r: Dictionary = resolve(t[0], t[1], cards, fired, hit_keys)
			total += int(r["score"])
			fired.append_array(r["fired_cards"])
			hit_keys[r["key"]] = int(hit_keys.get(r["key"], 0)) + 1
		if total > best:
			best = total
			best_seq = seq
	return {"score": best, "seq": best_seq}


## The greedy player: chases the single highest-BASE property (ignoring the
## table's traps) and hits it every stop. Used to prove the trap bites.
static func naive(cards: Array, stops: int) -> Dictionary:
	var top: StringName = &"odd"
	var top_base: int = -1
	for prop: StringName in AIMABLE:
		var t: Array = CANON[prop]
		var b: Dictionary = ScoringRules.evaluate(t[0], t[1])
		var base: int = int(b["points"]) * int(b["mult"])
		if base > top_base:
			top_base = base
			top = prop
	var fired: Array = []
	var hit_keys: Dictionary = {}
	var total: int = 0
	for i in stops:
		var t: Array = CANON[top]
		var r: Dictionary = resolve(t[0], t[1], cards, fired, hit_keys)
		total += int(r["score"])
		fired.append_array(r["fired_cards"])
		hit_keys[r["key"]] = int(hit_keys.get(r["key"], 0)) + 1
	return {"score": total, "prop": top}


## The best a "spam one property" line can do (with the repeat decay). The
## target must sit ABOVE this so a mix is genuinely required, and below `solve`
## so a good read clears it.
static func best_spam(cards: Array, stops: int) -> int:
	var best: int = 0
	for prop: StringName in AIMABLE:
		var fired: Array = []
		var hit_keys: Dictionary = {}
		var total: int = 0
		var t: Array = CANON[prop]
		for _s in stops:
			var r: Dictionary = resolve(t[0], t[1], cards, fired, hit_keys)
			total += int(r["score"])
			fired.append_array(r["fired_cards"])
			hit_keys[r["key"]] = int(hit_keys.get(r["key"], 0)) + 1
		best = maxi(best, total)
	return best


static func _sequences(stops: int) -> Array:
	var out: Array = [[]]
	for _i in stops:
		var next: Array = []
		for seq: Array in out:
			for prop: StringName in AIMABLE:
				next.append(seq + [prop])
		out = next
	return out
