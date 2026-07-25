class_name CardCompoundInterest
extends Card
## "Compound Interest" - pays $1 when a round is cleared, growing by $1 for every
## round it survives. A slow economic engine.

var _rounds_survived: int = 0


func attach() -> void:
	EventBus.round_scored.connect(_on_round_scored)


func detach() -> void:
	if EventBus.round_scored.is_connected(_on_round_scored):
		EventBus.round_scored.disconnect(_on_round_scored)


func _on_round_scored(passed: bool) -> void:
	if not passed:
		return
	_rounds_survived += 1
	RunManager.add_money(_rounds_survived)
	activate()
