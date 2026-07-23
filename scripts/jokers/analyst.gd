class_name JokerAnalyst
extends JokerDef
## Counter-joker. +mult on every stop that lands on a property-kind you have not
## hit yet this round — it literally pays you to build the MIX the deceptive
## table is designed to demand, instead of spamming one line.

func on_stop(stop: Dictionary) -> Dictionary:
	if stop["first_of_kind"] and not (stop["conditions"] as Array).is_empty():
		return {"mult": num("mult", 3.0)}
	return {}
