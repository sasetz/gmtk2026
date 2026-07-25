class_name CardDecimalDollars
extends Card
## Reference card (the worked example from the design): earn $1 whenever a lock
## lands on the decimal second right after the previous lock's — 0.3s then 0.4s,
## and so on. Shows how a card reads the StopwatchManager and pushes state back
## out through the managers / EventBus.


func attach() -> void:
	EventBus.stopwatch_clicked.connect(_on_click)


func detach() -> void:
	if EventBus.stopwatch_clicked.is_connected(_on_click):
		EventBus.stopwatch_clicked.disconnect(_on_click)


func _on_click() -> void:
	var clicks: Array[int] = StopwatchManager.clicks
	if clicks.size() < 2:
		return
	var prev: int = _decimal(clicks[-2])
	var curr: int = _decimal(clicks[-1])
	if curr == (prev + 1) % 10:
		activate()
		RunManager.add_money(1)


## The tenths-of-a-second digit of a millisecond time.
func _decimal(ms: int) -> int:
	return (ms / 100) % 10
