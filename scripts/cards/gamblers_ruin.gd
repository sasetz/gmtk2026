class_name CardGamblersRuin
extends Card
## "Gambler's Ruin" - a fat +10 mult, but each round it has a 1-in-5 chance to
## shatter and remove itself. Risk you keep re-accepting.


func attach() -> void:
	EventBus.stopwatch_started.connect(_on_started)
	EventBus.round_scored.connect(_on_round_scored)


func detach() -> void:
	if EventBus.stopwatch_started.is_connected(_on_started):
		EventBus.stopwatch_started.disconnect(_on_started)
	if EventBus.round_scored.is_connected(_on_round_scored):
		EventBus.round_scored.disconnect(_on_round_scored)


func _on_started() -> void:
	StopwatchManager.add_mult(10)
	activate()


func _on_round_scored(_passed: bool) -> void:
	if RunManager.rng.randf() < 0.2:
		RunManager.remove_card(self)
