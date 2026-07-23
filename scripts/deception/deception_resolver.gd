class_name DeceptionResolver
extends RefCounted
## Resolves a picked set of VALUE cards under the board's always-active RULE
## cards, left-to-right, and returns the score plus a step-by-step breakdown.
##
## Every input is fully visible to the player — this function computes exactly
## what a perfect reader could have computed in their head. The "deception" is
## only that tracing the rule interactions is non-obvious under a clock; the
## breakdown is what the post-round screen shows so a fooled player sees WHY.
##
## Score model: score = points x mult, mult starts at 1 (so a lone points card
## scores points x 1). Additive mult from cards; rules can override.

## picked, rules: Array[TableCard]. rules resolve in board order after the picks
## are summed. Returns {points, mult, score, steps: Array[String]}.
static func resolve(picked: Array, rules: Array) -> Dictionary:
	var steps: Array[String] = []
	var points: int = 0
	var mult: int = 1

	for c in picked:
		points += c.points
		mult += c.mult
		steps.append("take %s  (+%d pts, +%d mult)" % [c.label, c.points, c.mult])

	for r in rules:
		match r.effect:
			&"lock_mult":
				if mult != 1:
					steps.append("RULE %s: mult %d → 1" % [r.label, mult])
					mult = 1
			&"highest_negative":
				var hi: TableCard = _highest_points(picked)
				if hi != null and hi.points > 0:
					points -= 2 * hi.points
					steps.append("RULE %s: %s's +%d flips to −%d" % [r.label, hi.label, hi.points, hi.points])
			&"even_count_bonus":
				# Reward for an all-even-count pick; a trap when you break it.
				if picked.size() > 0 and picked.size() % 2 == 0:
					mult += 3
					steps.append("RULE %s: even number of picks → +3 mult" % r.label)
			&"mult_cards_void_points":
				# Any picked card carrying mult contributes 0 points.
				var lost: int = 0
				for c in picked:
					if c.mult > 0:
						lost += c.points
				if lost > 0:
					points -= lost
					steps.append("RULE %s: mult-cards give 0 pts (−%d)" % [r.label, lost])
			&"lowest_double":
				# The lowest-points picked card scores double — rewards a small card.
				var lo: TableCard = _lowest_points(picked)
				if lo != null and lo.points > 0:
					points += lo.points
					steps.append("RULE %s: %s's +%d doubles" % [r.label, lo.label, lo.points])
			&"mult_cap":
				# Over-stacking mult backfires: mult above 5 collapses to 1.
				if mult > 5:
					steps.append("RULE %s: mult %d over cap → 1" % [r.label, mult])
					mult = 1

	var score: int = points * mult
	return {"points": points, "mult": mult, "score": max(score, 0), "steps": steps}


## What a GREEDY player scores in their head: they ignore the rules and just
## maximize points x (1 + sum of mult). Used to prove the trap works — the
## greedy pick should score worse (once rules bite) than the correct read.
static func naive_best(values: Array, pick_k: int) -> Dictionary:
	var best: Array = []
	var best_naive: int = -99999
	for combo in _combos(values, pick_k):
		var p: int = 0
		var m: int = 1
		for c in combo:
			p += c.points
			m += c.mult
		var naive: int = p * m
		if naive > best_naive:
			best_naive = naive
			best = combo
	return {"pick": best, "naive_score": best_naive}


## The genuinely best pick once rules are applied.
static func true_best(values: Array, rules: Array, pick_k: int) -> Dictionary:
	var best: Array = []
	var best_score: int = -99999
	for combo in _combos(values, pick_k):
		var r: Dictionary = resolve(combo, rules)
		if r["score"] > best_score:
			best_score = r["score"]
			best = combo
	return {"pick": best, "score": best_score}


static func _highest_points(cards: Array) -> TableCard:
	var hi: TableCard = null
	for c in cards:
		if hi == null or c.points > hi.points:
			hi = c
	return hi


static func _lowest_points(cards: Array) -> TableCard:
	var lo: TableCard = null
	for c in cards:
		if lo == null or c.points < lo.points:
			lo = c
	return lo


## All non-empty subsets of `items` up to size k.
static func _combos(items: Array, k: int) -> Array:
	var out: Array = []
	var n: int = items.size()
	for mask in range(1, 1 << n):
		var pick: Array = []
		for i in n:
			if mask & (1 << i):
				pick.append(items[i])
		if pick.size() <= k:
			out.append(pick)
	return out
