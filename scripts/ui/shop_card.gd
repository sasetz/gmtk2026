extends PanelContainer
## A single card on offer in the shop: name, blurb, texture and a buy button.
## Buying goes through the RunManager, which re-rolls the offer list, so this view
## just fires the request.

@onready var _icon: TextureRect = $Box/Icon
@onready var _name: Label = $Box/Name
@onready var _desc: Label = $Box/Desc
@onready var _buy: Button = $Box/Buy

var card: Card
var index: int


func setup(c: Card, i: int) -> void:
	card = c
	index = i


func _ready() -> void:
	_name.text = card.display_name
	_desc.text = card.description
	if card.texture != null:
		_icon.texture = card.texture
	_buy.text = "Buy  $%d" % card.cost
	_buy.disabled = RunManager.money < card.cost
	_buy.pressed.connect(_on_buy)


func _on_buy() -> void:
	Audio.play_sfx(&"card_slide")
	RunManager.buy_card(index)
