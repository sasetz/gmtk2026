extends Node
# Lifetime: run
## Holds the money, the card deck, and the data generator, and drives the run
## loop: it prepares each round, reacts when a round is scored, and advances to
## the shop, the next round, a boss win, or a loss.

const ROUNDS_PER_LAP: int = 4
const STARTING_MONEY: int = 4
const BUTTONS_PER_ROUND: int = 4

var money: int = 0
var cards: Array[Card] = []
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


func _start_round() -> void:
	var def: RoundDef = generator.next_round(lap, round_index, ROUNDS_PER_LAP)
	RoundManager.begin(def, generator.deal_buttons(BUTTONS_PER_ROUND))
	EventBus.round_started.emit()
	EventBus.switch_scene.emit(SceneController.Scene.ROUND)


func _on_round_scored(passed: bool) -> void:
	if not passed:
		EventBus.switch_overlay.emit(SceneController.State.LOST)
		return
	var def: RoundDef = RoundManager.round_def
	add_money(def.reward)
	if def.is_boss:
		# Boss down means the lap is cleared; that ends the run for the slice.
		EventBus.switch_overlay.emit(SceneController.State.WON)
		return
	round_index += 1
	if round_index >= ROUNDS_PER_LAP:
		round_index = 0
		lap += 1
		EventBus.lap_changed.emit(lap)
	EventBus.switch_scene.emit(SceneController.Scene.SHOP)


func _detach_cards() -> void:
	for c in cards:
		c.detach()
