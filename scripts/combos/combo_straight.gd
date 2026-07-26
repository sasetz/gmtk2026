class_name ComboStraight
extends ComboDef
## Fires for every run of three locks stepping to the next consecutive decimal
## (e.g. .3 then .4 then .5). Runs overlap, so a longer streak keeps paying -
## otherwise a stopwatch asking for six locks would need all six in a row and the
## combo would be worth nothing.

const RUN: int = 3


## Roughly a third of the possible runs come off.
func expected_hits(clicks: int) -> float:
	return maxf(0.0, float(clicks - RUN + 1)) * 0.35


func max_hits(clicks: int) -> int:
	return maxi(0, clicks - RUN + 1)


func hits(clicks: Array[int]) -> int:
	var n: int = 0
	for start in range(0, clicks.size() - RUN + 1):
		var ok: bool = true
		for i in range(start + 1, start + RUN):
			if tenths(clicks[i]) != (tenths(clicks[i - 1]) + 1) % 10:
				ok = false
				break
		if ok:
			n += 1
	return n
