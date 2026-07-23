extends SceneTree
## Proves the core claim of the deception pivot WITHOUT any UI: on a fully
## face-up board, the GREEDY pick (chase the big numbers/mults, ignore the
## rules) scores worse than the pick that TRACES the visible rule interaction —
## and the greedy pick misses the target while the correct read clears it.
##
## Everything the resolver uses is visible to the player, so this is exactly
## what a perfect reader could compute. If this holds, the concept is sound.
##
## Run: godot --headless --path <project> --script res://tools/prove_deception.gd

func _init() -> void:
	_board("Board 1 — 'Dead Air' (mult is a lie)",
		[
			TableCard.value(&"neon", "Neon", 40, 5, "+40, +5 mult"),
			TableCard.value(&"slab", "Slab", 90, 0, "+90"),
			TableCard.value(&"brick", "Brick", 70, 0, "+70"),
			TableCard.value(&"spark", "Spark", 30, 4, "+30, +4 mult"),
		],
		[TableCard.rule(&"deadair", "Dead Air", &"lock_mult", "All mult is locked to 1.")],
		2, 150)

	_board("Board 2 — 'Static' (mult cards pay no points)",
		[
			TableCard.value(&"combo", "Combo", 100, 4, "+100, +4 mult"),
			TableCard.value(&"plain", "Plain", 80, 0, "+80"),
			TableCard.value(&"plain2", "Plate", 75, 0, "+75"),
			TableCard.value(&"tiny", "Tiny", 10, 6, "+10, +6 mult"),
		],
		[TableCard.rule(&"static", "Static", &"mult_cards_void_points", "Cards with mult give 0 points.")],
		2, 150)
	quit()


func _board(name: String, values: Array, rules: Array, pick_k: int, target: int) -> void:
	print("\n=== %s   (pick up to %d, target %d) ===" % [name, pick_k, target])
	print("RULES: " + ", ".join(rules.map(func(r): return "%s — %s" % [r.label, r.text])))
	print("%-16s %8s %8s   %s" % ["pick", "naive", "ACTUAL", "note"])
	var naive: Dictionary = DeceptionResolver.naive_best(values, pick_k)
	var truth: Dictionary = DeceptionResolver.true_best(values, rules, pick_k)

	for combo in DeceptionResolver._combos(values, pick_k):
		var labels: String = "+".join(combo.map(func(c): return c.label))
		var p: int = 0
		var m: int = 1
		for c in combo:
			p += c.points
			m += c.mult
		var naive_score: int = p * m
		var actual: int = DeceptionResolver.resolve(combo, rules)["score"]
		var note: String = ""
		if _same(combo, naive["pick"]):
			note += "← greedy picks this"
		if _same(combo, truth["pick"]):
			note += "  ← actually best"
		print("%-16s %8d %8d   %s" % [labels, naive_score, actual, note])

	var greedy_actual: int = DeceptionResolver.resolve(naive["pick"], rules)["score"]
	var best_actual: int = truth["score"]
	print("--")
	print("greedy pick scores %d actual  → %s" % [greedy_actual, "MISS" if greedy_actual < target else "clears"])
	print("correct read scores %d actual → %s" % [best_actual, "MISS" if best_actual < target else "clears"])
	var fooled: bool = greedy_actual < best_actual
	var trap_bites: bool = greedy_actual < target
	var solvable: bool = best_actual >= target
	print("[verify] greedy < correct: %s | greedy misses target: %s | correct clears: %s → %s" % [
		fooled, trap_bites, solvable,
		"TRAP WORKS & FAIR" if (fooled and trap_bites and solvable) else "*** BROKEN ***",
	])


func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	var ida: Array = a.map(func(c): return c.id)
	var idb: Array = b.map(func(c): return c.id)
	ida.sort()
	idb.sort()
	return ida == idb
