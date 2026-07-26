extends Button
## A consumable button from the round's hand: a plain themed button at the
## texture's own 80x24, carrying its name. Toggling it on marks it active in
## RoundManager and plays an activation pop; starting a stopwatch spends it,
## greying it out. It also pops when it fires (button_fired) so the player sees
## it land.

var def: ButtonDef


func setup(d: ButtonDef) -> void:
	def = d


func _ready() -> void:
	text = def.display_name
	tooltip_text = def.description
	toggle_mode = true
	_refresh_spent()
	toggled.connect(_on_toggled)
	EventBus.stopwatch_started.connect(_on_stopwatch_started)
	EventBus.button_fired.connect(_on_button_fired)


func _on_toggled(on: bool) -> void:
	RoundManager.set_button_active(def, on)
	if on:
		Audio.play_sfx(Audio.sound_for_button(def.id))
		Shake.play(self)   # activation animation


func _on_stopwatch_started() -> void:
	if def.spent:
		set_pressed_no_signal(false)
		_refresh_spent()


func _refresh_spent() -> void:
	disabled = def.spent
	modulate.a = 0.5 if def.spent else 1.0


func _on_button_fired(button: ButtonDef) -> void:
	if button == def:
		Shake.play(self)
