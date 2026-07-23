class_name JokerExtraBeat
extends JokerDef
## "Extra Beat" — one more press each round, at the cost of a stiffer target.
## A round-setup effect; the round controller applies both before the round.

func press_bonus() -> int:
	return int(num("press_bonus", 1.0))


func target_multiplier() -> float:
	return num("target_mult", 1.15)
