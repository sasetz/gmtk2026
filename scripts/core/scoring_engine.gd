class_name ScoringEngine
extends RefCounted
## The generic scoring loop. It never knows any joker's identity — it just calls
## the same hooks on each card in board order and applies whatever struct comes
## back. Adding card #13 is a .tres + a tiny script, no change here.
##
## Two passes, both left-to-right:
##   1. reactive — for every beat, every joker gets on_score_eval (this single
##      per-beat call covers all "when you hit an N" cards);
##   2. main    — every joker gets on_final_scoring once (flat +mult, ×mult,
##      positional cards). Order matters here: a ×mult picks up the +mult to its
##      left.
##
## Returns the ScoringContext, mutated, so callers can read points/mult/score and
## the reveal can replay the same order.

## `log` (optional) is filled with ordered animation steps for the reveal:
##   {type:"beat", index, beat, points, mult}   — running totals after that beat
##   {type:"joker", index, joker, effect, points, mult}
static func score(presses: Array, jokers: Array, target: int,
		rng: RandomNumberGenerator, log: Array = [], boss_id: StringName = &"") -> ScoringContext:
	# Bosses may nullify some conditions on the presses themselves (The Mirror).
	var effective_presses: Array = presses
	if boss_id != &"":
		effective_presses = []
		for p: Dictionary in presses:
			effective_presses.append(BossMods.transform_press(boss_id, p))

	var ctx := ScoringContext.new(effective_presses, target, rng)
	ctx.jokers = jokers
	ctx.presses = []
	ctx.presses.assign(presses)  # keep the ORIGINAL for display; score the effective

	# Pass 1 — each beat adds its base, then reactive jokers fire on it (L→R).
	for i: int in effective_presses.size():
		ctx.current_index = i
		ctx.current_beat = effective_presses[i]
		ctx.points += int(effective_presses[i]["points"])
		ctx.mult += float(effective_presses[i]["mult"])
		for ji: int in jokers.size():
			ctx.current_joker_index = ji
			ctx.apply(BossMods.transform_joker_effect(boss_id, jokers[ji].on_score_eval(ctx)))
		log.append({"type": "beat", "index": i, "beat": presses[i],
			"points": ctx.points, "mult": ctx.mult})

	# Pass 2 — each joker's own contribution, in board order. Order matters: a
	# ×mult picks up the +mult to its left.
	for ji: int in jokers.size():
		ctx.current_joker_index = ji
		var eff: Dictionary = BossMods.transform_joker_effect(boss_id, jokers[ji].on_final_scoring(ctx))
		if not eff.is_empty():
			ctx.apply(eff)
			log.append({"type": "joker", "index": ji, "joker": jokers[ji],
				"effect": eff, "points": ctx.points, "mult": ctx.mult})

	ctx.current_beat = {}
	ctx.current_index = -1
	ctx.current_joker_index = -1
	return ctx
