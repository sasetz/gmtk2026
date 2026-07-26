class_name CardRoundDown
extends Card
## "Round Down" - a lock landing on .1, .2 or .3 is rounded down to the whole
## second, so an early press still counts as a round number.


func attach() -> void:
	EventBus.stopwatch_clicked.connect(_on_click)


func detach() -> void:
	if EventBus.stopwatch_clicked.is_connected(_on_click):
		EventBus.stopwatch_clicked.disconnect(_on_click)


func _on_click() -> void:
	var clicks: Array[int] = StopwatchManager.clicks
	if clicks.is_empty():
		return
	var ms: int = clicks[-1]
	var d: int = tenths(ms)
	if d < 1 or d > 3:
		return
	StopwatchManager.adjust_last_click((ms / 1000) * 1000)
	activate()
