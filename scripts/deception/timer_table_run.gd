extends Control
## The INTEGRATED run: the deception table + your persistent Balatro deck + a shop.
##
## A run is 5 escalating rounds, 3 lives, the last one a BOSS. Each round: a
## generated, fuzz-proven deceptive modifier table, then a descending countdown on
## which you make your stops. Your OWNED jokers ride along — score-jokers boost
## each stop, counter-jokers bend the table (disable a trap, rescue a void, echo a
## buff, add a stop). Clear a round and you cash out into the SHOP to grow the
## deck; miss and you lose a life. Beat the boss to win the run.
##
## The deck, money and rng live in RunManager/Economy so the shop scene (shared
## with the original game) plugs straight in.

const ROUNDS: int = 5
const BASE_STOPS: int = 3
const DURATION_MS: int = 12000
const TIER: int = 1
const PEEK_SECONDS: float = 3.0
## Countdown falls at this fraction of real time — generous so hitting your
## intended property is easy (the skill is the read, not the reflex).
const TIMER_RATE: float = 0.45

const ShopScene := preload("res://scenes/shop.tscn")

@onready var _timer: TimerCore = $Timer
@onready var _round_lbl: Label = $HUD/Round
@onready var _target_lbl: Label = $HUD/Target
@onready var _money_lbl: Label = $HUD/Money
@onready var _lives_lbl: Label = $HUD/Lives
@onready var _total_lbl: Label = $HUD/Total
@onready var _table: HBoxContainer = $Table
@onready var _count: Label = $Count
@onready var _prop: Label = $Prop
@onready var _pips: HBoxContainer = $Pips
@onready var _prompt: Label = $Prompt
@onready var _breakdown: VBoxContainer = $Breakdown
@onready var _jokers: HBoxContainer = $Jokers
@onready var _continue: Button = $Continue

const GREEN := Color(0.4, 0.95, 0.55)
const RED := Color(0.95, 0.4, 0.4)
const GOLD := Color(0.98, 0.86, 0.4)

var _round_idx: int = 0

var _cards: Array = []
var _target: int = 0
var _stops: int = BASE_STOPS
var _board: Dictionary = {}
var _ctx: DeceptionContext = null

var _total: int = 0
var _fired: Array = []
var _hit_keys: Dictionary = {}
var _stop_lines: Array[String] = []

var _shop: Control = null
var _state: String = "boot"


func _ready() -> void:
	Input.use_accumulated_input = false
	_timer.pressed.connect(_on_stop)
	_timer.expired.connect(_finish_round)
	_timer.set_rate(TIMER_RATE)
	_continue.pressed.connect(_on_confirm)
	EventBus.money_changed.connect(func(m: int) -> void: _money_lbl.text = "$%d" % m)
	_start_run()


func _is_boss_round() -> bool:
	return _round_idx == ROUNDS - 1


func _start_run() -> void:
	RunManager.start_deception_run()
	_round_idx = 0
	_start_round()


func _start_round() -> void:
	_continue.visible = false
	_clear_breakdown()
	var difficulty: int = _round_idx + 1
	_board = TimerTableGenerator.generate(RunManager.rng, difficulty, _is_boss_round())
	_cards = _board["cards"]
	# The player's owned jokers ride into the round: build the counter-context
	# (disabled traps, immunities, echo) and fold in the setup counters.
	_ctx = DeceptionContext.build(RunManager.jokers, _cards)
	_stops = BASE_STOPS + _stop_bonus()
	_target = _apply_target_multipliers(int(_board["target"]))
	_total = 0
	_fired = []
	_hit_keys = {}
	_stop_lines = []
	_timer.configure(DURATION_MS, _stops, TIER)
	_render_table()
	_render_jokers()
	_build_pips()
	_update_hud()
	_money_lbl.text = "$%d" % Economy.money
	_count.add_theme_color_override("font_color", GOLD)
	_count.text = ScoringRules.digits(DURATION_MS, TIER)["display"]
	_prop.add_theme_color_override("font_color", Color(0.75, 0.9, 0.85))
	_prop.text = ""
	_enter_peek()


func _stop_bonus() -> int:
	var n: int = 0
	for j in RunManager.jokers:
		n += j.stop_bonus()
	return n


## Overtime (and any future stop-adder) makes the target stiffer so the extra
## stop doesn't trivialise the fuzz-proven balance.
func _apply_target_multipliers(target: int) -> int:
	var t: float = float(target)
	for j in RunManager.jokers:
		if j.has_method("target_multiplier"):
			t *= float(j.target_multiplier())
	return int(round(t))


func _enter_peek() -> void:
	_state = "peek"
	var lead: String = "BOSS — " if _is_boss_round() else ""
	_prompt.text = "%sPEEK — read the table  (buffs fire once; repeats fade)" % lead
	get_tree().create_timer(PEEK_SECONDS).timeout.connect(_enter_ready)


func _enter_ready() -> void:
	if _state != "peek":
		return
	_state = "ready"
	_prompt.text = "Press SPACE to start — then STOP %d times on the right properties" % _stops


func _process(_delta: float) -> void:
	if _state != "running":
		return
	var ms: int = _timer.remaining_ms()
	_count.text = ScoringRules.digits(ms, TIER)["display"]
	# Live property read (not the score — you must know which property you want).
	var ev: Dictionary = ScoringRules.evaluate(ms, TIER)
	var names: Array = []
	for c: Dictionary in ev["conditions"]:
		names.append(c["name"])
	_prop.text = ", ".join(names) if not names.is_empty() else "—"


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"press"):
		if _state == "shop":
			return
		get_viewport().set_input_as_handled()
		if _state == "ready":
			_state = "running"
			_prompt.text = "STOP! (%d left)" % _timer.presses_left()
			_timer.start()
		elif _state == "running":
			_timer.press()
		elif _state == "result" or _state == "ended":
			_on_confirm()
	elif event.is_action_pressed(&"confirm") and (_state == "result" or _state == "ended"):
		_on_confirm()


func _on_stop(ms: int, index: int) -> void:
	_apply_stop(ms, index)
	_prompt.text = "STOP! (%d left)" % _timer.presses_left()
	if _timer.presses_left() == 0:
		_finish_round()


func _apply_stop(ms: int, index: int) -> void:
	var r: Dictionary = ModifierTable.resolve(ms, TIER, _cards, _fired, _hit_keys, _ctx)
	_total += int(r["score"])
	_fired.append_array(r["fired_cards"])
	_hit_keys[r["key"]] = int(_hit_keys.get(r["key"], 0)) + 1
	_stop_lines.append("stop %d: %s (%s) → +%d" % [index + 1, r["base_display"], r["key"], int(r["score"])])
	_fill_pip(index, int(r["score"]) > 0)
	_update_hud()
	_render_table()  # dim used buffs
	Juice.punch(_total_lbl, 1.2, 0.25)


## Test hook: play a given property sequence deterministically (no wall-clock).
func _debug_play(props: Array) -> void:
	_state = "running"
	for i in props.size():
		var t: Array = ModifierTable.CANON[props[i]]
		_apply_stop(t[0], i)
	_finish_round()


func _finish_round() -> void:
	if _state == "result":
		return
	_state = "result"
	var passed: bool = _total >= _target
	# Inline result — the cards stay on screen; the board shows the outcome.
	_count.text = str(_total)
	_count.add_theme_color_override("font_color", GREEN if passed else RED)
	if passed:
		var reward: int = 3 + _round_idx
		var gained: int = RunManager.deception_round_payout(reward)
		_set_prop("ROUND CLEAR    %d / %d    ·    +$%d" % [_total, _target, gained], GREEN)
		_show_breakdown(_stop_lines)
		if _is_boss_round():
			_show_continue("Win!  ▶")
		else:
			_show_continue("Cash out  ▶")
	else:
		RunManager.dec_lose_life()
		_set_prop("MISSED    %d / %d    ·    lives %d" % [_total, _target, RunManager.dec_lives], RED)
		_show_breakdown(_stop_lines)
		_show_continue("Retry  ▶" if RunManager.dec_lives > 0 else "New run  ▶")
	_prompt.text = ""
	_update_hud()


func _on_confirm() -> void:
	match _state:
		"result":
			_continue.visible = false
			if _total >= _target:
				if _is_boss_round():
					_end_run(true)
				else:
					_open_shop()
			elif RunManager.dec_lives > 0:
				_start_round()   # retry, fresh board same difficulty
			else:
				_end_run(false)
		"ended":
			_start_run()


func _open_shop() -> void:
	_state = "shop"
	_shop = ShopScene.instantiate()
	_shop.continue_pressed.connect(_leave_shop)
	add_child(_shop)


func _leave_shop() -> void:
	if is_instance_valid(_shop):
		_shop.queue_free()
		_shop = null
	_round_idx += 1
	_start_round()


func _end_run(won: bool) -> void:
	_state = "ended"
	_count.text = "WIN" if won else "OVER"
	_count.add_theme_color_override("font_color", GOLD if won else RED)
	if won:
		_set_prop("YOU BEAT THE RUN — cleared all %d rounds" % ROUNDS, GOLD)
	else:
		_set_prop("GAME OVER — reached round %d of %d" % [_round_idx + 1, ROUNDS], RED)
	_clear_breakdown()
	_show_continue("Play again  ▶")


func _set_prop(text: String, color: Color) -> void:
	_prop.text = text
	_prop.add_theme_color_override("font_color", color)


func _show_continue(text: String) -> void:
	_continue.text = text
	_continue.visible = true
	_continue.pivot_offset = _continue.size * 0.5
	Juice.punch(_continue, 1.2, 0.3)


func _clear_breakdown() -> void:
	for c in _breakdown.get_children():
		c.queue_free()


func _show_breakdown(lines: Array) -> void:
	_clear_breakdown()
	for line in lines:
		var l := Label.new()
		l.text = str(line)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color", Color(0.86, 0.88, 0.92))
		_breakdown.add_child(l)


# --- UI -------------------------------------------------------------------

func _update_hud() -> void:
	var tag: String = "BOSS" if _is_boss_round() else "Round %d/%d" % [_round_idx + 1, ROUNDS]
	_round_lbl.text = tag
	_target_lbl.text = "Target %d" % _target
	_lives_lbl.text = "♥ ".repeat(RunManager.dec_lives).strip_edges()
	_total_lbl.text = "Score %d" % _total


func _render_jokers() -> void:
	for c in _jokers.get_children():
		c.queue_free()
	for j in RunManager.jokers:
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.14, 0.12, 0.24)
		style.set_corner_radius_all(6)
		style.set_border_width_all(1)
		style.border_color = Color(0.7, 0.6, 0.95, 0.6)
		style.set_content_margin_all(6)
		panel.add_theme_stylebox_override("panel", style)
		var l := Label.new()
		l.text = j.display_name
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
		panel.add_child(l)
		_jokers.add_child(panel)


func _build_pips() -> void:
	for c in _pips.get_children():
		c.queue_free()
	for i in _stops:
		var p := ColorRect.new()
		p.custom_minimum_size = Vector2(26, 26)
		p.color = Color(0.3, 0.35, 0.33)
		_pips.add_child(p)


func _fill_pip(index: int, good: bool) -> void:
	if index < _pips.get_child_count():
		_pips.get_child(index).color = Color(0.4, 0.9, 0.5) if good else Color(0.7, 0.35, 0.35)


func _render_table() -> void:
	for c in _table.get_children():
		c.queue_free()
	for card: TimerModCard in _cards:
		var used: bool = card in _fired and not card.voids
		var disabled: bool = _ctx != null and card in _ctx.disabled_cards
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(148, 104)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.32, 0.12, 0.14) if card.voids else Color(0.16, 0.13, 0.26)
		style.set_corner_radius_all(8)
		style.set_border_width_all(2)
		style.border_color = Color(0.98, 0.55, 0.4, 0.85) if card.voids else Color(0.7, 0.6, 0.95, 0.7)
		style.set_content_margin_all(8)
		panel.add_theme_stylebox_override("panel", style)
		panel.modulate = Color(0.42, 0.42, 0.42) if (used or disabled) else Color.WHITE
		var l := Label.new()
		var suffix: String = "\n(cut)" if disabled else ("\n(used)" if used else "")
		l.text = card.text + suffix
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 17)
		l.add_theme_color_override("font_color", Color(0.92, 0.9, 0.98))
		panel.add_child(l)
		_table.add_child(panel)
