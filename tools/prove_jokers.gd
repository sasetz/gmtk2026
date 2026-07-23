extends SceneTree
## Deterministic proof that each deception joker does EXACTLY what it claims,
## by resolving hand-built stops through ModifierTable.resolve with a
## DeceptionContext. No wall-clock, no scene — pure scoring maths.
##
## Run: godot --headless --path . --script res://tools/prove_jokers.gd

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_score_jokers()
	_trap_cutter()
	_life_vest()
	_echo()
	_analyst()
	_overtime()
	print("\n[verify] prove_jokers: %d passed, %d failed  → %s" % [
		_pass, _fail, "ALL OK" if _fail == 0 else "*** FAILURES ***"])
	quit(1 if _fail > 0 else 0)


func _ok(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass += 1
		print("  OK    %s" % label)
	else:
		_fail += 1
		print("  FAIL  %s  %s" % [label, detail])


## Resolve a single stop with an owned board, from a fresh round context.
func _stop(time_ms: int, cards: Array, jokers: Array) -> Dictionary:
	var ctx := DeceptionContext.build(jokers, cards)
	return ModifierTable.resolve(time_ms, 1, cards, [], {}, ctx)


func _j(id: StringName) -> JokerDef:
	return JokerCatalog.get_joker(id)


func _score_jokers() -> void:
	print("== score jokers (per-stop) ==")
	# Bare odd stop 06:3 → base 10 pts × 2 mult = 20.
	var bare: Dictionary = _stop(6300, [], [])
	_ok("bare odd = 20", bare["score"] == 20, str(bare["score"]))
	# Multi +4 → mult 2+4=6 → 10×6 = 60.
	var mp: Dictionary = _stop(6300, [], [_j(&"multi_plus")])
	_ok("multi_plus +4 mult → 60", mp["score"] == 60, str(mp["score"]))
	# Odd Ally +2 on odd → mult 4 → 40.
	var oa: Dictionary = _stop(6300, [], [_j(&"odd_ally")])
	_ok("odd_ally +2 mult on odd → 40", oa["score"] == 40, str(oa["score"]))
	# Odd Ally on an EVEN stop 06:2 → no bonus → base 10×2 = 20.
	var oae: Dictionary = _stop(6200, [], [_j(&"odd_ally")])
	_ok("odd_ally does nothing on even → 20", oae["score"] == 20, str(oae["score"]))
	# All In on a stop that hit a property → ×2 → 40.
	var ai: Dictionary = _stop(6300, [], [_j(&"all_in")])
	_ok("all_in ×2 on a live stop → 40", ai["score"] == 40, str(ai["score"]))


func _trap_cutter() -> void:
	print("== trap cutter (disables the biggest trap) ==")
	# THE ONE (base 1920) and STRAIGHT (base 770) both trapped. Cutter must kill
	# the THE ONE void (bigger), so stopping on 01:0 scores its base, not 0.
	var cards: Array = [
		TimerModCard.make(&"the_one", 0, 0, 1.0, true, "THE ONE void"),
		TimerModCard.make(&"straight", 0, 0, 1.0, true, "STRAIGHT void"),
	]
	# Without the cutter: 01:0 hits the_one void → 0.
	var trapped: Dictionary = _stop(1000, cards, [])
	_ok("no cutter: THE ONE trapped → 0", trapped["score"] == 0, str(trapped["score"]))
	# With the cutter: THE ONE void disabled → base 160×12 = 1920.
	var cut: Dictionary = _stop(1000, cards, [_j(&"trap_cutter")])
	_ok("cutter frees THE ONE → 1920", cut["score"] == 1920, str(cut["score"]))
	# STRAIGHT (the smaller trap) is still live → stopping on 05:5 still voids.
	var still: Dictionary = _stop(5500, cards, [_j(&"trap_cutter")])
	_ok("cutter leaves the smaller trap → 0", still["score"] == 0, str(still["score"]))


func _life_vest() -> void:
	print("== life vest (rescues the first void) ==")
	var cards: Array = [TimerModCard.make(&"straight", 0, 0, 1.0, true, "STRAIGHT void")]
	# No vest: 05:5 straight void → 0.
	var sunk: Dictionary = _stop(5500, cards, [])
	_ok("no vest: void → 0", sunk["score"] == 0, str(sunk["score"]))
	# Vest: rescued to base straight+odd = 110×7 = 770.
	var ctx := DeceptionContext.build([_j(&"life_vest")], cards)
	var r1: Dictionary = ModifierTable.resolve(5500, 1, cards, [], {}, ctx)
	_ok("vest rescues first void → 770", r1["score"] == 770, str(r1["score"]))
	_ok("vest immunity consumed", ctx.immunities_left == 0, str(ctx.immunities_left))
	# A SECOND void in the same round is no longer covered → 0.
	var r2: Dictionary = ModifierTable.resolve(5500, 1, cards, [], {}, ctx)
	_ok("second void not covered → 0", r2["score"] == 0, str(r2["score"]))


func _echo() -> void:
	print("== echo (first buff fires twice) ==")
	# A buff on ODD: +0 pts, +5 mult.
	var cards: Array = [TimerModCard.make(&"odd", 0, 5, 1.0, false, "ODD +5 mult")]
	# No echo: base 10 × (2+5) = 70.
	var once: Dictionary = _stop(6300, cards, [])
	_ok("no echo: buff once → 70", once["score"] == 70, str(once["score"]))
	# Echo: buff fires again → 10 × (2+5+5) = 120.
	var twice: Dictionary = _stop(6300, cards, [_j(&"echo")])
	_ok("echo: buff twice → 120", twice["score"] == 120, str(twice["score"]))
	# Echo is spent after the first buff: a second buffed stop is normal (70).
	var ctx := DeceptionContext.build([_j(&"echo")], cards)
	var a: Dictionary = ModifierTable.resolve(6300, 1, cards, [], {}, ctx)
	var fired: Array = []
	fired.append_array(a["fired_cards"])
	var b: Dictionary = ModifierTable.resolve(6200, 1, cards, fired, {&"odd": 1}, ctx)
	# 06:2 is even, the ODD buff won't fire anyway; just assert echo didn't linger.
	_ok("echo spent after first buff", ctx.echo_spent and ctx.echo_left == 0,
		"spent=%s left=%d" % [ctx.echo_spent, ctx.echo_left])


func _analyst() -> void:
	print("== analyst (+mult per new property-kind) ==")
	# First odd stop: base 10 × (2+3) = 50.
	var ctx := DeceptionContext.build([_j(&"analyst")], [])
	var first: Dictionary = ModifierTable.resolve(6300, 1, [], [], {}, ctx)
	_ok("analyst first-of-kind → 50", first["score"] == 50, str(first["score"]))
	# Repeat the SAME kind: no analyst bonus (and the repeat decay bites) → base
	# 20 × decay 0.4 = 8.
	var again: Dictionary = ModifierTable.resolve(6300, 1, [], [], {"odd": 1}, ctx)
	_ok("analyst no bonus on a repeat kind → 8", again["score"] == 8, str(again["score"]))


func _overtime() -> void:
	print("== overtime (setup counter) ==")
	var ot: JokerDef = _j(&"overtime")
	_ok("overtime grants +1 stop", ot.stop_bonus() == 1, str(ot.stop_bonus()))
	_ok("overtime bumps target ×1.15", is_equal_approx(ot.target_multiplier(), 1.15),
		str(ot.target_multiplier()))
