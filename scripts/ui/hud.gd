extends Control
## The run HUD: money, lap, round name, and a view per card. It pulls everything
## from the managers and refreshes off the EventBus.

@export var card_scene: PackedScene

@onready var _money: Label = $Money
@onready var _lap: Label = $Lap
@onready var _round: Label = $Round
@onready var _cards: BoxContainer = $Cards


func _ready() -> void:
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.lap_changed.connect(_on_lap_changed)
	EventBus.round_started.connect(_on_round_started)
	EventBus.card_activated.connect(_on_card_activated)
	# Keep the card row in sync when the deck changes (buying / selling).
	EventBus.card_bought.connect(func(_i: int) -> void: _populate())
	EventBus.card_sold.connect(func(_i: int) -> void: _populate())
	EventBus.tutorial_highlight.connect(_on_highlight)


## Lift the deck over the tutorial's dim when it is pointing at the cards.
func _on_highlight(role: StringName) -> void:
	for child: Node in _cards.get_children():
		(child as CanvasItem).z_index = 100 if role == &"card" else 0


func _on_money_changed(amount: int) -> void:
	_money.text = "$%d" % amount


func _on_lap_changed(lap: int) -> void:
	_lap.text = "Lap %d" % lap


func _on_round_started() -> void:
	_round.text = RoundManager.round_def.display_name
	_populate()


func _populate() -> void:
	for c: Node in _cards.get_children():
		c.queue_free()
	for card: Card in RunManager.cards:
		var view := card_scene.instantiate()
		view.setup(card)
		_cards.add_child(view)


func _on_card_activated(index: int) -> void:
	if index >= 0 and index < _cards.get_child_count():
		_cards.get_child(index).on_activation()
