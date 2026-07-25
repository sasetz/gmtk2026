class_name CardMultiPlus
extends Card
## "Multi +4" - a flat mult on every stopwatch. The plainest build baseline.


func attach() -> void:
	EventBus.stopwatch_started.connect(_on_started)


func detach() -> void:
	if EventBus.stopwatch_started.is_connected(_on_started):
		EventBus.stopwatch_started.disconnect(_on_started)


func _on_started() -> void:
	StopwatchManager.add_mult(4)
	activate()
