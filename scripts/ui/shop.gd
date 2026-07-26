extends Control
## The shop between rounds: buy cards from the offers the RunManager rolled,
## reroll for a fresh set, or continue. All data comes from the run generator via
## the RunManager; this just renders it.

signal continue_pressed

@export var shop_card_scene: PackedScene

@onready var _offers: HBoxContainer = $Offers
@onready var _reroll: Button = $Footer/Reroll
@onready var _continue: Button = $Footer/Continue


func _ready() -> void:
	EventBus.shop_entered.emit()
	EventBus.money_changed.connect(_on_changed)
	EventBus.shop_rolled.connect(_rebuild)
	_reroll.pressed.connect(_on_reroll)
	_continue.pressed.connect(_on_continue)
	_rebuild()
	_continue.grab_focus()


func _on_changed(_amount: int) -> void:
	_rebuild()


func _rebuild() -> void:
	for c: Node in _offers.get_children():
		c.queue_free()
	for i in RunManager.shop_offers.size():
		var view := shop_card_scene.instantiate()
		view.setup_shop(RunManager.shop_offers[i], i)
		_offers.add_child(view)
	_reroll.text = "Reroll  $%d" % RunManager.reroll_cost()
	_reroll.disabled = RunManager.money < RunManager.reroll_cost()


func _on_reroll() -> void:
	Audio.play_sfx(&"ui_click")
	RunManager.reroll_shop()


func _on_continue() -> void:
	Audio.play_sfx(&"ui_click")
	continue_pressed.emit()
