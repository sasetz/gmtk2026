class_name Shake
extends Object
## A tiny reusable pop-and-wiggle used across cards, combos and buttons to signal
## that something just fired. Uses scale + rotation (via the pivot) so it is safe
## inside containers, which drive position and size themselves. Honours the
## reduced-motion setting.


## Grow a little, then spring back. Used to flag that something is live right
## now (a combo the current time would score) rather than that it just fired.
static func pulse(node: Control, strength: float = 1.0) -> void:
	if not Settings.screen_shake:
		return
	node.pivot_offset = node.size * 0.5
	var t: Tween = node.create_tween()
	t.tween_property(node, "scale", Vector2.ONE * (1.0 + 0.25 * strength), 0.09) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


static func play(node: Control, strength: float = 1.0) -> void:
	if not Settings.screen_shake:
		return
	node.pivot_offset = node.size * 0.5
	var pop: Tween = node.create_tween()
	pop.tween_property(node, "scale", Vector2.ONE * (1.0 + 0.12 * strength), 0.06)
	pop.tween_property(node, "scale", Vector2.ONE, 0.12)
	var wiggle: Tween = node.create_tween()
	wiggle.tween_property(node, "rotation", 0.09 * strength, 0.05)
	wiggle.tween_property(node, "rotation", -0.07 * strength, 0.05)
	wiggle.tween_property(node, "rotation", 0.0, 0.05)
