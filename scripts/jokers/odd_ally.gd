class_name JokerOddAlly
extends JokerDef
## "Odd Ally" — extra mult on every odd hit. Rewards an all-odd build identity.

func on_score_eval(ctx) -> Dictionary:
	if beat_has(ctx, &"odd"):
		return {"mult": num("mult", 2.0)}
	return {}


## Deception run: +mult on any stop that landed on an odd time.
func on_stop(stop: Dictionary) -> Dictionary:
	if &"odd" in stop["conditions"]:
		return {"mult": num("mult", 2.0)}
	return {}
