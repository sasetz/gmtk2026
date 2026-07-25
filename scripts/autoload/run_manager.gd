extends Node
# Lifetime: run
## Holds the money, the card deck, the data generator, and the shop offers, and
## drives the run loop. A scored round is gated behind a continue screen before
## the shop (or game over), so the player is never dumped straight into shopping.

const ROUNDS_PER_LAP: int = 4
const STARTING_MONEY: int = 4
const BUTTONS_PER_ROUND: int = 4
const SHOP_OFFERS: int = 3
const REROLL_COST: int = 5

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

func _start_round() -> void:
	var def: RoundDef = generator.next_round(lap, round_index, ROUNDS_PER_LAP)
	RoundManager.begin(def, generator.deal_buttons(BUTTONS_PER_ROUND))
	EventBus.round_started.emit()
	EventBus.switch_scene.emit(SceneController.Scene.ROUND)


func _on_round_scored(passed: bool) -> void:
	var def: RoundDef = RoundManager.round_def
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
	if won:
		roll_shop()
		EventBus.switch_scene.emit(SceneController.Scene.SHOP)
	else:
		end_run()
		EventBus.switch_scene.emit(SceneController.Scene.MAIN_MENU)


func _detach_cards() -> void:
	for c: Card in cards:
		c.detach()
