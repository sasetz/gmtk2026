class_name ButtonDef
extends Resource
## A button is a consumable the player activates before starting a stopwatch. The
## hand is dealt per round and not refilled, so they have to be rationed. Once
## spent it stays in the hand but greyed out. A button acts on the
## StopwatchManager: on_begin() for flat, always-on bonuses (so they show in the
## live mult), on_finish() for ones that depend on how the locks played out.

@export var id: StringName
@export var display_name: String = ""
@export var description: String = ""
@export var bonus_points: int = 0
@export var bonus_mult: int = 0

var spent: bool = false


## Applied when the stopwatch starts. Returns true if it contributed. Base does
## the flat points/mult bonus.
func on_begin() -> bool:
	if bonus_points == 0 and bonus_mult == 0:
		return false
	StopwatchManager.add_points(bonus_points)
	StopwatchManager.add_mult(bonus_mult)
	return true


## Applied when the stopwatch scores, from the locked-in times. Returns true if
## it contributed. Override for conditional buttons.
func on_finish() -> bool:
	return false


## The tenths-of-a-second digit of a millisecond time.
func tenths(ms: int) -> int:
	return (ms / 100) % 10
