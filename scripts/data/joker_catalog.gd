class_name JokerCatalog
extends RefCounted
## Central joker registry (cloned from pixel-dying's ItemCatalog): refer to cards
## by id instead of resource path, and enumerate the pool for the shop.
##
## Each get() returns a FRESH duplicate — jokers carry per-run state (Compound
## Interest's counter, a shatter flag), so the shared .tres must not be mutated.

const PATHS := {
	&"multi_plus": "res://data/jokers/multi_plus.tres",
	&"round_robin": "res://data/jokers/round_robin.tres",
	&"deuce": "res://data/jokers/deuce.tres",
	&"odd_ally": "res://data/jokers/odd_ally.tres",
	&"slow_reveal": "res://data/jokers/slow_reveal.tres",
	&"copycat": "res://data/jokers/copycat.tres",
	&"gamblers_ruin": "res://data/jokers/gamblers_ruin.tres",
	&"all_in": "res://data/jokers/all_in.tres",
	&"extra_beat": "res://data/jokers/extra_beat.tres",
	&"compound_interest": "res://data/jokers/compound_interest.tres",
	&"reroll_rebate": "res://data/jokers/reroll_rebate.tres",
	&"microscope": "res://data/jokers/microscope.tres",
	# Counter-jokers — the deception-run build layer (interact with the table).
	&"trap_cutter": "res://data/jokers/trap_cutter.tres",
	&"life_vest": "res://data/jokers/life_vest.tres",
	&"overtime": "res://data/jokers/overtime.tres",
	&"echo": "res://data/jokers/echo.tres",
	&"analyst": "res://data/jokers/analyst.tres",
}

## The pool the DECEPTION shop offers: score-jokers that have a per-stop effect
## plus the counter-jokers. Excludes original cards whose hooks only fire in the
## countdown-round model (they'd be dead weight in a deception run).
const DECEPTION_POOL := [
	&"multi_plus", &"odd_ally", &"round_robin", &"all_in", &"compound_interest",
	&"reroll_rebate", &"trap_cutter", &"life_vest", &"overtime", &"echo", &"analyst",
]


## A fresh, mutable instance of the card.
static func get_joker(id: StringName) -> JokerDef:
	if not PATHS.has(id):
		push_warning("JokerCatalog: unknown joker id %s" % id)
		return null
	var base: JokerDef = load(PATHS[id])
	if base == null:
		return null
	return base.duplicate(true)


static func all_ids() -> Array:
	return PATHS.keys()
