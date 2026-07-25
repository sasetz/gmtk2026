class_name ButtonDef
extends Resource
## A button is a consumable the player activates before starting a stopwatch. The
## hand is dealt per round and not refilled, so they have to be rationed. For now
## a button is a flat points/mult bonus applied to the stopwatch it is spent on.

@export var id: StringName
@export var display_name: String = ""
@export var description: String = ""
@export var bonus_points: int = 0
@export var bonus_mult: int = 0
