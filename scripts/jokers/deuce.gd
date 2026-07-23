class_name JokerDeuce
extends JokerDef
## "Deuce" — every press whose displayed time contains a 2 gives points and mult.

func on_score_eval(ctx) -> Dictionary:
	if "2" in beat_digits(ctx):
		return {"points": num("points", 24.0), "mult": num("mult", 6.0)}
	return {}
