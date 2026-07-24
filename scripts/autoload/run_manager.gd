extends Node
## Run-level state machine + the blind schedule. Owns the ante, the current
## blind sequence, money payouts on a win, and the run's seeded RNG. The Game
## controller reads current_blind() and calls round_won()/round_lost().

enum State { BOOT, STOPWATCH_SELECT, ROUND, SHOP, WON, GAME_OVER }


var state: int = State.BOOT
var ante: int = 1
var round_index: int = 0
var stopwatch_index: int = 0
var run_seed: int = 0
var rng := RandomNumberGenerator.new()

## The player's equipped board — persists across rounds, grown in the shop.
var jokers: Array = []

var blinds: Array[BlindDef] = []


func start_run(seed_value: int = 0) -> void:
	run_seed = seed_value if seed_value != 0 else int(Time.get_ticks_usec())
	stopwatch_index = 0
	rng.seed = run_seed
	ante = 1
	round_index = 0
	jokers = _starting_board()
	Economy.reset()
	_build_ante()
	state = State.STOPWATCH_SELECT
	EventBus.run_started.emit()
	EventBus.ante_changed.emit(ante)


## A small starting board so a fresh run already shows the systems working.
## The real game would start empty / with one gift card.
func _starting_board() -> Array:
	return [JokerCatalog.get_joker(&"multi_plus"), JokerCatalog.get_joker(&"odd_ally")]


func _build_ante() -> void:
	blinds.clear()
	var scale: float = pow(2.2, ante - 1)
	var tier: int = _tier_for_ante()
	blinds.assign(BlindCatalog.get_ante(ante - 1))
	for i in range(blinds.size()):
		var blind = blinds[i]
		blind.display_name = BossMods.name_of(blind.boss_id) if blind.is_boss \
		else "Round %d" % (i + 1)


func _tier_for_ante() -> int:
	if ante < 3:
		return 1
	return 2 if ante < 5 else 3


func current_blind() -> BlindDef:
	return blinds[round_index]


## Config dict the round scene consumes.
func stopwatch_config(index: int) -> Dictionary:
	var b: BlindDef = current_blind()
	return {
		"duration_ms": b.stopwatches_ms[index],
		"rate": b.stopwatch_rates[index],
		"target": b.target,
		"tier": b.tier,
		"boss_id": b.boss_id,
		"blind_name": b.display_name,
		"jokers": jokers,
	}


## Called when a round is beaten. Pays out, resolves end-of-round joker effects,
## and advances. Returns the next State the Game should present.
func round_won() -> int:
	var b: BlindDef = current_blind()
	var payout: int = b.reward + Economy.interest()
	Economy.add(payout)
	_resolve_round_end()

	if b.is_boss:
		# Beating the ante-1 boss is the vertical slice's win.
		state = State.WON
		EventBus.run_ended.emit(true)
		return state

	round_index += 1
	state = State.SHOP
	EventBus.shop_entered.emit()
	return state


func round_lost() -> int:
	state = State.GAME_OVER
	EventBus.run_ended.emit(false)
	return state


## Leave the shop and move to the next blind.
func leave_shop() -> void:
	state = State.STOPWATCH_SELECT
	EventBus.shop_left.emit()


## End-of-round joker hooks: interest payouts, self-shatter rolls.
func _resolve_round_end() -> void:
	var survivors: Array = []
	for j in jokers:
		var eff: Dictionary = j.on_round_end(null)
		if int(eff.get("dollars", 0)) != 0:
			Economy.add(int(eff["dollars"]))
		if j is JokerGamblersRuin and (j as JokerGamblersRuin).should_destroy(rng):
			continue  # shattered — drop it
		survivors.append(j)
	jokers = survivors


func end_run(won: bool) -> void:
	state = State.WON if won else State.GAME_OVER
	EventBus.run_ended.emit(won)
