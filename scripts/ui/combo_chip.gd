extends PanelContainer
## A little chip on a stopwatch showing one active combo. Hover for its
## description; shakes when the combo fires during scoring. Negative combos
## (boss rounds) are tinted red.

@onready var _label: Label = $Label

var combo: ComboDef


func setup(c: ComboDef) -> void:
	combo = c


func _ready() -> void:
	_label.text = combo.display_name
	tooltip_text = combo.description
	if combo.negative:
		self_modulate = Color(1.0, 0.55, 0.55)
	EventBus.combo_triggered.connect(_on_triggered)


func _on_triggered(c: ComboDef) -> void:
	if c == combo:
		Shake.play(self)
