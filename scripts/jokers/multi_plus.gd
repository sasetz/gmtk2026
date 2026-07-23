class_name JokerMultiPlus
extends JokerDef
## "Multi +4" — a flat mult every round. The plainest build baseline.

func on_final_scoring(_ctx) -> Dictionary:
	return {"mult": num("mult", 4.0)}


## Deception run: +mult on every stop.
func on_stop(_stop: Dictionary) -> Dictionary:
	return {"mult": num("mult", 4.0)}
