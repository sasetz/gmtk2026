class_name CardSlowReveal
extends Card
## "Slow Reveal" - when a lock lands on a round number the clock crawls for a
## moment, making the next lock easier to place.


func attach() -> void:
	EventBus.stopwatch_clicked.connect(_on_click)


func detach() -> void:
	if EventBus.stopwatch_clicked.is_connected(_on_click):
		EventBus.stopwatch_clicked.disconnect(_on_click)


func _on_click() -> void:
	var clicks: Array[int] = StopwatchManager.clicks
	if not clicks.is_empty() and tenths(clicks[-1]) == 0:
		StopwatchManager.slow(0.3, 1.0)
		activate()
