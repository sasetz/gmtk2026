extends Node
## Global UI polish, applied automatically as nodes enter the tree — no per-scene
## wiring:
##   • every full-screen "Felt" ColorRect gets the striped-green background,
##   • every button gets hover/press SCALE animations plus a hover tick,
##     on top of the click Audio already plays.
##
## Runs with PROCESS_MODE_ALWAYS so pause-menu buttons animate while paused.

const StripesMat := preload("res://assets/felt_stripes.tres")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_added)
	_scan(get_tree().root)


func _scan(n: Node) -> void:
	_on_added(n)
	for c in n.get_children():
		_scan(c)


func _on_added(n: Node) -> void:
	if n is ColorRect and n.name == "Felt":
		(n as ColorRect).material = StripesMat
	elif n is BaseButton:
		_wire_button(n as BaseButton)


# --- button juice ----------------------------------------------------------

func _wire_button(b: BaseButton) -> void:
	if b.has_meta("uifx"):
		return
	b.set_meta("uifx", true)
	# Each button state gets its own cue, so a click feels like a real button:
	#   hover in  → light swish up      hover out → softer swish down
	#   press down → deep thunk          release/activate → the click (Audio hook)
	b.mouse_entered.connect(_hover.bind(b, true, true))
	b.mouse_exited.connect(_hover.bind(b, false, true))
	# Keyboard focus scales too (menus are keyboard-navigable) but stays silent,
	# so grabbing focus on load doesn't tick.
	b.focus_entered.connect(_hover.bind(b, true, false))
	b.focus_exited.connect(_hover.bind(b, false, false))
	b.button_down.connect(_press.bind(b))
	b.button_up.connect(_release.bind(b))


func _hover(b: BaseButton, on: bool, sound: bool) -> void:
	if not is_instance_valid(b):
		return
	b.set_meta("hover", on)
	if sound:
		if on:
			Audio.play_sfx(&"card", 1.35, -13.0)    # hover IN — light swish up
		else:
			Audio.play_sfx(&"card", 0.95, -20.0)    # hover OUT — softer swish down
	_to_scale(b, 1.06 if on else 1.0)


func _press(b: BaseButton) -> void:
	Audio.play_sfx(&"ui_click", 0.8, -5.0)          # press DOWN — deep thunk
	_to_scale(b, 0.93)


func _release(b: BaseButton) -> void:
	_to_scale(b, 1.06 if b.get_meta("hover", false) else 1.0)


func _to_scale(b: BaseButton, s: float) -> void:
	if not is_instance_valid(b):
		return
	b.pivot_offset = b.size * 0.5   # scale about the centre
	var prev: Variant = b.get_meta("tw", null)
	if prev != null and (prev as Tween).is_valid():
		(prev as Tween).kill()
	var t: Tween = b.create_tween()
	t.tween_property(b, "scale", Vector2.ONE * s, 0.11) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	b.set_meta("tw", t)
