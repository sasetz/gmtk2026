class_name JokerSlowReveal
extends JokerDef
## "Slow Reveal" — when a press lands on a round number the live timer slows to a
## crawl for a moment, making the next press easier to place. A round-side effect
## (no scoring contribution); the round controller reads these knobs.

func slow_factor() -> float:
	return num("slow_factor", 0.3)


func slow_seconds() -> float:
	return num("slow_seconds", 1.0)
