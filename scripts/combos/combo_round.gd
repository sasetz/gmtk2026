class_name ComboRound
extends ComboDef
## Fires for every lock landing on a round number (decimal 0).


func hits(clicks: Array[int]) -> int:
	var n: int = 0
	for ms: int in clicks:
		if tenths(ms) == 0:
			n += 1
	return n
