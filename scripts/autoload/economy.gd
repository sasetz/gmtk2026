extends Node
## The money economy: balance, interest, rewards, shop costs.
##
## Balatro-calibrated. Money is a single int here; the HUD listens to
## EventBus.money_changed rather than polling.

const START_MONEY: int = 4
## Interest: +$1 per $5 held, capped. The core "hoard vs spend" tension.
const INTEREST_PER: int = 5
const INTEREST_CAP: int = 5
const REROLL_BASE: int = 5

var money: int = START_MONEY
## Rerolls done in the current shop visit; resets on shop enter.
var _reroll_count: int = 0


func reset() -> void:
	money = START_MONEY
	_reroll_count = 0
	EventBus.money_changed.emit(money)


func add(amount: int) -> void:
	money += amount
	EventBus.money_changed.emit(money)


## Returns false (and spends nothing) if the player can't afford it.
func try_spend(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	EventBus.money_changed.emit(money)
	EventBus.money_spent.emit(amount)
	return true


## +$1 per $5 held, capped. Reported separately so the cash-out screen can show
## the breakdown.
func interest() -> int:
	return mini(money / INTEREST_PER, INTEREST_CAP)


func enter_shop() -> void:
	_reroll_count = 0


func reroll_cost() -> int:
	return REROLL_BASE + _reroll_count


## `discount` (from Reroll Rebate) lowers the price but never below $1.
func do_reroll(discount: int = 0) -> bool:
	var cost: int = maxi(1, reroll_cost() - discount)
	if not try_spend(cost):
		return false
	_reroll_count += 1
	return true
