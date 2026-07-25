class_name ComboDef
extends Resource
## A combo is a scoring modifier that rides a single stopwatch (round, straight,
## etc.). The player sees which combos are active on a stopwatch. For now a combo
## is a flat bonus; detecting its condition from the recorded clicks is a later
## step (see StopwatchManager).

@export var id: StringName
@export var display_name: String = ""
@export var bonus_points: int = 0
@export var bonus_mult: int = 0
