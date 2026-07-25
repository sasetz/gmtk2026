class_name ComboDigit
extends ComboDef
## Fires for every lock ending on a specific decimal digit. One of these is
## authored per digit 0-9 (see ComboCatalog).

@export var digit: int = 0


func hits(clicks: Array[int]) -> int:
	var n: int = 0
	for ms: int in clicks:
		if tenths(ms) == digit:
			n += 1
	return n
