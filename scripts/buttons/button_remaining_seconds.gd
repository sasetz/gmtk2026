class_name ButtonRemainingSeconds
extends ButtonDef
## Adds the whole seconds left on the clock at each lock to the mult. Locking
## early and often stacks up.


func on_finish() -> bool:
	var mult: int = 0
	for ms: int in StopwatchManager.clicks:
		@warning_ignore("integer_division")
		mult += ms / 1000
	if mult == 0:
		return false
	StopwatchManager.add_mult(mult)
	return true
