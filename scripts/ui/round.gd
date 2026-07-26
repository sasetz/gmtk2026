extends Control
## The round screen. It builds a stopwatch view per StopwatchDef and a button
## view per dealt button, all pulled from RoundManager, and shows progress toward
## the round target. Buttons stay put once spent (they grey themselves out).

@export var stopwatch_scene: PackedScene
@export var button_scene: PackedScene

@onready var _stopwatches: HBoxContainer = $Stopwatches
@onready var _buttons: HBoxContainer = $Buttons
@onready var _progress: Label = $Progress


## Drawn above the tutorial's dim, so a highlighted element stands out.
const HIGHLIGHT_Z: int = 100


func _ready() -> void:
	EventBus.stopwatch_ended.connect(_update_progress)
	EventBus.tutorial_highlight.connect(_on_highlight)
	_build_stopwatches()
	_build_buttons()
	_update_progress()


## The tutorial points at one kind of element at a time; lift it over the dim.
func _on_highlight(role: StringName) -> void:
	_lift(_stopwatches, role == &"stopwatch")
	_lift(_buttons, role == &"button")


func _lift(box: Container, on: bool) -> void:
	for child: Node in box.get_children():
		(child as CanvasItem).z_index = HIGHLIGHT_Z if on else 0


func _build_stopwatches() -> void:
	for def: StopwatchDef in RoundManager.round_def.stopwatches:
		var view := stopwatch_scene.instantiate()
		view.setup(def)
		_stopwatches.add_child(view)


func _build_buttons() -> void:
	for def: ButtonDef in RoundManager.buttons:
		var view := button_scene.instantiate()
		view.setup(def)
		_buttons.add_child(view)


func _update_progress() -> void:
	_progress.text = "Score %d / %d" % [RoundManager.total_score, RoundManager.round_def.target]
