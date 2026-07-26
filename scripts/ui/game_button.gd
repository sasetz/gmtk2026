extends VBoxContainer
## A consumable button from the round's hand, shown as a keycap chosen for what it
## does with its name below. Toggling it on marks it active in RoundManager and
## plays an activation pop; starting a stopwatch spends it, greying it out. It
## also pops when it fires (button_fired) so the player sees it land.

@onready var _face: TextureButton = $Face
@onready var _label: Label = $Label

var def: ButtonDef


func setup(d: ButtonDef) -> void:
	def = d


func _ready() -> void:
	_label.text = def.display_name
	tooltip_text = def.description
	_face.tooltip_text = def.description
	if def.face != null:
		_face.texture_normal = def.face
	_face.toggle_mode = true
	_refresh_spent()
	_face.toggled.connect(_on_toggled)
	EventBus.stopwatch_started.connect(_on_stopwatch_started)
	EventBus.button_fired.connect(_on_button_fired)


func _on_toggled(on: bool) -> void:
	RoundManager.set_button_active(def, on)
	if on:
		Shake.play(_face)   # activation animation


func _on_stopwatch_started() -> void:
	if def.spent:
		_face.set_pressed_no_signal(false)
		_refresh_spent()


func _refresh_spent() -> void:
	_face.disabled = def.spent
	modulate.a = 0.5 if def.spent else 1.0


func _on_button_fired(button: ButtonDef) -> void:
	if button == def:
		Shake.play(_face)
