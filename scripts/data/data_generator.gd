class_name DataGenerator
extends RefCounted
## Hands out the random data a run needs - rounds, stopwatches, buttons, and shop
## cards - and scales difficulty as the run goes on. Normal rounds are rolled
## from the catalogs under simple constraints; boss rounds are predefined and
## layer negative combos on top. RunManager owns one of these. The numbers are a
## baseline to tune later.

var rng: RandomNumberGenerator
var rounds_made: int = 0


func _init(run_rng: RandomNumberGenerator) -> void:
	rng = run_rng


## The round for a lap + its index within the lap. The last round of a lap is a
## predefined boss; the rest are rolled.
func next_round(lap: int, index_in_lap: int, rounds_per_lap: int) -> RoundDef:
	rounds_made += 1
	var difficulty: int = (lap - 1) * rounds_per_lap + index_in_lap
	if index_in_lap == rounds_per_lap - 1:
		return _boss_round(lap, difficulty)
	return _normal_round(index_in_lap, difficulty)


func _normal_round(index_in_lap: int, difficulty: int) -> RoundDef:
	var r := RoundDef.new()
	r.display_name = "Round %d" % (index_in_lap + 1)
	r.target = 150 * (difficulty + 1)
	r.reward = 3 + index_in_lap
	var count: int = 2 + index_in_lap
	var pos: Array[ComboDef] = ComboCatalog.positives()
	for i in count:
		r.stopwatches.append(_make_stopwatch(difficulty, pos, []))
	return r


## Predefined boss: more stopwatches, each carrying one positive and one negative
## combo, and a heavy target. The layout is fixed per lap (cycling through a small
## set) so bosses feel authored rather than random.
func _boss_round(lap: int, difficulty: int) -> RoundDef:
	var r := RoundDef.new()
	r.is_boss = true
	r.display_name = "Boss"
	r.target = 400 * (difficulty + 1)
	r.reward = 6 + lap
	var pos: Array[ComboDef] = ComboCatalog.positives()
	var neg: Array[ComboDef] = ComboCatalog.negatives()
	# Fixed picks per lap keep a boss consistent from run to run.
	var seed: int = lap - 1
	for i in 5:
		var sw := StopwatchDef.new()
		sw.rate = 1.4
		sw.clicks = 3
		sw.duration_ms = 6000
		# Bosses carry more combos than a normal stopwatch: two positives and a
		# negative to work around.
		sw.combos = [
			_pick_fixed(pos, seed + i),
			_pick_fixed(pos, seed + i + 2),
			_pick_fixed(neg, seed + i + 1),
		]
		r.stopwatches.append(sw)
	return r


func _make_stopwatch(difficulty: int, pos: Array[ComboDef], neg: Array[ComboDef]) -> StopwatchDef:
	var s := StopwatchDef.new()
	# Harder rounds run the clock faster (higher rate = shorter second).
	s.rate = 1.0 + 0.12 * difficulty
	s.clicks = 3
	s.duration_ms = 6000
	s.combos = [_pick_random(pos)]
	if difficulty >= 2 and not pos.is_empty():
		s.combos.append(_pick_random(pos))
	for n: ComboDef in neg:
		s.combos.append(n)
	return s


## The hand of consumable buttons for a round.
func deal_buttons(count: int) -> Array[ButtonDef]:
	var hand: Array[ButtonDef] = []
	for i in count:
		var fresh: Array[ButtonDef] = ButtonCatalog.pool()
		hand.append(fresh[rng.randi_range(0, fresh.size() - 1)])
	return hand


## Cards offered in the shop, excluding ones already owned.
func shop_cards(count: int, owned: Array[StringName]) -> Array[Card]:
	var available: Array[Card] = []
	for c: Card in CardCatalog.pool():
		if not owned.has(c.id):
			available.append(c)
	_shuffle(available)
	return available.slice(0, mini(count, available.size()))


## The cards a fresh run starts with.
func starting_cards() -> Array[Card]:
	var start: Array[Card] = []
	for c: Card in CardCatalog.pool():
		if c.id == &"decimal_dollars":
			start.append(c)
	return start


func _pick_random(pool: Array[ComboDef]) -> ComboDef:
	return pool[rng.randi_range(0, pool.size() - 1)]


func _pick_fixed(pool: Array[ComboDef], index: int) -> ComboDef:
	return pool[index % pool.size()]


## Seeded Fisher-Yates so a run's shop is reproducible from its RNG.
func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
