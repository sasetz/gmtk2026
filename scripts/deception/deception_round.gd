extends Control
## Playable proof-of-concept for the deception pivot. Self-contained: no run/
## shop dependency, so it can't disturb the working game on main.
##
## Flow: PEEK (see the board, untimed) → ANALYZE (clock ticks; toggle up to K
## picks; the raw/naive tally is shown — that's the bait) → COMMIT (apply the
## visible RULES; the breakdown reveals which contradiction you missed).

const PEEK_SECONDS: float = 2.5
const ANALYZE_SECONDS: float = 8.0
const PICK_K: int = 2

@onready var _phase: Label = $Root/Top/Phase
@onready var _clock: Label = $Root/Top/Clock
@onready var _target_label: Label = $Root/Top/Target
@onready var _rules_box: VBoxContainer = $Root/Rules/List
@onready var _cards: HBoxContainer = $Root/Cards
@onready var _tally: Label = $Root/Tally
@onready var _commit_btn: Button = $Root/CommitButton
@onready var _breakdown: VBoxContainer = $Root/Breakdown/List
@onready var _breakdown_panel: Panel = $Root/Breakdown

var _values: Array = []
var _rules: Array = []
var _target: int = 150
var _selected: Array = []
var _card_buttons: Array = []

var _phase_name: String = "peek"
var _analyze_left: float = ANALYZE_SECONDS
var _committed: bool = false


func _ready() -> void:
	_build_board()
	_render_board()
	_breakdown_panel.visible = false
	_commit_btn.pressed.connect(_commit)
	_commit_btn.disabled = true
	_enter_peek()


## The "Dead Air" board: mult is a lie. Swap in others to test.
func _build_board() -> void:
	_values = [
		TableCard.value(&"neon", "Neon", 40, 5, "+40\n+5 mult"),
		TableCard.value(&"slab", "Slab", 90, 0, "+90"),
		TableCard.value(&"brick", "Brick", 70, 0, "+70"),
		TableCard.value(&"spark", "Spark", 30, 4, "+30\n+4 mult"),
	]
	_rules = [TableCard.rule(&"deadair", "Dead Air", &"lock_mult", "All mult is locked to 1.")]
	_target = 150
	_target_label.text = "Target  %d" % _target


func _enter_peek() -> void:
	_phase_name = "peek"
	_phase.text = "PEEK — read the board"
	_clock.text = ""
	_set_cards_enabled(false)
	get_tree().create_timer(PEEK_SECONDS).timeout.connect(_enter_analyze)


func _enter_analyze() -> void:
	_phase_name = "analyze"
	_phase.text = "ANALYZE — pick up to %d" % PICK_K
	_set_cards_enabled(true)
	_commit_btn.disabled = false
	_analyze_left = ANALYZE_SECONDS


func _process(delta: float) -> void:
	if _phase_name != "analyze" or _committed:
		return
	_analyze_left -= delta
	_clock.text = "%.1f" % maxf(_analyze_left, 0.0)
	if _analyze_left <= 0.0:
		_commit()


# --- picking --------------------------------------------------------------

func _toggle(index: int) -> void:
	if _phase_name != "analyze" or _committed:
		return
	var card = _values[index]
	if card in _selected:
		_selected.erase(card)
	elif _selected.size() < PICK_K:
		_selected.append(card)
	_refresh_selection()


func _refresh_selection() -> void:
	for i in _card_buttons.size():
		var picked: bool = _values[i] in _selected
		_card_buttons[i].button_pressed = picked
		# Obvious highlight: selected cards glow gold and lift slightly.
		_card_buttons[i].modulate = Color(1.35, 1.2, 0.6) if picked else Color.WHITE
	# The BAIT: raw points x mult, before any rule is applied.
	var p: int = 0
	var m: int = 1
	for c in _selected:
		p += c.points
		m += c.mult
	if _selected.is_empty():
		_tally.text = "select cards…"
	else:
		_tally.text = "%d  ×  %d  =  %d" % [p, m, p * m]


# --- commit / resolve -----------------------------------------------------

func _commit() -> void:
	if _committed:
		return
	_committed = true
	_phase_name = "done"
	_phase.text = "RESULT"
	_clock.text = ""
	_set_cards_enabled(false)
	_commit_btn.disabled = true

	var res: Dictionary = DeceptionResolver.resolve(_selected, _rules)
	var passed: bool = res["score"] >= _target

	for c in _breakdown.get_children():
		c.queue_free()
	for step: String in res["steps"]:
		_add_breakdown(step, Color(0.85, 0.88, 0.92))
	_add_breakdown("= %d points × %d mult = %d" % [res["points"], res["mult"], res["score"]],
		Color(0.98, 0.86, 0.4))
	_add_breakdown("PASS" if passed else "FAIL  (needed %d)" % _target,
		Color(0.4, 0.95, 0.55) if passed else Color(0.95, 0.4, 0.4))
	_breakdown_panel.visible = true
	Juice.punch(_breakdown_panel, 1.1, 0.35)


func _add_breakdown(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", color)
	_breakdown.add_child(l)


# --- rendering ------------------------------------------------------------

func _render_board() -> void:
	for r in _rules:
		var l := Label.new()
		l.text = "⚠  %s — %s" % [r.label, r.text]
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", Color(0.98, 0.55, 0.4))
		_rules_box.add_child(l)
	for i in _values.size():
		var btn := Button.new()
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(150, 190)
		btn.text = "%s\n\n%s" % [_values[i].label, _values[i].text]
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(_toggle.bind(i))
		_cards.add_child(btn)
		_card_buttons.append(btn)


func _set_cards_enabled(on: bool) -> void:
	for b in _card_buttons:
		b.disabled = not on
