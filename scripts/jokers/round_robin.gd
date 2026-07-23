class_name JokerRoundRobin
extends JokerDef
## "Round Robin" — bonus points every time a press lands on a round number.

func on_score_eval(ctx) -> Dictionary:
	if beat_has(ctx, &"round"):
		return {"points": num("points", 30.0)}
	return {}


## Deception run: +points on any stop that landed on a round number.
func on_stop(stop: Dictionary) -> Dictionary:
	if &"round" in stop["conditions"]:
		return {"points": num("points", 30.0)}
	return {}
