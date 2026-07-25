class_name ComboOdd
extends ComboDef
## Fires for every lock landing on an odd decimal (1, 3, 5, 7, 9).


func hits(clicks: Array[int]) -> int:
	var n: int = 0
	for ms: int in clicks:
		if tenths(ms) % 2 == 1:
			n += 1
	return n
