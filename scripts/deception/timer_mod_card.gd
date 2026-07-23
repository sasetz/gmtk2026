class_name TimerModCard
extends Resource
## A face-up TABLE card in the reconnected model. It is a conditional MODIFIER,
## not a number: it reacts to a *property of the time you stop on* (odd / even /
## round / straight / the_one / all_or_nothing / any) and transforms the score.
##
## The number itself still comes from the countdown you stop (via ScoringRules).
## The deception lives here: cards contradict — one buffs a property another
## punishes, and the highest-base property (a straight) is often the trap.

@export var condition: StringName = &"any"
@export var add_points: int = 0
@export var add_mult: int = 0
@export var xmult: float = 1.0
@export var voids: bool = false
## Plain text shown on the card — always visible.
@export var text: String = ""


static func make(condition_: StringName, add_points_: int, add_mult_: int,
		xmult_: float, voids_: bool, text_: String) -> TimerModCard:
	var c := TimerModCard.new()
	c.condition = condition_
	c.add_points = add_points_
	c.add_mult = add_mult_
	c.xmult = xmult_
	c.voids = voids_
	c.text = text_
	return c


## Does this card fire for a time carrying `conditions` (a set of condition names)?
func fires_for(conditions: Array) -> bool:
	return condition == &"any" or condition in conditions
