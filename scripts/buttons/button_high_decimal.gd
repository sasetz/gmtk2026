class_name ButtonHighDecimal
extends ButtonDef
## +5 mult for every lock on a high decimal (5 through 9).


func on_finish() -> bool:
	var mult: int = 0
	for ms: int in StopwatchManager.clicks:
		if tenths(ms) >= 5:
			mult += 5
	if mult == 0:
		return false
	StopwatchManager.add_mult(mult)
	return true
