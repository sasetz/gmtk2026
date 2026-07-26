class_name ComboOdd
extends ComboDef
## Fires for every lock landing on an odd decimal (1, 3, 5, 7, 9).


## Five decimals in ten, so most locks can be aimed at one.
func expected_hits(clicks: int) -> float:
	return float(clicks) * 0.55


func hits(clicks: Array[int]) -> int:
	var n: int = 0
	for ms: int in clicks:
		if tenths(ms) % 2 == 1:
			n += 1
	return n
