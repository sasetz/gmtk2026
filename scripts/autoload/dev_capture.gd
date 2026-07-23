extends Node
## Agent-facing verification harness (cloned from pixel-dying).
##
## With `-- --verify` the game runs itself: it feeds scripted input, prints
## `[verify] …` assertion lines, saves screenshots to user://verify/, and quits.
## Closes the "did the change actually work?" loop without a human at the keyboard.
##
##   godot --path <project> -- --verify --timer   # base scoring-rule assertions
##   godot --path <project> -- --verify --score   # full chips×mult over a board
##   godot --path <project> -- --verify --run     # the round/boss loop advances
##   godot --path <project> -- --verify           # default: screenshot the scene

const OUT_DIR: String = "user://verify"

var enabled: bool = false


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	enabled = "--verify" in args
	if not enabled:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	if "--timer" in args:
		_run_timer.call_deferred()
	elif "--score" in args:
		_run_score.call_deferred()
	elif "--round" in args:
		_run_round.call_deferred()
	elif "--run" in args:
		_run_loop.call_deferred()
	elif "--game" in args:
		_run_game.call_deferred()
	elif "--shop" in args:
		_run_shop.call_deferred()
	elif "--deception" in args:
		_run_deception.call_deferred()
	elif "--timertable" in args:
		_run_timertable.call_deferred()
	elif "--run2" in args:
		_run_run2.call_deferred()
	elif "--counter" in args:
		_run_counter.call_deferred()
	else:
		_run_default.call_deferred()


# --- scenarios (filled in as each phase lands) ----------------------------

## Asserts the pure scoring rules against the GDD's own examples. No scene
## needed — ScoringRules is static.
func _run_timer() -> void:
	# Each case: [total_ms, tier, expected condition names (sorted), expect_bad]
	var cases: Array = [
		# Straight: all digits equal, leading-zero seconds ignored.
		[5500, 1, ["straight", "odd"], false],          # 05:5
		[3330, 2, ["straight", "odd"], false],          # 03:33
		[7770, 2, ["straight", "odd"], false],          # 07:77
		# Round numbers: decimals all zero.
		[3000, 1, ["round"], false],                    # 03:0
		[10000, 2, ["round"], false],                   # 10:00
		# THE ONE: exactly 01:00 — stacks with round.
		[1000, 1, ["round", "the_one"], false],         # 01:0
		# All or Nothing: last hittable tick before 0.
		[100, 1, ["all_or_nothing", "odd"], false],     # 00:1 (tier1 tenths)
		# Odd / Even on last decimal digit.
		[6300, 1, ["odd"], false],                      # 06:3
		[6200, 1, ["even"], false],                     # 06:2
		# Bad Time 6:66 — hidden trap, scores nothing.
		[6660, 2, [], true],                            # 06:66
	]
	var all_ok: bool = true
	for case: Array in cases:
		var ms: int = case[0]
		var tier: int = case[1]
		var expected: Array = case[2]
		var expect_bad: bool = case[3]
		var res: Dictionary = ScoringRules.evaluate(ms, tier)
		var got: Array = []
		for c: Dictionary in res["conditions"]:
			got.append(String(c["name"]))
		got.sort()
		var want: Array = expected.duplicate()
		want.sort()
		var ok: bool = got == want and res["bad"] == expect_bad
		all_ok = all_ok and ok
		expect("%s  t%d" % [res["digits"]["display"], tier], ok,
			"got=%s want=%s bad=%s" % [got, want, res["bad"]])
	print("[verify] --timer %s" % ("ALL OK" if all_ok else "FAILURES ABOVE"))
	get_tree().quit()


## Drives the interactive round: start the clock, lock 4 presses, confirm the
## _input→press path registers them and a result is produced. (Exact times vary
## with wall-clock; --timer already proves the scoring maths.)
func _run_round() -> void:
	await _settle()
	var round_node: Node = get_tree().current_scene
	var timer: TimerCore = round_node.get_node("Timer")
	await tap(&"press")  # start
	await capture("10_running")
	for i: int in 4:
		await get_tree().create_timer(0.4).timeout
		await tap(&"press")
	await _frames(4)
	expect("4 presses locked", timer.presses.size() == 4, "got %d" % timer.presses.size())
	# The reveal is an overlay child added on finish; catch it mid-sequence…
	await get_tree().create_timer(0.6).timeout
	await capture("11_reveal_beats")
	# …and after the slam + verdict have landed.
	await get_tree().create_timer(2.6).timeout
	await capture("12_reveal_slam")
	var reveal: Node = round_node.get_node_or_null("ScoreReveal")
	expect("reveal present", reveal != null)
	if reveal != null:
		expect("score shown", reveal.get_node("Shake/Center/Score").text != "")
		expect("verdict shown", reveal.get_node("Shake/Center/Verdict").text != "")
	get_tree().quit()


## Proves the scoring engine: known presses + a known board → exact final score,
## computed by hand here. Covers reactive cards, flat mult, xmult, positional
## Copycat, and All In's void.
func _run_score() -> void:
	await _settle()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1

	# Presses: 05:5 (straight+odd 100/5+10/2 = 110/7), 03:00 (round 80/4),
	#          02:2 (straight+even 100/5+10/2 = 110/7 — contains a 2),
	#          01:00 (round+the_one 80/4 + 80/8 = 160/12).
	var presses: Array = [
		ScoringRules.evaluate(5500, 1),   # 05:5
		ScoringRules.evaluate(3000, 1),   # 03:0  (round)
		ScoringRules.evaluate(2200, 2),   # 02:2  no wait — build below
		ScoringRules.evaluate(1000, 1),   # 01:0  round + the_one
	]
	var base_pts: int = 0
	var base_mult: int = 0
	for r: Dictionary in presses:
		base_pts += r["points"]
		base_mult += r["mult"]
	print("[verify] base presses = %d pts, %d mult" % [base_pts, base_mult])

	# Board A: Multi+4 then Odd Ally then Round Robin.
	# Odd Ally: +2 mult per odd beat. Round Robin: +30 pts per round-number beat.
	var board_a: Array = [
		JokerCatalog.get_joker(&"multi_plus"),
		JokerCatalog.get_joker(&"odd_ally"),
		JokerCatalog.get_joker(&"round_robin"),
	]
	var ctx_a: ScoringContext = ScoringEngine.score(presses, board_a, 999999, rng)
	# Expected: reactive — odd beats (05:5, 01:0? 01:0 dec=0 even→ not odd; 05:5 odd,
	# 02:2 even, 03:0 even) → count odd beats via rules; round beats (03:0, 01:0)=2.
	var odd_beats: int = 0
	var round_beats: int = 0
	for r: Dictionary in presses:
		for c: Dictionary in r["conditions"]:
			if c["name"] == &"odd":
				odd_beats += 1
			elif c["name"] == &"round":
				round_beats += 1
	var exp_pts: int = base_pts + 30 * round_beats
	var exp_mult: int = base_mult + 4 + 2 * odd_beats
	var exp_score: int = exp_pts * exp_mult
	expect("board A points", ctx_a.points == exp_pts, "got %d want %d" % [ctx_a.points, exp_pts])
	expect("board A mult", int(ctx_a.mult) == exp_mult, "got %d want %d" % [int(ctx_a.mult), exp_mult])
	expect("board A score", ctx_a.final_score() == exp_score, "got %d want %d" % [ctx_a.final_score(), exp_score])

	# Board B: Multi+4 then All In (x2 mult). xmult picks up the +4 to its left.
	var board_b: Array = [JokerCatalog.get_joker(&"multi_plus"), JokerCatalog.get_joker(&"all_in")]
	var ctx_b: ScoringContext = ScoringEngine.score(presses, board_b, 999999, rng)
	var exp_b: int = base_pts * int(round((base_mult + 4) * 2.0))
	expect("board B xmult order", ctx_b.final_score() == exp_b, "got %d want %d" % [ctx_b.final_score(), exp_b])

	# Board C: Copycat then Multi+4 — Copycat mirrors the +4, total +8 mult.
	var board_c: Array = [JokerCatalog.get_joker(&"copycat"), JokerCatalog.get_joker(&"multi_plus")]
	var ctx_c: ScoringContext = ScoringEngine.score(presses, board_c, 999999, rng)
	var exp_c: int = base_pts * (base_mult + 8)
	expect("board C copycat", ctx_c.final_score() == exp_c, "got %d want %d" % [ctx_c.final_score(), exp_c])

	# Board D: All In with a board that hits nothing → voided to 0.
	var blanks: Array = [ScoringRules.evaluate(4444 + 5, 1)]  # 04:4 -> even, so hits; use a true blank
	# A press that matches nothing: sec=0? use 08:3? that's odd. Force a no-condition
	# time: tier1 08:4 is even (hits). Hard to get zero conditions at tier1, so use
	# a bad time (6:66) which yields no conditions.
	var void_presses: Array = [ScoringRules.evaluate(6660, 2)]  # bad time, 0 conditions
	var ctx_d: ScoringContext = ScoringEngine.score(void_presses, [JokerCatalog.get_joker(&"all_in")], 999999, rng)
	expect("board D all-in void", ctx_d.final_score() == 0, "got %d" % ctx_d.final_score())

	get_tree().quit()


## Deterministic test of the run state machine: play the ante by calling
## round_won() and assert progression, payouts, the boss, and the win — without
## depending on live press timing (that's covered by --game).
func _run_loop() -> void:
	await _settle()
	RunManager.start_run(12345)
	expect("starts on round 1", RunManager.round_index == 0 and not RunManager.current_blind().is_boss)
	expect("start money $4", Economy.money == 4, "$%d" % Economy.money)

	# Round 1 win — reward $3 + interest floor($4/5)=0.
	RunManager.round_won()
	expect("after R1 → shop", RunManager.state == RunManager.State.SHOP)
	expect("R1 payout to $7", Economy.money == 7, "$%d" % Economy.money)
	RunManager.leave_shop()
	expect("R2 next", RunManager.round_index == 1)

	RunManager.round_won()  # R2 reward $4 + interest floor(7/5)=1 → +5 → $12
	expect("R2 payout to $12", Economy.money == 12, "$%d" % Economy.money)
	RunManager.leave_shop()

	RunManager.round_won()  # R3 reward $5 + interest floor(12/5)=2 → +7 → $19
	expect("R3 payout to $19", Economy.money == 19, "$%d" % Economy.money)
	RunManager.leave_shop()

	expect("boss is next", RunManager.current_blind().is_boss and RunManager.current_blind().boss_id == &"miser")
	RunManager.round_won()  # boss → WON
	expect("beating boss = WON", RunManager.state == RunManager.State.WON)

	# Loss path.
	RunManager.start_run(999)
	RunManager.round_lost()
	expect("loss = GAME_OVER", RunManager.state == RunManager.State.GAME_OVER)

	# Miser actually strips joker mult.
	var presses: Array = [ScoringRules.evaluate(5500, 1)]  # 05:5 straight+odd 110/7
	var board: Array = [JokerCatalog.get_joker(&"multi_plus")]  # +4 mult (should be voided)
	var clean: ScoringContext = ScoringEngine.score(presses, board, 0, RunManager.rng, [], &"")
	var mised: ScoringContext = ScoringEngine.score(presses, board, 0, RunManager.rng, [], &"miser")
	expect("miser strips joker mult",
		int(clean.mult) == 11 and int(mised.mult) == 7,
		"clean=%d miser=%d" % [int(clean.mult), int(mised.mult)])
	get_tree().quit()


## Visual smoke test of the whole game scene: HUD, a live round, the reveal, and
## the cashout overlay.
func _run_game() -> void:
	await _settle()
	var game: Node = get_tree().current_scene
	await capture("20_round_start")
	await tap(&"press")   # start the countdown
	for i: int in 4:
		await get_tree().create_timer(0.35).timeout
		await tap(&"press")
	await get_tree().create_timer(7.5).timeout   # let the slower reveal play out
	# The reveal now HOLDS on WIN/LOSE with a Continue button — it must not have
	# auto-advanced to the shop.
	var reveal: Node = game.get_node("RoundHost/Round").get_node_or_null("ScoreReveal")
	expect("reveal holds (no auto-advance)", reveal != null and reveal._awaiting_continue)
	if reveal != null:
		expect("verdict shown", reveal.get_node("Shake/Center/Verdict").text != "")
		expect("continue button visible", reveal.get_node("Continue").visible)
	await capture("21_reveal_hold")
	# Press Continue → shop opens.
	await tap(&"confirm")
	await _frames(6)
	await capture("22_shop")
	var shop: Node = game.get_node("RoundHost").get_node_or_null("Shop")
	expect("continue opens shop", shop != null)
	expect("money advanced", Economy.money > 4, "$%d" % Economy.money)
	get_tree().quit()


## Drives the shop directly: buy an offer, reroll, sell a card — asserting the
## money and board move correctly.
func _run_shop() -> void:
	await _settle()
	RunManager.start_run(7)
	Economy.add(30)  # give it spending money
	var shop: Node = load("res://scenes/shop.tscn").instantiate()
	get_tree().current_scene.add_child(shop)
	await _frames(4)
	await capture("30_shop")

	var board_before: int = RunManager.jokers.size()
	var money_before: int = Economy.money
	# Buy the first offer.
	var first_id: StringName = shop._offer_ids[0]
	var cost: int = JokerCatalog.get_joker(first_id).cost
	shop._on_buy(first_id)
	expect("buy adds to board", RunManager.jokers.size() == board_before + 1)
	expect("buy spends money", Economy.money == money_before - cost, "$%d" % Economy.money)

	# Reroll costs money and changes offers.
	var offers_before: Array = shop._offer_ids.duplicate()
	var money_r: int = Economy.money
	shop._on_reroll()
	expect("reroll spent", Economy.money < money_r, "$%d" % Economy.money)

	# Sell the card we bought back.
	var sell_money: int = Economy.money
	var sell_val: int = RunManager.jokers[RunManager.jokers.size() - 1].sell_value()
	shop._on_sell(RunManager.jokers.size() - 1)
	expect("sell refunds", Economy.money == sell_money + sell_val, "$%d" % Economy.money)
	expect("sell removes card", RunManager.jokers.size() == board_before)
	await capture("31_shop_after")
	get_tree().quit()


## Drives the deception prototype: make the GREEDY pick to show the tempting
## bait tally, then commit to reveal the trap and the breakdown "aha".
func _run_deception() -> void:
	await _settle()
	get_tree().change_scene_to_file("res://scenes/deception_round.tscn")
	await _frames(12)
	var scene: Node = get_tree().current_scene
	await get_tree().create_timer(2.8).timeout   # Peek (2.5s) done → Analyze
	scene._toggle(0)   # Neon (the +5 mult bait)
	scene._toggle(1)   # Slab
	await _frames(4)
	await capture("40_analyze_bait")             # tally shows the tempting 780
	scene._commit()
	await _frames(8)
	await capture("41_commit_aha")               # Dead Air crushes it → 130, FAIL
	get_tree().quit()


## The reconnected model: table of modifiers, countdown-stop as the number.
## Screenshots the peek/running states and both outcomes (obvious straight = trap,
## humble odd = win) via the deterministic debug hook.
func _run_timertable() -> void:
	await _settle()
	var scene: Node = get_tree().current_scene
	await capture("50_peek")
	await get_tree().create_timer(2.7).timeout   # peek → ready
	Input.parse_input_event(_action(&"press", true)); await _frames(2)
	Input.parse_input_event(_action(&"press", false)); await _frames(6)
	await capture("51_running")
	# Deterministic outcomes:
	scene._debug_resolve(5500)   # 05:5 STRAIGHT → voided → 0 (the obvious trap)
	await _frames(6)
	await capture("52_straight_trap")
	# reset + show the winning read
	get_tree().reload_current_scene()
	await _frames(20)
	get_tree().current_scene._debug_resolve(6300)   # 06:3 ODD → 400 → PASS
	await _frames(6)
	await capture("53_odd_win")
	get_tree().quit()


func _action(name: StringName, pressed: bool) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = name
	e.pressed = pressed
	return e


## The full INTEGRATED run: generated table + persistent deck + shop between
## rounds. Clears round 1, cashes out into the shop, buys a joker, plays round 2
## with the grown deck.
func _run_run2() -> void:
	await _settle()
	var scene: Node = get_tree().current_scene
	await capture("60_peek")                       # generated table + countdown + deck
	await get_tree().create_timer(3.2).timeout     # peek → ready
	await capture("61_ready")
	scene._debug_play(scene._board["best"]["seq"]) # play the solver's best → clear
	await _frames(6)
	expect("round 1 cleared", scene._total >= scene._target,
		"%d/%d" % [scene._total, scene._target])
	expect("payout banked (money > start)", Economy.money > 4, "$%d" % Economy.money)
	await capture("62_round_clear")                # shows ROUND CLEAR + +$reward
	# Cash out → the shared shop opens over the table.
	Input.parse_input_event(_action(&"confirm", true)); await _frames(6)
	Input.parse_input_event(_action(&"confirm", false)); await _frames(8)
	var shop: Node = scene.get_node_or_null("Shop")
	expect("cash out opens shop", shop != null)
	await capture("63_shop")
	# Buy the first affordable offer, then leave — the deck must persist.
	var deck_before: int = RunManager.jokers.size()
	if shop != null and not shop._offer_ids.is_empty():
		Economy.add(20)  # ensure affordability for the smoke test
		shop._on_buy(shop._offer_ids[0])
	expect("shop grew the deck", RunManager.jokers.size() == deck_before + 1,
		"%d→%d" % [deck_before, RunManager.jokers.size()])
	scene._leave_shop()
	await _frames(8)
	expect("advanced to round 2", scene._round_idx == 1)
	await capture("64_round2_with_deck")            # new board, deck strip shows growth
	print("[verify] run reached round %d, deck size %d" % [scene._round_idx + 1, RunManager.jokers.size()])
	get_tree().quit()


## Counter-joker showcase: stack the deck with Trap Cutter + Life Vest, start a
## boss board (both high-base grabs trapped), and screenshot the table showing a
## trap visibly CUT — proof the owned deck bends the deceptive table.
func _run_counter() -> void:
	await _settle()
	var scene: Node = get_tree().current_scene
	RunManager.jokers = [
		JokerCatalog.get_joker(&"trap_cutter"),
		JokerCatalog.get_joker(&"life_vest"),
		JokerCatalog.get_joker(&"analyst"),
	]
	scene._round_idx = 4  # boss round → both high-base props trapped
	scene._start_round()
	await _frames(8)
	var cut: int = scene._ctx.disabled_cards.size()
	expect("trap cutter disabled a trap", cut >= 1, "disabled=%d" % cut)
	expect("life vest armed one immunity", scene._ctx.immunities_left == 1,
		str(scene._ctx.immunities_left))
	await capture("70_counter_table")   # a trap shows "(cut)"; deck strip visible
	get_tree().quit()


func _run_default() -> void:
	await _settle()
	await capture("00_boot")
	print("[verify] booted; screenshot saved")
	get_tree().quit()


# --- shared idioms --------------------------------------------------------

func capture(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, shot_name])
	print("[verify] shot %s" % shot_name)


## InputEventAction pushed through the tree — Input.action_press only updates the
## polled state, it does not reach _input handlers.
func tap(action: StringName) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await _frames(2)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _settle() -> void:
	for i: int in 10:
		await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout


## Assertion print helper: consistent, greppable output.
func expect(label: String, ok: bool, detail: String = "") -> void:
	var mark: String = "OK  " if ok else "FAIL"
	print("[verify] %s  %s  %s" % [mark, label, detail])
