class_name JokerTrapCutter
extends JokerDef
## Counter-joker. Disables one TRAP (void card) each round — the highest-base one,
## the very card a greedy player is most tempted to grab. Turns the obvious grab
## from a bomb into a jackpot, so it swings the whole read of the table.

func disables_trap() -> bool:
	return true
