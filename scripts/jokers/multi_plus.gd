class_name JokerMultiPlus
extends JokerDef
## "Multi +4" — a flat mult every round. The plainest build baseline.

func on_final_scoring(_ctx) -> Dictionary:
	return {"mult": num("mult", 4.0)}
