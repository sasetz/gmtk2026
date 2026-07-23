extends Control
## Reconnected prototype: STOP the countdown to lock a time (the number), and the
## face-up table cards are the deceptive modifiers that transform it.
##
## Flow: PEEK (read the table, untimed) → READY (press to start the clock) →
## RUNNING (the countdown ticks; press again to STOP on a time-property) →
## RESULT (modifiers resolve; breakdown shows what fooled you).

const PEEK_SECONDS: float = 2.5
const DURATION_MS: int = 6000
const TIER: int = 1
const TARGET: int = 350

@onready var _timer: TimerCore = $Timer
@onready var _phase: Label = $Root/Top/Phase
@onready var _target_label: Label = $Root/Top/Target
@onready var _table: HBoxContainer = $Root/Table
@onready var _count: Label = $Root/Count
@onready var _prompt: Label = $Root/Prompt
@onready var _breakdown_panel: Panel = $Breakdown
@onready var _breakdown: VBoxContainer = $Breakdown/List

var _cards: Array = []
var _state: String = "peek"


func _ready() -> void:
	Input.use_accumulated_input = false
	_build_table()
	_render_table()
	_breakdown_panel.visible = false
	_timer.configure(DURATION_MS, 1, TIER)
	_timer.pressed.connect(func(ms: int, _i: int) -> void: _resolve(ms))
	_timer.expired.connect(func() -> void: _resolve(0))
	_target_label.text = "Target  %d" % TARGET
	_enter_peek()


## Hand-authored deceptive table (generator comes later): the obvious high-base
## STRAIGHT is a void-trap; the humble ODD property is the secret jackpot.
func _build_table() -> void:
	_cards = [
		TimerModCard.make(&"odd", 40, 6, 1.0, false, "ODD\n+40 pts, +6 mult"),
		TimerModCard.make(&"straight", 0, 0, 1.0, true, "STRAIGHT\nscore → 0"),
		TimerModCard.make(&"even", 0, 2, 1.0, false, "EVEN\n+2 mult"),
		TimerModCard.make(&"round", 100, 0, 1.0, false, "ROUND\n+100 pts"),
	]


func _enter_peek() -> void:
	_state = "peek"
	_phase.text = "PEEK — read the table"
	_count.text = ScoringRules.digits(DURATION_MS, TIER)["display"]
	_prompt.text = ""
	get_tree().create_timer(PEEK_SECONDS).timeout.connect(_enter_ready)


func _enter_ready() -> void:
	_state = "ready"
	_phase.text = "READY"
	_prompt.text = "Press SPACE to start the clock — then STOP on the right time"


func _process(_delta: float) -> void:
	if _state == "running":
		_count.text = ScoringRules.digits(_timer.remaining_ms(), TIER)["display"]


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"press"):
		return
	get_viewport().set_input_as_handled()
	if _state == "ready":
		_state = "running"
		_phase.text = "STOP!"
		_prompt.text = "Press SPACE to lock your time"
		_timer.start()
	elif _state == "running":
		_timer.press()   # → _resolve via signal


func _resolve(ms: int) -> void:
	if _state == "done":
		return
	_state = "done"
	_phase.text = "RESULT"
	_prompt.text = ""
	_count.text = ScoringRules.digits(ms, TIER)["display"]

	var r: Dictionary = ModifierTable.resolve(ms, TIER, _cards)
	var passed: bool = r["score"] >= TARGET
	for c in _breakdown.get_children():
		c.queue_free()
	for step: String in r["steps"]:
		_add_line(step, Color(0.85, 0.88, 0.92))
	_add_line("= %d" % r["score"], Color(0.98, 0.86, 0.4))
	_add_line("PASS" if passed else "FAIL  (needed %d)" % TARGET,
		Color(0.4, 0.95, 0.55) if passed else Color(0.95, 0.4, 0.4))
	_breakdown_panel.visible = true
	Juice.punch(_breakdown_panel, 1.08, 0.35)


## Test hook: resolve a specific time without wall-clock timing.
func _debug_resolve(ms: int) -> void:
	_state = "running"
	_resolve(ms)


func _add_line(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", color)
	_breakdown.add_child(l)


func _render_table() -> void:
	for card: TimerModCard in _cards:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(150, 110)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.13, 0.26) if not card.voids else Color(0.32, 0.12, 0.14)
		style.set_corner_radius_all(8)
		style.set_border_width_all(2)
		style.border_color = Color(0.98, 0.55, 0.4, 0.8) if card.voids else Color(0.7, 0.6, 0.95, 0.7)
		style.set_content_margin_all(8)
		panel.add_theme_stylebox_override("panel", style)
		var l := Label.new()
		l.text = card.text
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 18)
		l.add_theme_color_override("font_color", Color(0.92, 0.9, 0.98))
		panel.add_child(l)
		_table.add_child(panel)
