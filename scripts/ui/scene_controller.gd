extends Control
## The single scene controller. It owns the whole app flow so no other scene has
## to call change_scene_to_file or juggle overlays:
##   • which SCREEN is shown (main menu vs the run) — mounted in $Screen,
##   • the RUN loop (round -> shop -> next -> boss -> win/lose),
##   • the HUD (money / ante / blind, and its visibility),
##   • the OVERLAYS (options, credits, pause, and the win/lose result panel).
##
## Screens and the round/shop are plain scenes that report back by signal; the
## controller decides what happens next.

const MenuScene := preload("res://scenes/main_menu.tscn")
const RoundScene := preload("res://scenes/round_scene.tscn")
const ShopScene := preload("res://scenes/shop.tscn")
const OptionsScene := preload("res://scenes/options_menu.tscn")
const CreditsScene := preload("res://scenes/credits.tscn")
const PauseScene := preload("res://scenes/pause_menu.tscn")

@onready var _screen: Control = $Screen
@onready var _hud: HBoxContainer = $HUD
@onready var _money: Label = $HUD/Money
@onready var _ante: Label = $HUD/Ante
@onready var _blind: Label = $HUD/Blind
@onready var _overlays: Control = $Overlays
@onready var _result: Panel = $Result
@onready var _result_title: Label = $Result/Box/Title
@onready var _result_sub: Label = $Result/Box/Sub
@onready var _result_again: Button = $Result/Box/Again

var _round: Node = null
var _shop: Node = null
var _overlay: Control = null   # options / credits
var _pause: Control = null


func _ready() -> void:
	EventBus.money_changed.connect(func(m: int) -> void: _money.text = "$%d" % m)
	EventBus.ante_changed.connect(func(a: int) -> void: _ante.text = "Ante %d" % a)
	to_menu()


# --- screens ----------------------------------------------------------------

func to_menu() -> void:
	_set_paused(false)
	_close_overlay()
	_round = null
	_shop = null
	_result.visible = false
	_hud.visible = false
	var menu: Control = MenuScene.instantiate()
	menu.play_pressed.connect(start_run)
	menu.options_pressed.connect(_open_options)
	menu.credits_pressed.connect(_open_credits)
	menu.quit_pressed.connect(func() -> void: get_tree().quit())
	_mount(menu)
	Audio.play_music(&"menu")


func start_run() -> void:
	RunManager.start_run()
	_money.text = "$%d" % Economy.money
	_result.visible = false
	_start_blind()


func _start_blind() -> void:
	_shop = null
	_result.visible = false
	_hud.visible = true
	Audio.play_music(&"round")
	var b: BlindDef = RunManager.current_blind()
	_blind.text = "%s   ·   target %d" % [b.display_name, b.target]
	var round: Node = RoundScene.instantiate()
	round.configure(b)
	round.finished.connect(_on_round_finished)
	_mount(round)
	_round = round


func _on_round_finished(passed: bool) -> void:
	if passed:
		var before: int = Economy.money
		var st: int = RunManager.round_won()
		var gained: int = Economy.money - before
		if st == RunManager.State.WON:
			_show_result("YOU BEAT THE ANTE", "+$%d banked" % gained)
		else:
			_open_shop()
	else:
		RunManager.round_lost()
		_show_result("GAME OVER", "Needed %d." % RunManager.current_blind().target)


func _open_shop() -> void:
	_round = null
	# The shop is a full-screen takeover with its own money readout, so the HUD
	# would double it up — hide it while shopping.
	_hud.visible = false
	Audio.play_music(&"shop")
	var shop: Node = ShopScene.instantiate()
	shop.continue_pressed.connect(_on_shop_continue)
	_mount(shop)
	_shop = shop


func _on_shop_continue() -> void:
	RunManager.leave_shop()
	_start_blind()


## Free whatever's in the screen slot and mount `node` there.
func _mount(node: Node) -> void:
	for c: Node in _screen.get_children():
		c.queue_free()
	_screen.add_child(node)


# --- result (win / lose) ----------------------------------------------------

func _show_result(title: String, sub: String) -> void:
	_hud.visible = false
	_result_title.text = title
	_result_sub.text = sub
	_result.visible = true
	_result_again.grab_focus()


func _on_again_pressed() -> void:
	Audio.play_sfx(&"ui_click")
	start_run()


func _on_menu_pressed() -> void:
	Audio.play_sfx(&"ui_click")
	to_menu()


# --- overlays (options / credits) -------------------------------------------

func _open_options() -> void:
	_push_overlay(OptionsScene)


func _open_credits() -> void:
	_push_overlay(CreditsScene)


func _push_overlay(scene: PackedScene) -> void:
	if _overlay != null:
		return
	_overlay = scene.instantiate()
	_overlay.closed.connect(_close_overlay)
	_overlays.add_child(_overlay)


func _close_overlay() -> void:
	if _overlay == null:
		return
	_overlay.queue_free()
	_overlay = null


# --- pause ------------------------------------------------------------------

## Esc opens the pause overlay during a run (a round or the shop), unless an
## overlay is already up (options/credits own Esc to close themselves).
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"cancel"):
		return
	if _pause != null or _overlay != null or not _in_run():
		return
	get_viewport().set_input_as_handled()
	_open_pause()


func _in_run() -> bool:
	return not _result.visible and (_round != null or _shop != null)


func _open_pause() -> void:
	_set_paused(true)
	_pause = PauseScene.instantiate()
	_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause.resume_pressed.connect(_close_pause)
	_pause.options_pressed.connect(_open_options)
	_pause.menu_pressed.connect(to_menu)
	_overlays.add_child(_pause)


func _close_pause() -> void:
	if _pause != null:
		_pause.queue_free()
		_pause = null
	_set_paused(false)


func _set_paused(on: bool) -> void:
	get_tree().paused = on
