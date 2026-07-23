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
}


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
