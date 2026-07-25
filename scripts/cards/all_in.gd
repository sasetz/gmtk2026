class_name CardAllIn
extends Card
## "All In" - x2 mult on every stopwatch. A flat multiplier bet.


func attach() -> void:
	EventBus.stopwatch_started.connect(_on_started)


func detach() -> void:
	if EventBus.stopwatch_started.is_connected(_on_started):
		EventBus.stopwatch_started.disconnect(_on_started)


func _on_started() -> void:
	StopwatchManager.add_xmult(2.0)
	activate()
