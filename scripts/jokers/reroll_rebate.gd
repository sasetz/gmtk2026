class_name JokerRerollRebate
extends JokerDef
## "Reroll Rebate" — every shop reroll costs $1 less. A shop-side effect the
## Economy reads; no scoring contribution.

func reroll_discount() -> int:
	return int(num("discount", 1.0))
