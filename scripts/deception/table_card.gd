class_name TableCard
extends Resource
## One card on the deception table. EVERYTHING here is visible to the player —
## there is no hidden value. The fooling comes from how VALUE cards and RULE
## cards interact when resolved left-to-right, not from concealment.
##
## A VALUE card contributes points/mult when picked. A RULE card is always
## active on the board and mutates how the picked cards score. Their effects
## deliberately CONTRADICT (a card offers big mult; a rule cancels all mult), so
## a careless read grabs the shiny thing a visible rule has already neutered.

enum Kind { VALUE, RULE }

@export var id: StringName = &""
@export var label: String = ""
@export var kind: Kind = Kind.VALUE
## VALUE: what it adds when picked.
@export var points: int = 0
@export var mult: int = 0
## RULE: which resolution effect it applies (see DeceptionResolver).
@export var effect: StringName = &""
## Plain-language text shown ON the card — the player always sees this.
@export var text: String = ""


static func value(id_: StringName, label_: String, points_: int, mult_: int, text_: String) -> TableCard:
	var c := TableCard.new()
	c.id = id_
	c.label = label_
	c.kind = Kind.VALUE
	c.points = points_
	c.mult = mult_
	c.text = text_
	return c


static func rule(id_: StringName, label_: String, effect_: StringName, text_: String) -> TableCard:
	var c := TableCard.new()
	c.id = id_
	c.label = label_
	c.kind = Kind.RULE
	c.effect = effect_
	c.text = text_
	return c
