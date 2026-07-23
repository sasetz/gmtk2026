extends Control
## The money moment: stages a round's presses into a Points × Mult slam.
##
## Beats fly in left-to-right, each popping its conditions and rolling its points
## and mult into the running counters (rising pitch), then Points × Mult slams
## with a screen-scaled punch, shake and particle burst, and the verdict lands
## against the target. Jokers slot between the beats and the slam in Phase 3.

signal finished(passed: bool)

const BEAT_STAGGER: float = 0.34
const COND_COLOR := Color(0.98, 0.86, 0.4)
const POINTS_COLOR := Color(0.42, 0.72, 0.98)
const MULT_COLOR := Color(0.98, 0.45, 0.4)
const FoilShader := preload("res://shaders/foil.gdshader")

@onready var _shake: Control = $Shake
@onready var _jokers: HBoxContainer = $Shake/Center/Jokers
@onready var _hand: HBoxContainer = $Shake/Center/Hand
@onready var _points_label: Label = $Shake/Center/Board/Points/Value
@onready var _mult_label: Label = $Shake/Center/Board/Mult/Value
@onready var _score_label: Label = $Shake/Center/Score
@onready var _verdict: Label = $Shake/Center/Verdict
@onready var _burst: CPUParticles2D = $Burst

var _points: int = 0
var _mult: float = 0.0
var _joker_cards: Array[Control] = []


## Replays the engine's ordered log so the animation matches the maths exactly.
func play(ctx: ScoringContext, log: Array) -> void:
	_reset(ctx.target)
	# The equipped board sits above the hand and lights up as each joker fires.
	for j in ctx.jokers:
		var jc: Control = _make_joker_card(j)
		_jokers.add_child(jc)
		_joker_cards.append(jc)
	await get_tree().process_frame

	for step: Dictionary in log:
		if step["type"] == "beat":
			var card: Control = _make_beat_card(step["beat"])
			_hand.add_child(card)
			await get_tree().process_frame
			card.pivot_offset = card.size * 0.5
			Juice.punch(card, 1.2, 0.3)
		else:  # joker
			var jc: Control = _joker_cards[step["index"]]
			jc.pivot_offset = jc.size * 0.5
			Juice.punch(jc, 1.3, 0.3)
			Juice.flash(jc, Color(1, 1, 0.6), 0.3)
			_float_effect(jc, step["effect"])
		_roll_points(int(step["points"]))
		_roll_mult(step["mult"])
		await get_tree().create_timer(BEAT_STAGGER).timeout

	# --- anticipation, then the slam ---
	await get_tree().create_timer(0.35).timeout
	var score: int = ctx.final_score()
	Juice.count(_score_label, 0, score, 0.6, "%d")
	Juice.punch(_score_label, 1.7, 0.55)
	Juice.flash(_score_label, Color.WHITE, 0.4)
	Juice.shake(_shake, clampf(float(score) / 120.0, 8.0, 40.0), 0.4)
	_burst.position = _score_label.global_position + _score_label.size * 0.5
	_burst.restart()
	_burst.emitting = true
	await get_tree().create_timer(0.7).timeout

	# --- verdict ---
	var passed: bool = ctx.passed()
	_verdict.text = "PASS  (target %d)" % ctx.target if passed else "FAIL  (needed %d)" % ctx.target
	_verdict.modulate = Color(0.4, 0.95, 0.55) if passed else Color(0.95, 0.4, 0.4)
	Juice.punch(_verdict, 1.3, 0.35)
	finished.emit(passed)


func _roll_points(to_val: int) -> void:
	Juice.count(_points_label, _points, to_val, 0.28)
	_points = to_val
	Juice.punch($Shake/Center/Board/Points, 1.15, 0.2)


func _roll_mult(to_val: float) -> void:
	# Mult is integer in the current card set; a rolling count reads fine. If a
	# fractional xmult ever lands, snap to a one-decimal readout at the end.
	var from_i: int = int(round(_mult))
	var to_i: int = int(round(to_val))
	var t: Tween = Juice.count(_mult_label, from_i, to_i, 0.28)
	if not is_equal_approx(to_val, round(to_val)):
		t.tween_callback(func() -> void: _mult_label.text = "%.1f" % to_val)
	_mult = to_val
	Juice.punch($Shake/Center/Board/Mult, 1.15, 0.2)


func _reset(target: int) -> void:
	_points = 0
	_mult = 0.0
	_joker_cards.clear()
	_points_label.text = "0"
	_mult_label.text = "0"
	_score_label.text = ""
	_verdict.text = ""
	_verdict.modulate = Color.WHITE
	for c: Node in _hand.get_children():
		c.queue_free()
	for c: Node in _jokers.get_children():
		c.queue_free()


## A compact card showing an equipped joker's name.
func _make_joker_card(joker) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(96, 60)
	var is_rare: bool = joker.rarity == JokerDef.Rarity.RARE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.14, 0.28)
	style.set_corner_radius_all(6)
	style.set_border_width_all(2)
	style.border_color = Color(0.98, 0.82, 0.4, 0.9) if is_rare else Color(0.7, 0.6, 0.95, 0.7)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	# Rare cards get the animated holographic foil behind the label.
	if is_rare:
		var foil := ColorRect.new()
		var mat := ShaderMaterial.new()
		mat.shader = FoilShader
		mat.set_shader_parameter("intensity", 0.5)
		mat.set_shader_parameter("base_color", Color(0.18, 0.14, 0.28))
		foil.material = mat
		foil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(foil)
	var l := Label.new()
	l.text = joker.display_name
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.9, 0.88, 0.98))
	panel.add_child(l)
	return panel


## Floating "+N" / "×N" over a joker as it fires.
func _float_effect(anchor: Control, effect: Dictionary) -> void:
	var text: String = ""
	if effect.has("xmult"):
		text = "×%s" % _fmt(effect["xmult"])
	elif effect.get("void", false):
		text = "VOID"
	else:
		var parts: Array[String] = []
		if int(effect.get("points", 0)) != 0:
			parts.append("+%d" % int(effect["points"]))
		if float(effect.get("mult", 0)) != 0:
			parts.append("+%s Mult" % _fmt(effect["mult"]))
		text = " ".join(parts)
	if text == "":
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(0.98, 0.86, 0.4))
	add_child(l)
	l.global_position = anchor.global_position + Vector2(anchor.size.x * 0.5 - 20, -10)
	var t: Tween = l.create_tween()
	t.set_parallel(true)
	t.tween_property(l, "global_position:y", l.global_position.y - 40, 0.7)
	t.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.2)
	t.chain().tween_callback(l.queue_free)


func _fmt(v: float) -> String:
	return "%d" % int(v) if is_equal_approx(v, round(v)) else "%.1f" % v


## A small card for one locked press: the time, plus its matched condition labels.
func _make_beat_card(r: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(120, 150)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.32, 0.24) if not r["bad"] else Color(0.35, 0.1, 0.12)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(0.98, 0.86, 0.4, 0.6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vb)

	var time := Label.new()
	time.text = r["digits"]["display"]
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time.add_theme_font_size_override("font_size", 34)
	time.add_theme_color_override("font_color", COND_COLOR)
	vb.add_child(time)

	if r["bad"]:
		_add_cond_label(vb, "BAD TIME", Color(0.95, 0.5, 0.5))
	elif r["conditions"].is_empty():
		_add_cond_label(vb, "—", Color(0.6, 0.6, 0.6))
	else:
		for c: Dictionary in r["conditions"]:
			_add_cond_label(vb, "%s +%d ×%d" % [c["label"], c["points"], c["mult"]], Color(0.85, 0.88, 0.9))
	return panel


func _add_cond_label(parent: Node, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
