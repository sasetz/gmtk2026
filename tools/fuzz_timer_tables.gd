extends SceneTree
## Fuzz the generated deception tables to prove fairness at scale:
##  - every board is winnable (solver best >= target),
##  - the greedy "chase the biggest base" player MISSES the target,
##  - no dumb single-property heuristic (spam odd / even / round) trivially clears.
##
## Run: godot --headless --path <project> --script res://tools/fuzz_timer_tables.gd

const N: int = 500


func _init() -> void:
	for difficulty in [1, 3, 5]:
		_run_tier(difficulty)
	_run_tier(5, true)   # boss board: both high-base grabs trapped, higher target
	_run_jokers()
	quit()


func _run_tier(difficulty: int, boss: bool = false) -> void:
	var rng := RandomNumberGenerator.new()
	var winnable: int = 0
	var greedy_misses: int = 0
	var trap_bites: int = 0        # greedy scores strictly less than best
	var heuristic_clears: int = 0  # a spam-one-property line clears target
	var mix_clears: int = 0        # a natural buff mix clears (human reachability)
	var targets: Array[int] = []

	for i in N:
		rng.seed = difficulty * 100000 + i + (900000 if boss else 0)
		var b: Dictionary = TimerTableGenerator.generate(rng, difficulty, boss)
		var target: int = b["target"]
		var best: int = b["best"]["score"]
		var naive: int = b["naive"]["score"]
		targets.append(target)
		if best >= target:
			winnable += 1
		if naive < target:
			greedy_misses += 1
		if naive < best:
			trap_bites += 1
		# Dumb heuristic: spam each single property for all 3 stops; does any clear?
		for prop: StringName in ModifierTable.AIMABLE:
			var fired: Array = []
			var hit_keys: Dictionary = {}
			var total: int = 0
			var t: Array = ModifierTable.CANON[prop]
			for _s in 3:
				var r: Dictionary = ModifierTable.resolve(t[0], t[1], b["cards"], fired, hit_keys)
				total += int(r["score"])
				fired.append_array(r["fired_cards"])
				hit_keys[r["key"]] = int(hit_keys.get(r["key"], 0)) + 1
			if total >= target:
				heuristic_clears += 1
				break

		# Human reachability: a natural mix — hit both buffed properties, then
		# repeat the first. Does it clear the target?
		var bmix: Array = b["buffed"]
		var mseq: Array = [bmix[0], bmix[1], bmix[0]]
		var mf: Array = []
		var mk: Dictionary = {}
		var mtotal: int = 0
		for prop: StringName in mseq:
			var ct: Array = ModifierTable.CANON[prop]
			var r: Dictionary = ModifierTable.resolve(ct[0], ct[1], b["cards"], mf, mk)
			mtotal += int(r["score"])
			mf.append_array(r["fired_cards"])
			mk[r["key"]] = int(mk.get(r["key"], 0)) + 1
		if mtotal >= target:
			mix_clears += 1

	var avg_target: int = 0
	for t in targets:
		avg_target += t
	avg_target /= max(targets.size(), 1)

	print("=== difficulty %d%s  (%d boards) ===" % [difficulty, "  BOSS" if boss else "", N])
	print("  winnable (best>=target):     %d/%d  (%.0f%%)" % [winnable, N, 100.0 * winnable / N])
	print("  greedy misses target:        %d/%d  (%.0f%%)" % [greedy_misses, N, 100.0 * greedy_misses / N])
	print("  trap bites (greedy<best):    %d/%d  (%.0f%%)" % [trap_bites, N, 100.0 * trap_bites / N])
	print("  a spam-1-property line wins: %d/%d  (%.0f%%)  <- want LOW" % [heuristic_clears, N, 100.0 * heuristic_clears / N])
	print("  a natural buff-mix clears:   %d/%d  (%.0f%%)  <- want HIGH (reachable)" % [mix_clears, N, 100.0 * mix_clears / N])
	print("  avg target: %d" % avg_target)
	var ok: bool = winnable == N and greedy_misses == N
	print("  [verify] %s\n" % ("FAIR & FOOLS at scale" if ok else "*** issues above ***"))


## Prove the OWNED DECK integrates soundly at scale: on every board, playing the
## same natural buff-mix with a representative deck (a) never crashes, (b) never
## scores LESS than playing it deck-less (jokers only ever help), and (c) turns a
## meaningful share of boards from a squeaker into a comfortable clear — the whole
## point of a build. Fairness of the BOARD itself is proven deck-less above.
func _run_jokers() -> void:
	var rng := RandomNumberGenerator.new()
	var deck_ids := [&"multi_plus", &"odd_ally", &"analyst", &"trap_cutter", &"echo"]
	var never_worse: int = 0
	var deck_clears: int = 0
	var bare_clears: int = 0
	for i in N:
		rng.seed = 500000 + i
		var difficulty: int = 1 + (i % 5)
		var b: Dictionary = TimerTableGenerator.generate(rng, difficulty)
		var bmix: Array = b["buffed"]
		var seq: Array = [bmix[0], bmix[1], bmix[0]]
		var bare: int = _play(seq, b["cards"], null)
		var deck: Array = deck_ids.map(func(id: StringName): return JokerCatalog.get_joker(id))
		var ctx := DeceptionContext.build(deck, b["cards"])
		var withd: int = _play(seq, b["cards"], ctx)
		if withd >= bare:
			never_worse += 1
		if bare >= b["target"]:
			bare_clears += 1
		if withd >= b["target"]:
			deck_clears += 1
	print("=== deck integration  (%d boards, representative 5-joker deck) ===" % N)
	print("  deck never scores worse than bare: %d/%d  (%.0f%%)  <- want 100%%" % [
		never_worse, N, 100.0 * never_worse / N])
	print("  natural mix clears — bare:  %d/%d  (%.0f%%)" % [bare_clears, N, 100.0 * bare_clears / N])
	print("  natural mix clears — deck:  %d/%d  (%.0f%%)  <- build should lift this" % [
		deck_clears, N, 100.0 * deck_clears / N])
	var jok_ok: bool = never_worse == N and deck_clears >= bare_clears
	print("  [verify] %s\n" % ("DECK INTEGRATES CLEANLY" if jok_ok else "*** deck regressions above ***"))


## Play a property sequence through a board (with optional deck context), summing
## per-stop scores exactly as the run does. Returns the round total.
func _play(seq: Array, cards: Array, ctx: DeceptionContext) -> int:
	var fired: Array = []
	var hit_keys: Dictionary = {}
	var total: int = 0
	for prop: StringName in seq:
		var t: Array = ModifierTable.CANON[prop]
		var r: Dictionary = ModifierTable.resolve(t[0], t[1], cards, fired, hit_keys, ctx)
		total += int(r["score"])
		fired.append_array(r["fired_cards"])
		hit_keys[r["key"]] = int(hit_keys.get(r["key"], 0)) + 1
	return total
