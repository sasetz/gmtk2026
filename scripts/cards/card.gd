class_name Card
extends Resource
## Base card. Cards persist for a whole run and react to events. A concrete card
## overrides attach()/detach() to subscribe to the EventBus signals it cares
## about, then calls activate() from its callback to fire the visual pulse (the
## HUD listens on card_activated) and update state through the managers.

@export var id: StringName
@export var display_name: String = ""
@export var description: String = ""
@export var cost: int = 3
@export var texture: Texture2D

## RunManager stamps this so the HUD can pulse the matching card view.
var run_index: int = -1


## Subscribe to events here. Override in a concrete card.
func attach() -> void:
	pass


## Undo whatever attach() connected. Override in a concrete card.
func detach() -> void:
	pass


## Extra consumable-button slots this card grants for a round. Override to raise
## the hand cap above the default.
func extra_button_slots() -> int:
	return 0


func activate() -> void:
	EventBus.card_activated.emit(run_index)


## The tenths-of-a-second digit of a millisecond time (the "decimal").
func tenths(ms: int) -> int:
	@warning_ignore("integer_division")
	return (ms / 100) % 10
