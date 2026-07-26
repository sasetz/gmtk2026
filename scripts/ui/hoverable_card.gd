class_name HoverableCard
extends PanelContainer
## Shared hover behaviour for card views (HUD cards and shop offers): on hover the
## card pops up a little, tilts toward the mouse cursor, rises above its
## neighbours, and — if it has a "Shine" overlay with the card_shine shader — its
## gloss slides with the tilt. Balatro-style. Subclasses override _hover_changed
## to react (e.g. reveal a sell button).

const POP: float = 1.12
const TILT: float = 0.14

@onready var _shine: ColorRect = get_node_or_null("Shine")

var _hovering: bool = false


func _ready() -> void:
	mouse_entered.connect(_hover_on)
	mouse_exited.connect(_hover_off)
	if _shine != null:
		_shine.visible = false


func _process(_delta: float) -> void:
	if not _hovering:
		return
	pivot_offset = size * 0.5
	var off: Vector2 = (get_local_mouse_position() - size * 0.5) / size   # ~ -0.5..0.5
	rotation = clampf(off.x, -0.6, 0.6) * TILT
	if _shine != null and _shine.material is ShaderMaterial:
		(_shine.material as ShaderMaterial).set_shader_parameter("tilt", off)


func _hover_on() -> void:
	_hovering = true
	z_index = 10
	pivot_offset = size * 0.5
	var t: Tween = create_tween()
	t.tween_property(self, "scale", Vector2.ONE * POP, 0.1)
	if _shine != null:
		_shine.visible = true
	_hover_changed(true)


func _hover_off() -> void:
	_hovering = false
	z_index = 0
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(self, "scale", Vector2.ONE, 0.12)
	t.tween_property(self, "rotation", 0.0, 0.12)
	if _shine != null:
		_shine.visible = false
	_hover_changed(false)


## Override to react to hover changes (default does nothing).
func _hover_changed(_on: bool) -> void:
	pass
