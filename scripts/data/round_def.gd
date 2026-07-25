class_name RoundDef
extends Resource
## One round: a set of stopwatches to clear, a score target, and the reward for
## beating it. A boss round ends the lap.

@export var display_name: String = ""
@export var target: int = 300
@export var reward: int = 3
@export var is_boss: bool = false
@export var stopwatches: Array[StopwatchDef] = []
