extends Node
## Run-level state machine + the blind schedule. Owns the ante, the current
## blind sequence, money payouts on a win, and the run's seeded RNG. The Game
## controller reads current_blind() and calls round_won()/round_lost().

enum State { BOOT, BLIND_SELECT, ROUND, SHOP, WON, GAME_OVER }

## Ante-1 schedule (designer-tuned). [duration_ms, base_target, reward, boss_id].
const SCHEDULE := [
	[13000, 300, 3, &""],
	[11000, 750, 4, &""],
	[9000, 1800, 5, &""],
	[7000, 3000, 7, &"miser"],
]

var state: int = State.BOOT
var ante: int = 1
var round_index: int = 0
var run_seed: int = 0
var rng := RandomNumberGenerator.new()

## The player's equipped board — persists across rounds, grown in the shop.
var jokers: Array = []

## The id pool the shop draws from. Empty → the full catalog (original game).
## The deception run sets this to JokerCatalog.DECEPTION_POOL.
var shop_pool: Array = []

var blinds: Array[BlindDef] = []


func start_run(seed_value: int = 0) -> void:
	run_seed = seed_value if seed_value != 0 else int(Time.get_ticks_usec())
	rng.seed = run_seed
	ante = 1
	round_index = 0
	jokers = _starting_board()
	shop_pool = []   # original game: shop draws from the full catalog
	Economy.reset()
	_build_ante()
	state = State.BLIND_SELECT
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
	for spec: Array in SCHEDULE:
		var b := BlindDef.new()
		b.duration_ms = spec[0]
		b.target = int(round(float(spec[1]) * scale))
		b.reward = spec[2]
		b.boss_id = spec[3]
		b.is_boss = spec[3] != &""
		b.tier = tier
		b.display_name = BossMods.name_of(spec[3]) if b.is_boss else "Round %d" % (blinds.size() + 1)
		blinds.append(b)


func _tier_for_ante() -> int:
	if ante < 3:
		return 1
	return 2 if ante < 5 else 3


func current_blind() -> BlindDef:
	return blinds[round_index]


## Config dict the round scene consumes.
func round_config() -> Dictionary:
	var b: BlindDef = current_blind()
	return {
		"duration_ms": b.duration_ms,
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
	state = State.BLIND_SELECT
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


# --- deception run -----------------------------------------------------------
# The integrated game (deception table + persistent deck + shop) drives itself
# from the run host scene; RunManager just owns the shared, persistent pieces:
# the seeded rng, the joker deck, and the shop pool. The original ante machine
# above is left intact so the legacy game.tscn path still runs.

## A small starting deck so a fresh deception run already shows a joker working.
const DECEPTION_START := [&"multi_plus"]
const DECEPTION_LIVES := 3

## Lives left in the current deception run (miss a round → lose one).
var dec_lives: int = 0


func start_deception_run(seed_value: int = 0) -> void:
	run_seed = seed_value if seed_value != 0 else int(Time.get_ticks_usec())
	rng.seed = run_seed
	dec_lives = DECEPTION_LIVES
	jokers = []
	for id: StringName in DECEPTION_START:
		jokers.append(JokerCatalog.get_joker(id))
	shop_pool = JokerCatalog.DECEPTION_POOL.duplicate()
	Economy.reset()
	EventBus.run_started.emit()


func dec_lose_life() -> void:
	dec_lives = maxi(0, dec_lives - 1)


## End-of-round joker hooks for the deception run: pay out $ jokers (Compound
## Interest) and add the round reward + interest. Returns the money gained.
func deception_round_payout(reward: int) -> int:
	var before: int = Economy.money
	Economy.add(reward + Economy.interest())
	for j in jokers:
		var eff: Dictionary = j.on_round_end(null)
		if int(eff.get("dollars", 0)) != 0:
			Economy.add(int(eff["dollars"]))
	return Economy.money - before
