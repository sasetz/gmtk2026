extends Control
## The round screen. It builds a stopwatch view per StopwatchDef and a button
## view per dealt button, all pulled from RoundManager. The button hand is rebuilt
## whenever a stopwatch starts, since starting one spends the active buttons.

@export var stopwatch_scene: PackedScene
@export var button_scene: PackedScene

@onready var _stopwatches: HBoxContainer = $Stopwatches
@onready var _buttons: HBoxContainer = $Buttons


func _ready() -> void:
	EventBus.stopwatch_started.connect(_rebuild_buttons)
	_build_stopwatches()
	_rebuild_buttons()


func _build_stopwatches() -> void:
	for def: StopwatchDef in RoundManager.round_def.stopwatches:
		var view := stopwatch_scene.instantiate()
		view.setup(def)
		_stopwatches.add_child(view)


func _rebuild_buttons() -> void:
	for c: Node in _buttons.get_children():
		c.queue_free()
	for def: ButtonDef in RoundManager.buttons:
		var view := button_scene.instantiate()
		view.setup(def)
		_buttons.add_child(view)
