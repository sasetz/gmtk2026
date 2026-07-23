class_name JokerAllIn
extends JokerDef
## "All In" — ×2 mult, but if not a single scoring condition was hit anywhere
## this round the whole score is voided. A bet on your own aim.

func on_final_scoring(ctx) -> Dictionary:
	if ctx.conditions_hit() == 0:
		return {"void": true}
	return {"xmult": num("xmult", 2.0)}
