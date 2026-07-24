class_name RoundScene
extends Control

## Controls the whole round: how many stopwatches we get, which one is selected,
## etc.

@export var StopwatchScene := preload("res://scenes/stopwatch_scene.tscn")

@onready var joker_list: HBoxContainer = $Jokers
@onready var stopwatch_list: HBoxContainer = $Stopwatches

# stopwatch nodes for cleanup
var stopwatches: Array = []
var score: int = 0
var target: int = 30
var blind: BlindDef

signal finished(passed: bool)

func configure(_blind: BlindDef) -> void:
	target = _blind.target
	blind = _blind
	if stopwatch_list != null:
		_populate_stopwatches()


func reset() -> void:
	score = 0
	_clear_stopwatches()


func _ready() -> void:
	_populate_stopwatches()
	for joker in RunManager.jokers:
		var joker_ctrl = ScoringEngine.make_joker_card(joker)
		joker_list.add_child(joker_ctrl)


func _on_stopwatch_finished(_score: int) -> void:
	score += _score
	for stopwatch in stopwatches:
		stopwatch.enable()
	# so we don't have to click through all stopwatches to continue
	# TODO: add more money for the stopwatches that have been left
	if score >= target:
		finished.emit(true)

	for stopwatch in stopwatches:
		if not stopwatch.is_finished():
			return
	finished.emit(score >= target) # the **round** is finished


func _on_stopwatch_started() -> void:
	for stopwatch in stopwatches:
		stopwatch.disable()


func _populate_stopwatches() -> void:
	_clear_stopwatches()
	for stopwatch_index in range(blind.stopwatches_ms.size()):
		var stopwatch = StopwatchScene.instantiate()
		stopwatch.config = RunManager.stopwatch_config(stopwatch_index)
		stopwatch.finished.connect(_on_stopwatch_finished)
		stopwatch.started.connect(_on_stopwatch_started)
		stopwatch_list.add_child(stopwatch)
		stopwatches.append(stopwatch)


func _clear_stopwatches() -> void:
	for stopwatch in stopwatches:
		if is_instance_valid(stopwatch):
			stopwatch.queue_free()
	stopwatches.clear()
