extends HoverableCard
## A single card on offer in the shop: name, blurb, texture and a buy button, with
## the same hover pop/tilt as the HUD cards. Buying goes through the RunManager,
## which re-rolls the offer list; the buy button is off when you can't afford it
## or your hand is already full.

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
	super._ready()
	_name.text = card.display_name
	_desc.text = card.description
	tooltip_text = "%s\n%s" % [card.display_name, card.description]
	if card.texture != null:
		_icon.texture = card.texture
	if RunManager.can_buy_more():
		_buy.text = "Buy  $%d" % card.cost
		_buy.disabled = RunManager.money < card.cost
	else:
		_buy.text = "Hand full"
		_buy.disabled = true
	_buy.pressed.connect(_on_buy)


func _on_buy() -> void:
	Audio.play_sfx(&"card_slide")
	RunManager.buy_card(index)
