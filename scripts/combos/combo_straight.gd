class_name ComboStraight
extends ComboDef
## Fires once when every lock steps to the next consecutive decimal, in order
## (e.g. .3 then .4 then .5). Needs at least three locks.


func hits(clicks: Array[int]) -> int:
	if clicks.size() < 3:
		return 0
	for i in range(1, clicks.size()):
		if tenths(clicks[i]) != (tenths(clicks[i - 1]) + 1) % 10:
			return 0
	return 1
