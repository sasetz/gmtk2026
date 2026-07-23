extends Control
## One playable round: press to start the countdown, lock N times, then the
## juicy Points×Mult reveal scores it through the engine. Config-driven so the
## run (Phase 4) feeds each blind's duration/target/tier/jokers/boss; falls back
## to standalone defaults so it still runs on its own for --round testing.

signal finished(passed: bool)

const DEFAULT_DURATION_MS: int = 13000
const DEFAULT_PRESS_COUNT: int = 4
const DEFAULT_TIER: int = 1
const DEFAULT_TARGET: int = 300

const RevealScene := preload("res://scenes/score_reveal.tscn")

## Set by the run before the scene enters the tree. Keys: duration_ms, target,
## tier, reward, jokers (Array), boss_id, blind_name. Missing keys use defaults.
var config: Dictionary = {}

@onready var _timer: TimerCore = $Timer
@onready var _time_label: Label = $Center/TimerLabel
@onready var _prompt: Label = $Center/Prompt
@onready var _presses_label: Label = $Center/PressesLabel
@onready var _log: Label = $Center/Log
@onready var _result: Label = $Center/Result

var _duration_ms: int
var _tier: int
var _presses_base: int
var _target_base: int
var _boss_id: StringName
var _standalone: bool = false

var _started: bool = false
var _finished: bool = false
var _press_results: Array[Dictionary] = []
var _reveal: Control

var jokers: Array = []
var _slow_cards: Array = []


func _ready() -> void:
	# Deliver input events immediately instead of merging them per rendered frame
	# — a "hit the exact ms" game must not eat a frame of input latency.
	Input.use_accumulated_input = false
	_duration_ms = config.get("duration_ms", DEFAULT_DURATION_MS)
	_tier = config.get("tier", DEFAULT_TIER)
	_presses_base = config.get("press_count", DEFAULT_PRESS_COUNT)
	_target_base = config.get("target", DEFAULT_TARGET)
	_boss_id = config.get("boss_id", &"")
	jokers = config.get("jokers", jokers)
	# Standalone (no run driving us): a demo board so the joker system is visible.
	if jokers.is_empty():
		_standalone = true
		jokers = [
			JokerCatalog.get_joker(&"multi_plus"),
			JokerCatalog.get_joker(&"odd_ally"),
			JokerCatalog.get_joker(&"round_robin"),
		]
	_slow_cards = jokers.filter(func(j) -> bool: return j is JokerSlowReveal)
	_timer.configure(_duration_ms, _effective_presses(), _tier)
	_timer.pressed.connect(_on_pressed)
	_timer.expired.connect(_on_expired)
	_reset_view()


func _effective_presses() -> int:
	var n: int = _presses_base
	for j in jokers:
		if j is JokerExtraBeat:
			n += (j as JokerExtraBeat).press_bonus()
	return n


func _effective_target() -> int:
	var t: float = float(_target_base)
	for j in jokers:
		if j is JokerExtraBeat:
			t *= (j as JokerExtraBeat).target_multiplier()
	return int(round(t))


func _process(_delta: float) -> void:
	if _started and not _finished:
		_time_label.text = ScoringRules.digits(_timer.remaining_ms(), _tier)["display"]


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"press"):
		_on_press_action()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"confirm") and _finished and _standalone:
		_restart()


func _on_press_action() -> void:
	if _finished:
		return
	if not _started:
		_started = true
		_prompt.text = "Lock your times!"
		_timer.start()
		return
	_timer.press()


func _on_pressed(ms: int, index: int) -> void:
	var result: Dictionary = ScoringRules.evaluate(ms, _tier)
	_press_results.append(result)
	_presses_label.text = "Presses left: %d" % _timer.presses_left()
	_append_log(index, result)
	# Slow Reveal: hitting a round number crawls the clock, easing the next press.
	if not _slow_cards.is_empty() and (result["conditions"] as Array).any(
			func(c: Dictionary) -> bool: return c["name"] == &"round"):
		_apply_slow(_slow_cards[0])
	if _timer.presses_left() == 0:
		_finish()


func _apply_slow(card) -> void:
	_timer.slow(card.slow_factor(), card.slow_seconds())


func _on_expired() -> void:
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	# Score through the engine (records an animation log + honours the boss),
	# then hand off to the reveal. The plain countdown UI hides behind it.
	$Center.visible = false
	var log: Array = []
	var ctx: ScoringContext = ScoringEngine.score(
		_press_results, jokers, _effective_target(), RunManager.rng, log, _boss_id)
	_reveal = RevealScene.instantiate()
	add_child(_reveal)
	_reveal.finished.connect(_on_reveal_finished)
	_reveal.play(ctx, log)


func _on_reveal_finished(passed: bool) -> void:
	EventBus.round_scored.emit(0, _effective_target(), passed)
	finished.emit(passed)


func _append_log(index: int, result: Dictionary) -> void:
	var d: Dictionary = result["digits"]
	var labels: Array[String] = []
	for c: Dictionary in result["conditions"]:
		labels.append(c["label"])
	if result["bad"]:
		labels.append("A Bad Time…")
	var summary: String = ", ".join(labels) if not labels.is_empty() else "nothing"
	_log.text += "#%d  %s  →  %s  (+%d ×%d)\n" % [
		index + 1, d["display"], summary, result["points"], result["mult"],
	]


func _reset_view() -> void:
	_time_label.text = ScoringRules.digits(_duration_ms, _tier)["display"]
	var boss_line: String = ""
	if _boss_id != &"":
		boss_line = "  —  %s: %s" % [BossMods.name_of(_boss_id), BossMods.blurb_of(_boss_id)]
	_prompt.text = "Press SPACE to start%s" % boss_line
	_presses_label.text = "Target %d   ·   Presses: %d" % [_effective_target(), _effective_presses()]
	_log.text = ""
	_result.text = ""


func _restart() -> void:
	if is_instance_valid(_reveal):
		_reveal.queue_free()
		_reveal = null
	$Center.visible = true
	_started = false
	_finished = false
	_press_results.clear()
	_timer.configure(_duration_ms, _effective_presses(), _tier)
	_reset_view()
