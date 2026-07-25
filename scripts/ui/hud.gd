extends Control

@onready var Money = $Money
@onready var Lap = $Lap
@onready var Round = $Round
@onready var Cards = $Cards

@export var CardScene: PackedScene

var cards := []

func _ready() -> void:
	EventBus.money_changed.connect(func(m: int) -> void: Money.text = "$%d" % m)
	EventBus.lap_changed.connect(func(a: int) -> void: Lap.text = "Lap %d" % a)
	EventBus.round_started.connect(func() -> void: pass)


func _populate() -> void:
	cards.clear()
	for card_index in RunManager.cards.size():
		var card = RunManager.cards[card_index]
		cards.append(card.instantiate())
		cards.back().card = card
		EventBus.card_activated(func(index: int) -> void:
			if index == card_index:
				cards.back().card_activated.emit(card_index)
		)
