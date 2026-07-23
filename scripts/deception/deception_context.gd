class_name DeceptionContext
extends RefCounted
## Round-level state that the player's owned jokers inject into the deceptive
## table resolution. Built once per round from RunManager.jokers, then passed to
## ModifierTable.resolve on every stop (which mutates the "left" counters as it
## consumes them). When null, resolve runs the pure fuzz-proven baseline — so the
## generator's fairness solver and the original game are untouched.

## The player's owned jokers, board order (JokerDef instances).
var jokers: Array = []

## TRAP cards (TimerModCard) disabled for this round by Trap Cutter — resolve
## skips them entirely, so their void never fires.
var disabled_cards: Array = []

## Would-be-void stops still rescuable to their base score this round (Life Vest).
## Decremented each time an immunity is spent.
var immunities_left: int = 0

## Times the FIRST buff card triggered this round should fire again (Echo).
## Decremented on the round's first buff hit.
var echo_left: int = 0
## Set true once the echo has been spent, so it only applies to the round's very
## first buff trigger.
var echo_spent: bool = false


## Build a context from an owned joker board. Trap disabling is resolved against
## the round's cards (highest-base trap first) so the counter always bites the
## most tempting void.
static func build(jokers_: Array, cards: Array) -> DeceptionContext:
	var ctx := DeceptionContext.new()
	ctx.jokers = jokers_
	var trap_cutters: int = 0
	for j in jokers_:
		trap_cutters += 1 if j.disables_trap() else 0
		ctx.immunities_left += j.void_immunities()
		ctx.echo_left += j.echo_count()
	if trap_cutters > 0:
		ctx.disabled_cards = _pick_traps(cards, trap_cutters)
	return ctx


## The highest-base trap cards (by the base score of the property they punish),
## up to `count` — those are the ones a greedy player is most tempted by, so
## disabling them is what makes the read swing.
static func _pick_traps(cards: Array, count: int) -> Array:
	var traps: Array = []
	for c: TimerModCard in cards:
		if c.voids:
			traps.append(c)
	traps.sort_custom(func(a: TimerModCard, b: TimerModCard) -> bool:
		return _trap_base(a) > _trap_base(b))
	return traps.slice(0, mini(count, traps.size()))


static func _trap_base(card: TimerModCard) -> int:
	var t = ModifierTable.CANON.get(card.condition, null)
	if t == null:
		return 0
	var b: Dictionary = ScoringRules.evaluate(t[0], t[1])
	return int(b["points"]) * int(b["mult"])
