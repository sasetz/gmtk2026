extends Control
## A combo badge shown above a stopwatch. Positive combos wear the orange badge,
## negative combos (boss rounds) the blue one. Hover for the description; shakes
## when the combo fires during scoring.

const BADGE_POS := preload("res://assets/art/ui/badge_orange.tres")
const BADGE_NEG := preload("res://assets/art/ui/badge_blue.tres")

@onready var _badge: TextureRect = $Badge
@onready var _label: Label = $Label

var combo: ComboDef


func setup(c: ComboDef) -> void:
	combo = c


func _ready() -> void:
	_badge.texture = BADGE_NEG if combo.negative else BADGE_POS
	_label.text = combo.display_name
	tooltip_text = combo.description
	EventBus.combo_triggered.connect(_on_triggered)


func _on_triggered(c: ComboDef) -> void:
	if c == combo:
		Shake.play(self)
