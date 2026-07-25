extends Button
## A consumable button from the round's hand. Toggling it on marks it active in
## RoundManager; starting a stopwatch spends the active ones and the round
## rebuilds the hand, so this view just handles the toggle.

var def: ButtonDef


func setup(d: ButtonDef) -> void:
	def = d


func _ready() -> void:
	toggle_mode = true
	text = def.display_name
	tooltip_text = def.description
	toggled.connect(_on_toggled)


func _on_toggled(on: bool) -> void:
	RoundManager.set_button_active(def, on)
