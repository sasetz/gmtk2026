class_name BlindDef
extends Resource
## One blind (round). The run is a sequence of these: a few normal rounds then a
## boss. Built in code by RunManager for the vertical slice; trivially moved to
## .tres later.

@export var display_name: String = "Blind"
@export var duration_ms: int = 13000
@export var target: int = 300
@export var reward: int = 3
@export var tier: int = 1
@export var is_boss: bool = false
## Boss modifier id (see BossMods). Empty on normal rounds.
@export var boss_id: StringName = &""
