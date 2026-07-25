extends Control
## Minimal shop between rounds: shows your money and a button to move on. Buying,
## selling and rerolling cards come later; for now it just banks the reward and
## continues the run.

signal continue_pressed

@onready var _money: Label = $Box/Money
@onready var _continue: Button = $Box/Continue


func _ready() -> void:
	EventBus.shop_entered.emit()
	_money.text = "$%d" % RunManager.money
	EventBus.money_changed.connect(func(m: int) -> void: _money.text = "$%d" % m)
	_continue.pressed.connect(_on_continue)
	_continue.grab_focus()


func _on_continue() -> void:
	Audio.play_sfx(&"ui_click")
	continue_pressed.emit()
