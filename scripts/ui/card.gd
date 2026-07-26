extends HoverableCard
## A card view in the HUD. Shows the card's name and texture, tooltips what it
## does, pops when the card fires, and reveals a sell button on hover so the
## player can cash it in at any time. The behaviour lives on the Card resource.

@onready var _icon: TextureRect = $VBoxContainer/TextureRect
@onready var _name: Label = $VBoxContainer/Label
@onready var _sell: Button = $VBoxContainer/Sell

var card: Card


func setup(c: Card) -> void:
	card = c


func _ready() -> void:
	super._ready()
	# Kept in the layout always (so hover doesn't resize the card); faded out and
	# disabled until hovered.
	_sell.modulate.a = 0.0
	_sell.disabled = true
	_sell.pressed.connect(_on_sell)
	if card == null:
		return
	_name.text = card.display_name
	tooltip_text = "%s\n%s" % [card.display_name, card.description]
	_sell.text = "Sell $%d" % (card.cost / 2)
	if card.texture != null:
		_icon.texture = card.texture


func on_activation() -> void:
	Shake.play(self)


func _hover_changed(on: bool) -> void:
	_sell.modulate.a = 1.0 if on else 0.0
	_sell.disabled = not on


func _on_sell() -> void:
	Audio.play_sfx(&"crumple")
	RunManager.sell_card(card)
