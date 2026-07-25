extends PanelContainer
## A card view in the HUD. It shows a card's name and reacts when that card fires
## (the HUD routes card_activated to on_activation). The behaviour lives on the
## Card resource; this is only the display.

@onready var _name: Label = $VBoxContainer/Label

var card: Card


func setup(c: Card) -> void:
	card = c


func _ready() -> void:
	if card != null:
		_name.text = card.display_name
		tooltip_text = card.description


func on_activation() -> void:
	pass # TODO: visual pulse when the card fires
