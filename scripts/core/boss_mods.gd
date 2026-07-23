class_name BossMods
extends RefCounted
## Boss modifiers. Unlike the 40-strong joker pool, bosses are a handful of
## unique rule-changes, so explicit handling here is the right call (the
## "no match statement" rule was about the extensible card pool, not this).
##
## Phase 4 wires The Miser (a pure scoring transform — the cleanest test of the
## engine). The other three touch the live round (hidden digits, trap ticks) and
## land in Phase 5; their names/blurbs live here so the UI can already show them.

const INFO := {
	&"miser":  {"name": "The Miser",  "blurb": "Joker Mult & xMult are disabled."},
	&"rusher": {"name": "The Rusher", "blurb": "Digits hidden until the final second."},
	&"mirror": {"name": "The Mirror", "blurb": "Round & Straight scoring disabled."},
	&"flinch": {"name": "The Flinch", "blurb": "A trap tick can zero a press."},
}


static func name_of(boss_id: StringName) -> String:
	return INFO.get(boss_id, {}).get("name", "Boss")


static func blurb_of(boss_id: StringName) -> String:
	return INFO.get(boss_id, {}).get("blurb", "")


## Transform a joker's returned effect under the active boss. The Miser strips
## all mult so only points-based builds get through.
static func transform_joker_effect(boss_id: StringName, effect: Dictionary) -> Dictionary:
	if boss_id == &"miser":
		var e: Dictionary = effect.duplicate()
		e.erase("mult")
		e.erase("xmult")
		return e
	return effect


## Transform a press's base result under the active boss (before it seeds the
## running total). The Mirror voids round/straight conditions.
static func transform_press(boss_id: StringName, press: Dictionary) -> Dictionary:
	if boss_id != &"mirror":
		return press
	var kept: Array = []
	var pts: int = 0
	var mult: int = 0
	for c: Dictionary in press["conditions"]:
		if c["name"] == &"round" or c["name"] == &"straight":
			continue
		kept.append(c)
		pts += c["points"]
		mult += c["mult"]
	var p: Dictionary = press.duplicate(true)
	p["conditions"] = kept
	p["points"] = pts
	p["mult"] = mult
	return p
