class_name ButtonConsecutive
extends ButtonDef
## x2 mult when you lock three or more times on consecutive decimals (a straight,
## but for your own clicks).


func on_finish() -> bool:
	var clicks: Array[int] = StopwatchManager.clicks
	if clicks.size() < 3:
		return false
	for i in range(1, clicks.size()):
		if tenths(clicks[i]) != (tenths(clicks[i - 1]) + 1) % 10:
			return false
	StopwatchManager.add_xmult(2.0)
	return true
