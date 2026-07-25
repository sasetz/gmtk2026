class_name CardRoundRobin
extends Card
## "Round Robin" - bonus points every time a lock lands on a round number.


func attach() -> void:
	EventBus.stopwatch_clicked.connect(_on_click)


func detach() -> void:
	if EventBus.stopwatch_clicked.is_connected(_on_click):
		EventBus.stopwatch_clicked.disconnect(_on_click)


func _on_click() -> void:
	var clicks: Array[int] = StopwatchManager.clicks
	if not clicks.is_empty() and tenths(clicks[-1]) == 0:
		StopwatchManager.add_points(30)
		activate()
