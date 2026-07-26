extends Node
# Lifetime: run
## Holds the money, the card deck, the data generator, and the shop offers, and
## drives the run loop. A scored round is gated behind a continue screen before
## the shop (or game over), so the player is never dumped straight into shopping.

const ROUNDS_PER_LAP: int = 4
const STARTING_MONEY: int = 4
const SHOP_OFFERS: int = 3
const REROLL_COST: int = 5
const MAX_CARDS: int = 3

var money: int = 0
var cards: Array[Card] = []
var shop_offers: Array[Card] = []
var generator: DataGenerator
var rng := RandomNumberGenerator.new()
var lap: int = 1
var round_index: int = 0   # index within the current lap


func _ready() -> void:
	EventBus.round_scored.connect(_on_round_scored)
	EventBus.shop_left.connect(_start_round)


func start_run() -> void:
	_detach_cards()
	rng.randomize()
	generator = DataGenerator.new(rng)
	money = STARTING_MONEY
	lap = 1
	round_index = 0
	shop_offers.clear()
	cards = generator.starting_cards()
	for i in cards.size():
		cards[i].run_index = i
		cards[i].attach()
	Tutorial.start()
	EventBus.run_started.emit()
	EventBus.money_changed.emit(money)
	EventBus.lap_changed.emit(lap)
	_start_round()


func end_run() -> void:
	_detach_cards()
	cards.clear()
	EventBus.run_ended.emit()


func add_money(amount: int) -> void:
	money += amount
	EventBus.money_changed.emit(money)


func spend_money(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	EventBus.money_changed.emit(money)
	EventBus.money_spent.emit(amount)
	return true


# --- cards ------------------------------------------------------------------

func can_buy_more() -> bool:
	return cards.size() < MAX_CARDS


func add_card(card: Card) -> void:
	card.run_index = cards.size()
	cards.append(card)
	card.attach()


func remove_card(card: Card) -> void:
	var idx: int = cards.find(card)
	if idx < 0:
		return
	card.detach()
	cards.remove_at(idx)
	for i in cards.size():
		cards[i].run_index = i


## Sell a card for half its cost (rounded down). Available at any time.
func sell_card(card: Card) -> void:
	var idx: int = cards.find(card)
	if idx < 0:
		return
	add_money(card.cost / 2)
	remove_card(card)
	EventBus.card_sold.emit(idx)


# --- shop -------------------------------------------------------------------

func roll_shop() -> void:
	var owned: Array[StringName] = []
	for c: Card in cards:
		owned.append(c.id)
	shop_offers = generator.shop_cards(SHOP_OFFERS, owned)
	EventBus.shop_rolled.emit()


func buy_card(index: int) -> bool:
	if index < 0 or index >= shop_offers.size():
		return false
	if not can_buy_more():
		return false
	var offer: Card = shop_offers[index]
	if not spend_money(offer.cost):
		return false
	shop_offers.remove_at(index)
	add_card(offer)
	EventBus.card_bought.emit(offer.run_index)
	EventBus.shop_rolled.emit()
	return true


func reroll_cost() -> int:
	var cost: int = REROLL_COST
	for c: Card in cards:
		if c is CardRerollRebate:
			cost -= (c as CardRerollRebate).reroll_discount()
	return maxi(1, cost)


func reroll_shop() -> bool:
	if not spend_money(reroll_cost()):
		return false
	roll_shop()
	return true


# --- round loop -------------------------------------------------------------

## The button cap: three by default, raised by any card that grants slots.
func max_buttons() -> int:
	var slots: int = DataGenerator.BASE_MAX_BUTTONS
	for c: Card in cards:
		slots += c.extra_button_slots()
	return slots


func _start_round() -> void:
	# The scripted first lap comes from the tutorial instead of the generator.
	if Tutorial.active:
		var scripted: Card = Tutorial.card()
		if scripted != null and not _owns(scripted.id):
			add_card(scripted)
		RoundManager.begin(Tutorial.round_def(), Tutorial.buttons())
		EventBus.round_started.emit()
		EventBus.switch_scene.emit(SceneController.Scene.ROUND)
		return
	var def: RoundDef = generator.next_round(lap, round_index, ROUNDS_PER_LAP)
	var hand: int = generator.button_count(lap, def.stopwatches.size(), max_buttons())
	RoundManager.begin(def, generator.deal_buttons(hand))
	EventBus.round_started.emit()
	EventBus.switch_scene.emit(SceneController.Scene.ROUND)


func _owns(id: StringName) -> bool:
	for c: Card in cards:
		if c.id == id:
			return true
	return false


## Replay the round the tutorial is on, after a miss.
func retry_round() -> void:
	_start_round()


func _on_round_scored(passed: bool) -> void:
	var def: RoundDef = RoundManager.round_def
	# A missed tutorial round is never a loss - the overlay says something kind
	# and the same round comes round again.
	if Tutorial.active:
		EventBus.round_result.emit(passed, false, def.reward if passed else 0)
		if passed:
			add_money(def.reward)
		return
	if not passed:
		EventBus.round_result.emit(false, def.is_boss, 0)
		return
	add_money(def.reward)
	var was_boss: bool = def.is_boss
	round_index += 1
	if round_index >= ROUNDS_PER_LAP:
		round_index = 0
		lap += 1
		EventBus.lap_changed.emit(lap)
	EventBus.round_result.emit(true, was_boss, def.reward)


## Called by the scene controller when the player leaves the result screen.
func continue_from_result(won: bool) -> void:
	if Tutorial.active:
		if not won:
			retry_round()          # same scripted round, no game over
			return
		Tutorial.step += 1
		if Tutorial.step < Tutorial.STEPS:
			_start_round()
			return
		Tutorial.finish()
		_open_shop_for_next_lap()
		return
	if won:
		roll_shop()
		EventBus.switch_scene.emit(SceneController.Scene.SHOP)
	else:
		end_run()
		EventBus.switch_scene.emit(SceneController.Scene.MAIN_MENU)


## The scripted lap is over: the generator takes it from the next lap on.
func _open_shop_for_next_lap() -> void:
	lap += 1
	round_index = 0
	EventBus.lap_changed.emit(lap)
	roll_shop()
	EventBus.switch_scene.emit(SceneController.Scene.SHOP)


func _detach_cards() -> void:
	for c: Card in cards:
		c.detach()
