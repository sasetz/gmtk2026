class_name JokerCompoundInterest
extends JokerDef
## "Compound Interest" — pays $1 at the end of a round, and the payout grows by
## $1 every round it survives. A slow economic engine.

var _rounds_survived: int = 0


func on_round_end(_ctx) -> Dictionary:
	_rounds_survived += 1
	var base: int = int(num("base", 1.0))
	var step: int = int(num("step", 1.0))
	return {"dollars": base + step * (_rounds_survived - 1)}
