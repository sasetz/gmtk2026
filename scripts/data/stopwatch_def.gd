class_name StopwatchDef
extends Resource
## One stopwatch: how fast it counts, how many times the player locks it in, how
## long its window is, and which combos are active on it.

@export var rate: float = 1.0            ## clock speed multiplier
@export var clicks: int = 3              ## locks the player makes before it scores
@export var duration_ms: int = 5000      ## the clock counts up to this, then wraps
@export var combos: Array[ComboDef] = []
