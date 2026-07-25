class_name CardRerollRebate
extends Card
## "Reroll Rebate" - every shop reroll costs $2 less. A shop-side effect the
## RunManager reads; no scoring contribution.


func reroll_discount() -> int:
	return 2
