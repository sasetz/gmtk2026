class_name CardMimic
extends Card
## "Mimic" - copies the effect of the card above it, so that card's bonus lands
## twice. It re-runs the neighbour's own event handler, which keeps it working
## for any card without Mimic knowing what that card does.
##
## One hop only: a Mimic above another Mimic copies nothing, so a column of them
## can't loop.

const HANDLERS := {
	&"started": "_on_started",
	&"clicked": "_on_click",
	&"scored": "_on_round_scored",
}


func attach() -> void:
	EventBus.stopwatch_started.connect(_copy_started)
	EventBus.stopwatch_clicked.connect(_copy_clicked)
	EventBus.round_scored.connect(_copy_scored)


func detach() -> void:
	if EventBus.stopwatch_started.is_connected(_copy_started):
		EventBus.stopwatch_started.disconnect(_copy_started)
	if EventBus.stopwatch_clicked.is_connected(_copy_clicked):
		EventBus.stopwatch_clicked.disconnect(_copy_clicked)
	if EventBus.round_scored.is_connected(_copy_scored):
		EventBus.round_scored.disconnect(_copy_scored)


## The card sitting directly above this one, or null if there is none (or it is
## another Mimic).
func _above() -> Card:
	var idx: int = run_index - 1
	if idx < 0 or idx >= RunManager.cards.size():
		return null
	var card: Card = RunManager.cards[idx]
	return null if card is CardMimic else card


func _copy_started() -> void:
	_copy(HANDLERS[&"started"])


func _copy_clicked() -> void:
	_copy(HANDLERS[&"clicked"])


func _copy_scored(passed: bool) -> void:
	var card: Card = _above()
	if card != null and card.has_method(HANDLERS[&"scored"]):
		card.call(HANDLERS[&"scored"], passed)
		activate()


func _copy(handler: String) -> void:
	var card: Card = _above()
	if card != null and card.has_method(handler):
		card.call(handler)
		activate()
