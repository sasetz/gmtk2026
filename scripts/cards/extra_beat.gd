class_name CardExtraBeat
extends Card
## "Extra Beat" - one more lock on every stopwatch, at the cost of a stiffer
## round target. Applied as the round and each stopwatch begin.


func attach() -> void:
	EventBus.round_started.connect(_on_round_started)
	EventBus.stopwatch_started.connect(_on_started)


func detach() -> void:
	if EventBus.round_started.is_connected(_on_round_started):
		EventBus.round_started.disconnect(_on_round_started)
	if EventBus.stopwatch_started.is_connected(_on_started):
		EventBus.stopwatch_started.disconnect(_on_started)


func _on_round_started() -> void:
	RoundManager.round_def.target = int(RoundManager.round_def.target * 1.15)


func _on_started() -> void:
	StopwatchManager.add_click_capacity(1)
	activate()
