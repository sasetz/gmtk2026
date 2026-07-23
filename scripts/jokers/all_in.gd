class_name JokerAllIn
extends JokerDef
## "All In" — ×2 mult, but if not a single scoring condition was hit anywhere
## this round the whole score is voided. A bet on your own aim.

func on_final_scoring(ctx) -> Dictionary:
	if ctx.conditions_hit() == 0:
		return {"void": true}
	return {"xmult": num("xmult", 2.0)}


## Deception run: ×mult only on a stop that actually hit a scoring property —
## a bet that you aimed at something. A blank stop already scores 0.
func on_stop(stop: Dictionary) -> Dictionary:
	if (stop["conditions"] as Array).is_empty():
		return {}
	return {"xmult": num("xmult", 2.0)}
