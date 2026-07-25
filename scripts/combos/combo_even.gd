class_name ComboEven
extends ComboDef
## Fires for every lock landing on an even decimal (0, 2, 4, 6, 8).


func hits(clicks: Array[int]) -> int:
	var n: int = 0
	for ms: int in clicks:
		if tenths(ms) % 2 == 0:
			n += 1
	return n
