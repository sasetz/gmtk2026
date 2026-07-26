class_name CardDeuce
extends Card
## "Deuce" - every lock on a decimal of 2 gives points and mult.


func attach() -> void:
	EventBus.stopwatch_clicked.connect(_on_click)


func detach() -> void:
	if EventBus.stopwatch_clicked.is_connected(_on_click):
		EventBus.stopwatch_clicked.disconnect(_on_click)


func _on_click() -> void:
	var clicks: Array[int] = StopwatchManager.clicks
	if not clicks.is_empty() and tenths(clicks[-1]) == 2:
		StopwatchManager.add_points(4)
		StopwatchManager.add_mult(2)
		activate()
