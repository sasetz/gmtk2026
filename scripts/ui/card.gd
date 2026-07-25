extends PanelContainer
## A card view in the HUD. It shows a card's name and texture, and pops when that
## card fires (the HUD routes card_activated to on_activation). The behaviour
## lives on the Card resource; this is only the display.

@onready var _icon: TextureRect = $VBoxContainer/TextureRect
@onready var _name: Label = $VBoxContainer/Label

var card: Card


func setup(c: Card) -> void:
	card = c


func _ready() -> void:
	if card == null:
		return
	_name.text = card.display_name
	tooltip_text = card.description
	if card.texture != null:
		_icon.texture = card.texture


func on_activation() -> void:
	Shake.play(self)
