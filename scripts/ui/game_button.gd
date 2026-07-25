extends Button
## A consumable button from the round's hand. Toggling it on marks it active in
## RoundManager; starting a stopwatch spends it, after which it stays in the hand
## but disabled. It pops when it fires (button_fired) so the player sees it land.

var def: ButtonDef


func setup(d: ButtonDef) -> void:
	def = d


func _ready() -> void:
	toggle_mode = true
	text = def.display_name
	tooltip_text = def.description
	disabled = def.spent
	toggled.connect(_on_toggled)
	EventBus.stopwatch_started.connect(_on_stopwatch_started)
	EventBus.button_fired.connect(_on_button_fired)


func _on_toggled(on: bool) -> void:
	RoundManager.set_button_active(def, on)


func _on_stopwatch_started() -> void:
	# Spent state is decided as the stopwatch begins; grey out if this was spent.
	if def.spent:
		set_pressed_no_signal(false)
		disabled = true


func _on_button_fired(button: ButtonDef) -> void:
	if button == def:
		Shake.play(self)
