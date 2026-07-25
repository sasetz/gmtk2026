class_name ButtonGap
extends ButtonDef
## +10 mult for each pair of consecutive locks at least two seconds apart. The
## clock counts down, so the gap is the drop in remaining time between locks.


func on_finish() -> bool:
	var clicks: Array[int] = StopwatchManager.clicks
	var mult: int = 0
	for i in range(1, clicks.size()):
		if clicks[i - 1] - clicks[i] >= 2000:
			mult += 10
	if mult == 0:
		return false
	StopwatchManager.add_mult(mult)
	return true
