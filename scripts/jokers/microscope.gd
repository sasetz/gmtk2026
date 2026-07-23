class_name JokerMicroscope
extends JokerDef
## "Microscope" — big point bonus on the rare jackpot hits (THE ONE / All or
## Nothing). Dormant early, pays off once precision tiers unlock those hits.

func on_score_eval(ctx) -> Dictionary:
	if beat_has(ctx, &"the_one") or beat_has(ctx, &"all_or_nothing"):
		return {"points": num("points", 50.0)}
	return {}
