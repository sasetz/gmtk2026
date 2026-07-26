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
## The decimal digits this combo keys on, so the generator can tell which combos
## contradict each other. Empty means it is not digit based (Straight), which
## counts as "could need any digit".
@export var digits: Array[int] = []


## How many locks satisfy this combo. Override per combo.
func hits(_clicks: Array[int]) -> int:
	return 0


## Would locking right now, at `candidate` ms, advance this combo? Drives the
## live indicator on the badge so the player can see what is scoring.
func would_hit(clicks: Array[int], candidate: int) -> bool:
	var after: Array[int] = clicks.duplicate()
	after.append(candidate)
	return hits(after) > hits(clicks)


## The tenths-of-a-second digit of a millisecond time (the "decimal").
func tenths(ms: int) -> int:
	return (ms / 100) % 10
