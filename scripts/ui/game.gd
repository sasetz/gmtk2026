extends Control
## Top-level run orchestrator: drives blind → round → cashout → next → boss →
## win/lose, reusing the round scene per blind. The cashout screen is the Phase-5
## shop's mount point; for now it just banks the money and continues.

const RoundScene := preload("res://scenes/round_scene.tscn")
const ShopScene := preload("res://scenes/shop.tscn")

@onready var _host: Control = $RoundHost
@onready var _money: Label = $HUD/Money
@onready var _ante: Label = $HUD/Ante
@onready var _blind: Label = $HUD/Blind
@onready var _overlay: Panel = $Overlay
@onready var _overlay_title: Label = $Overlay/Box/Title
@onready var _overlay_sub: Label = $Overlay/Box/Sub

var _round: RoundScene
var _shop: Node
var _mode: String = ""


func _ready() -> void:
	EventBus.money_changed.connect(func(m: int) -> void: _money.text = "$%d" % m)
	EventBus.ante_changed.connect(func(a: int) -> void: _ante.text = "Ante %d" % a)
	RunManager.start_run()
	_money.text = "$%d" % Economy.money
	_start_blind()


func _start_blind() -> void:
	_overlay.visible = false
	_free_round()
	var b: BlindDef = RunManager.current_blind()
	_blind.text = "%s   ·   target %d" % [b.display_name, b.target]
	_round = RoundScene.instantiate()
	_round.configure(b)
	_round.finished.connect(_on_round_finished)
	_host.add_child(_round)


func _on_round_finished(passed: bool) -> void:
	if passed:
		var before: int = Economy.money
		var st: int = RunManager.round_won()
		var gained: int = Economy.money - before
		if st == RunManager.State.WON:
			_show_overlay("YOU BEAT THE ANTE", "+$%d banked\n\n[Enter] new run" % gained, "restart")
		else:
			_open_shop()
	else:
		RunManager.round_lost()
		_show_overlay("GAME OVER", "Needed %d.\n\n[Enter] new run" % RunManager.current_blind().target, "restart")


func _open_shop() -> void:
	_free_round()
	_blind.text = "Shop"
	_shop = ShopScene.instantiate()
	_shop.continue_pressed.connect(_on_shop_continue)
	_host.add_child(_shop)


func _on_shop_continue() -> void:
	if is_instance_valid(_shop):
		_shop.queue_free()
		_shop = null
	RunManager.leave_shop()
	_start_blind()


func _show_overlay(title: String, sub: String, mode: String) -> void:
	_mode = mode
	_overlay_title.text = title
	_overlay_sub.text = sub
	_overlay.visible = true


func _input(event: InputEvent) -> void:
	if _overlay.visible and event.is_action_pressed(&"confirm") and _mode == "restart":
		get_viewport().set_input_as_handled()
		RunManager.start_run()
		_money.text = "$%d" % Economy.money
		_start_blind()


func _free_round() -> void:
	if is_instance_valid(_round):
		_round.queue_free()
		_round = null
