class_name ButtonRemainingClicks
extends ButtonDef
## +10 mult for each lock you still had left when the clock ran out. Rewards
## finishing a stopwatch with time to spare.


func on_finish() -> bool:
	var left: int = StopwatchManager.remaining_clicks()
	if left <= 0:
		return false
	StopwatchManager.add_mult(10 * left)
	return true
