class_name ButtonCatalog
extends RefCounted
## The pool of consumable buttons. The DataGenerator deals hands from here. Each
## call returns fresh instances because a button tracks its own spent state.


## Keycap face per button, chosen for what it does.
const FACES := {
	&"plus_mult": preload("res://assets/art/buttons/button_grey_smiley.tres"),
	&"consecutive": preload("res://assets/art/buttons/button_white_enter.tres"),
	&"gap": preload("res://assets/art/buttons/button_white_smiley.tres"),
	&"remaining_clicks": preload("res://assets/art/buttons/button_red.tres"),
	&"remaining_seconds": preload("res://assets/art/buttons/button_grey_enter.tres"),
	&"high_decimal": preload("res://assets/art/buttons/button_white_vending.tres"),
}


static func pool() -> Array[ButtonDef]:
	var buttons: Array[ButtonDef] = []
	buttons.append(_flat("plus_mult", "+2 Mult", "Adds 2 mult to this stopwatch.", 0, 2))
	buttons.append(_named(ButtonConsecutive.new(), "consecutive", "Straight",
		"x2 mult for three locks on consecutive decimals."))
	buttons.append(_named(ButtonGap.new(), "gap", "Patience",
		"+10 mult for each pair of locks 2s+ apart."))
	buttons.append(_named(ButtonRemainingClicks.new(), "remaining_clicks", "Sprint",
		"+10 mult for each lock left when time runs out."))
	buttons.append(_named(ButtonRemainingSeconds.new(), "remaining_seconds", "Early Bird",
		"Adds the seconds left at each lock to the mult."))
	buttons.append(_named(ButtonHighDecimal.new(), "high_decimal", "High Roller",
		"+5 mult for each lock on decimals 5-9."))
	return buttons


static func _flat(id: String, name: String, desc: String, points: int, mult: int) -> ButtonDef:
	var b := ButtonDef.new()
	b.bonus_points = points
	b.bonus_mult = mult
	return _named(b, id, name, desc)


static func _named(b: ButtonDef, id: String, name: String, desc: String) -> ButtonDef:
	b.id = StringName(id)
	b.display_name = name
	b.description = desc
	b.face = FACES.get(b.id, null)
	return b
