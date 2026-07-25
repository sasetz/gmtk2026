class_name CardOddAlly
extends Card
## "Odd Ally" - extra mult on every odd lock. Rewards an all-odd build identity.


func attach() -> void:
	EventBus.stopwatch_clicked.connect(_on_click)


func detach() -> void:
	if EventBus.stopwatch_clicked.is_connected(_on_click):
		EventBus.stopwatch_clicked.disconnect(_on_click)


func _on_click() -> void:
	var clicks: Array[int] = StopwatchManager.clicks
	if not clicks.is_empty() and tenths(clicks[-1]) % 2 == 1:
		StopwatchManager.add_mult(2)
		activate()
