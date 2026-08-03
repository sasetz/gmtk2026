class_name CardRoundUp
extends Card
## "Round Up" - a lock landing on .7, .8 or .9 is rounded up to the next whole
## second, so a near miss still counts as a round number.


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
	if tenths(ms) < 7:
		return
	@warning_ignore("integer_division")
	StopwatchManager.adjust_last_click((ms / 1000 + 1) * 1000)
	activate()
