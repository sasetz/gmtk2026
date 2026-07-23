class_name JokerGamblersRuin
extends JokerDef
## "Gambler's Ruin" — a fat +10 mult, but each round's end it has a 1-in-5 chance
## to shatter. Risk you keep re-accepting. (The destroy roll is resolved by the
## run manager reading `should_destroy`; scoring just grants the mult.)

func on_final_scoring(_ctx) -> Dictionary:
	return {"mult": num("mult", 10.0)}


func should_destroy(rng: RandomNumberGenerator) -> bool:
	return rng.randf() < num("destroy_chance", 0.2)
