class_name JokerOvertime
extends JokerDef
## Counter-joker. +1 stop this round, at the cost of a stiffer target — more
## chances to build the mix, but the board demands more of them. Mirrors the
## original Extra Beat's press/target trade for the deception run.

func stop_bonus() -> int:
	return int(num("stop_bonus", 1.0))


func target_multiplier() -> float:
	return num("target_mult", 1.15)
