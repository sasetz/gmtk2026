extends HoverableCard
## The single card view used everywhere (HUD deck and shop offers), so a card
## looks identical wherever it appears. It shows the card's face, tooltips what it
## does, pops when the card fires, and carries one action button:
##   - HUD mode:  a Sell button revealed on hover (half cost).
##   - Shop mode: a Buy button, always shown.
## Sheen and tilt come from HoverableCard and stay active in both modes.

@onready var _face: TextureRect = $VBox/Face
@onready var _action: Button = $VBox/Action

var card: Card
var _shop_index: int = -1
var _shop_mode: bool = false


## HUD mode: an owned card with a hover-to-sell button.
func setup(c: Card) -> void:
	card = c
	_shop_mode = false


## Shop mode: an offer with a buy button.
func setup_shop(c: Card, index: int) -> void:
	card = c
	_shop_index = index
	_shop_mode = true


func _ready() -> void:
	super._ready()
	_action.pressed.connect(_on_action)
	if card == null:
		return
	tooltip_text = "%s\n%s" % [card.display_name, card.description]
	if card.texture != null:
		_face.texture = card.texture
	if _shop_mode:
		_refresh_buy()
	else:
		# Sell stays in the layout (so hover doesn't resize the card) but hidden
		# and disabled until hovered.
		_action.text = "Sell $%d" % (card.cost / 2)
		_action.modulate.a = 0.0
		_action.disabled = true


func _refresh_buy() -> void:
	if RunManager.can_buy_more():
		_action.text = "Buy $%d" % card.cost
		_action.disabled = RunManager.money < card.cost
	else:
		_action.text = "Full"
		_action.disabled = true


func on_activation() -> void:
	Shake.play(self)


func _hover_changed(on: bool) -> void:
	if _shop_mode:
		return
	_action.modulate.a = 1.0 if on else 0.0
	_action.disabled = not on


func _on_action() -> void:
	if _shop_mode:
		Audio.play_sfx(&"card_slide")
		RunManager.buy_card(_shop_index)
	else:
		Audio.play_sfx(&"crumple")
		RunManager.sell_card(card)
