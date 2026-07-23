class_name Juice
extends RefCounted
## Reusable game-feel helpers. All renderer-agnostic (work on GL Compatibility).
##
## Balatro's whole appeal is feedback, so these are the primitives every reveal
## beat is built from: a scale-punch, a rolling number, and a screen shake.

## Overshoot-and-settle pop. TRANS_BACK out = the satisfying Balatro "stamp".
## Assumes the node's pivot is centred (set pivot_offset = size/2 for Controls).
static func punch(node: CanvasItem, amount: float = 1.35, dur: float = 0.28) -> void:
	if not is_instance_valid(node):
		return
	node.scale = Vector2.ONE
	var t: Tween = node.create_tween()
	t.tween_property(node, "scale", Vector2.ONE * amount, dur * 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector2.ONE, dur * 0.65) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Colour flash that fades back to white — pair with punch for a "hit".
static func flash(node: CanvasItem, color: Color, dur: float = 0.25) -> void:
	if not is_instance_valid(node):
		return
	node.modulate = color
	node.create_tween().tween_property(node, "modulate", Color.WHITE, dur) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Rolling number count-up on a Label. Returns the Tween so callers can await it
## or chain. `fmt` formats the integer value (e.g. "%d", "×%d", "$%d").
static func count(label: Label, from_val: int, to_val: int, dur: float = 0.5,
		fmt: String = "%d") -> Tween:
	var t: Tween = label.create_tween()
	t.tween_method(
		func(v: float) -> void: label.text = fmt % roundi(v),
		float(from_val), float(to_val), dur
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return t


## Decaying positional shake. `node` is usually a wrapper Control/Node2D so the
## whole view jolts. Amplitude scales the punch to the moment (bigger score →
## bigger shake).
static func shake(node: CanvasItem, amount: float = 14.0, dur: float = 0.35) -> void:
	if not is_instance_valid(node):
		return
	var base: Vector2 = node.position if node is Control else (node as Node2D).position
	var t: Tween = node.create_tween()
	t.tween_method(
		func(k: float) -> void:
			var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amount * (1.0 - k)
			if node is Control:
				(node as Control).position = base + off
			else:
				(node as Node2D).position = base + off,
		0.0, 1.0, dur
	).set_trans(Tween.TRANS_LINEAR)
	t.tween_callback(func() -> void:
		if node is Control:
			(node as Control).position = base
		else:
			(node as Node2D).position = base)
