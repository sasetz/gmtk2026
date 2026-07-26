class_name CardMicroscope
extends Card
## "Microscope" - a big point bonus for a perfect lock, dead on a whole second.
## Dormant until your timing is sharp, then it pays off.


func attach() -> void:
	EventBus.stopwatch_clicked.connect(_on_click)


func detach() -> void:
	if EventBus.stopwatch_clicked.is_connected(_on_click):
		EventBus.stopwatch_clicked.disconnect(_on_click)


func _on_click() -> void:
	var clicks: Array[int] = StopwatchManager.clicks
	if not clicks.is_empty() and clicks[-1] % 1000 == 0:
		StopwatchManager.add_points(8)
		activate()
