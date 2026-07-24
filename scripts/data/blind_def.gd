class_name BlindDef
extends Resource


@export var display_name: String = "Blind"
@export var stopwatches_ms: Array[int] = [13_000]
@export var stopwatch_rates: Array[float] = [0.5]
@export var target: int = 300
@export var reward: int = 3
@export var tier: int = 1
@export var is_boss: bool = false
## Boss modifier id (see BossMods). Empty on normal rounds.
@export var boss_id: StringName = &""

func _init(_stopwatches: Array = [[13_000, 0.5]], _target: int = 300, _reward: int = 3,
		_tier: int = 1, _boss_id: StringName = &"", _display_name: String = "Blind") -> void:
	stopwatches_ms.clear()
	stopwatch_rates.clear()
	for stopwatch in _stopwatches:
		stopwatches_ms.append(int(stopwatch[0]))
		stopwatch_rates.append(float(stopwatch[1]))
	target = _target
	reward = _reward
	tier = _tier
	is_boss = _boss_id != &""
	boss_id = _boss_id
	display_name = _display_name
