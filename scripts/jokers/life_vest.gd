class_name JokerLifeVest
extends JokerDef
## Counter-joker. The first N would-be-voided stops this round score their base
## instead of zeroing — insurance that lets you gamble on a trapped property once.

func void_immunities() -> int:
	return int(num("immunities", 1.0))
