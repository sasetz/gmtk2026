extends Control
## The shop: spend the money the round paid out. Buy jokers into your board,
## reroll the two offers, or sell cards you've outgrown. Mouse-driven (menu-like)
## while the round itself is keyboard — both work on desktop and web.

signal continue_pressed

const MAX_BOARD: int = 5

@onready var _money: Label = $Box/Header/Money
@onready var _offers: HBoxContainer = $Box/Offers
@onready var _reroll: Button = $Box/Row/Reroll
@onready var _board: HBoxContainer = $Box/Board

var _offer_ids: Array = []
var _bought: Dictionary = {}


func _ready() -> void:
	Economy.enter_shop()
	EventBus.money_changed.connect(func(_m: int) -> void: _refresh())
	_reroll.pressed.connect(_on_reroll)
	$Box/Row/Continue.pressed.connect(func() -> void: continue_pressed.emit())
	_roll_offers()
	_refresh()


func _roll_offers() -> void:
	_bought.clear()
	var owned: Array = RunManager.jokers.map(func(j) -> StringName: return j.id)
	var pool: Array = JokerCatalog.all_ids().filter(func(id: StringName) -> bool: return not owned.has(id))
	_shuffle(pool)
	_offer_ids = pool.slice(0, mini(2, pool.size()))


## Seeded Fisher-Yates so a run's shop is reproducible (Array.shuffle uses the
## global RNG, which would desync seeded runs).
func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = RunManager.rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _reroll_cost() -> int:
	var c: int = Economy.reroll_cost()
	for j in RunManager.jokers:
		if j is JokerRerollRebate:
			c -= (j as JokerRerollRebate).reroll_discount()
	return maxi(1, c)


func _on_reroll() -> void:
	var discount: int = Economy.reroll_cost() - _reroll_cost()
	if Economy.do_reroll(discount):
		_roll_offers()
		_refresh()


func _refresh() -> void:
	_money.text = "$%d" % Economy.money
	_reroll.text = "Reroll  $%d" % _reroll_cost()
	_reroll.disabled = Economy.money < _reroll_cost()
	_render_offers()
	_render_board()


func _render_offers() -> void:
	for c: Node in _offers.get_children():
		c.queue_free()
	for id: StringName in _offer_ids:
		var joker: JokerDef = JokerCatalog.get_joker(id)
		var sold: bool = _bought.get(id, false)
		var can_buy: bool = not sold and Economy.money >= joker.cost and RunManager.jokers.size() < MAX_BOARD
		var card := _card(joker.display_name, joker.description,
			"SOLD" if sold else "Buy  $%d" % joker.cost, can_buy)
		if not sold:
			(card.get_meta("btn") as Button).pressed.connect(_on_buy.bind(id))
		_offers.add_child(card)


func _render_board() -> void:
	for c: Node in _board.get_children():
		c.queue_free()
	for i in RunManager.jokers.size():
		var joker = RunManager.jokers[i]
		var card := _card(joker.display_name, joker.description, "Sell  $%d" % joker.sell_value(), true, true)
		(card.get_meta("btn") as Button).pressed.connect(_on_sell.bind(i))
		_board.add_child(card)


func _on_buy(id: StringName) -> void:
	var joker: JokerDef = JokerCatalog.get_joker(id)
	if RunManager.jokers.size() >= MAX_BOARD or not Economy.try_spend(joker.cost):
		return
	RunManager.jokers.append(joker)
	EventBus.card_bought.emit(joker)
	_bought[id] = true
	_refresh()


func _on_sell(index: int) -> void:
	if index < 0 or index >= RunManager.jokers.size():
		return
	var joker = RunManager.jokers[index]
	Economy.add(joker.sell_value())
	if joker.has_method("on_sell"):
		joker.on_sell()
	RunManager.jokers.remove_at(index)
	EventBus.card_sold.emit(joker)
	_refresh()


## Small card widget with a title, blurb and an action button.
func _card(title: String, blurb: String, action: String, enabled: bool, is_board: bool = false) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(190, 150)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.12, 0.24) if not is_board else Color(0.12, 0.24, 0.2)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(0.7, 0.6, 0.95, 0.6) if not is_board else Color(0.5, 0.8, 0.7, 0.6)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	var name_l := Label.new()
	name_l.text = title
	name_l.add_theme_font_size_override("font_size", 18)
	name_l.add_theme_color_override("font_color", Color(0.98, 0.9, 0.7))
	vb.add_child(name_l)
	var blurb_l := Label.new()
	blurb_l.text = blurb
	blurb_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb_l.custom_minimum_size = Vector2(0, 60)
	blurb_l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	blurb_l.add_theme_font_size_override("font_size", 12)
	blurb_l.add_theme_color_override("font_color", Color(0.82, 0.85, 0.9))
	vb.add_child(blurb_l)
	var btn := Button.new()
	btn.text = action
	btn.disabled = not enabled
	vb.add_child(btn)
	panel.set_meta("btn", btn)
	return panel
