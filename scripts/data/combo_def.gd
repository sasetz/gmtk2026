class_name ComboDef
extends Resource
## A combo is a scoring modifier that rides a single stopwatch and reacts to the
## pattern of locked-in times. It is shown as a chip on the stopwatch and shakes
## when it fires. hits() counts how many times the condition landed across the
## locks; the bonus is applied per hit. Negative combos carry negative bonuses
## and are used to punish the player on boss rounds.

@export var id: StringName
@export var display_name: String = ""
@export var description: String = ""
@export var bonus_points: int = 0
@export var bonus_mult: int = 0
@export var negative: bool = false


## How many locks satisfy this combo. Override per combo.
func hits(_clicks: Array[int]) -> int:
	return 0


## The tenths-of-a-second digit of a millisecond time (the "decimal").
func tenths(ms: int) -> int:
	return (ms / 100) % 10
