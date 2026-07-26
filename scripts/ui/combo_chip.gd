extends Control
## A combo badge shown above a stopwatch. Positive combos wear the orange badge,
## negative combos the blue one. Hover for the description.
##
## While its stopwatch runs the badge watches the clock: the moment locking would
## score this combo it springs up and settles back, so the player can see what is
## live. It also shakes when the combo actually lands during scoring.

const BADGE_POS := preload("res://assets/art/ui/badge_orange.tres")
const BADGE_NEG := preload("res://assets/art/ui/badge_blue.tres")

@onready var _badge: TextureRect = $Badge
@onready var _label: Label = $Label

var combo: ComboDef
var _live: bool = false
## Only the stopwatch actually running should light its badges up.
var _watching: bool = false


func setup(c: ComboDef) -> void:
	combo = c


## The owning stopwatch tells us when it is the one running.
func set_watching(on: bool) -> void:
	_watching = on
	if not on:
		_live = false


func _ready() -> void:
	_badge.texture = BADGE_NEG if combo.negative else BADGE_POS
	_label.text = combo.display_name
	tooltip_text = combo.description
	EventBus.combo_triggered.connect(_on_triggered)


func _process(_delta: float) -> void:
	if not _watching or not StopwatchManager.running:
		return
	var now: bool = combo.would_hit(StopwatchManager.clicks, StopwatchManager.remaining_ms)
	if now and not _live:
		Shake.pulse(self)   # just became scorable
	_live = now


func _on_triggered(c: ComboDef) -> void:
	if c == combo:
		Shake.play(self)
