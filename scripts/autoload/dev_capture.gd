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
	elif "--menu" in args:
		_run_menu.call_deferred()
	elif "--pause" in args:
		_run_pause.call_deferred()
	elif "--pips" in args:
		_run_pips.call_deferred()
	elif "--fx" in args:
		_run_fx.call_deferred()
	elif "--liveshop" in args:
		_run_liveshop.call_deferred()
	elif "--livereveal" in args:
		_run_livereveal.call_deferred()
	elif "--liveround" in args:
		_run_liveround.call_deferred()
	elif "--audio" in args:
		_run_audio.call_deferred()
	elif "--fire" in args:
		_run_fire.call_deferred()
	elif "--holo" in args:
		_run_holo.call_deferred()
	elif "--juice" in args:
		_run_juice.call_deferred()
	elif "--ui" in args:
		_run_ui.call_deferred()
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
	# The game now boots into the main menu, so jump straight to the round.
	await _goto("res://scenes/game.tscn")
	var game: Node = get_tree().current_scene
	await capture("20_round_start")
	await tap(&"press")   # start the countdown
	for i: int in 4:
		await get_tree().create_timer(0.35).timeout
		await tap(&"press")
	await get_tree().create_timer(7.5).timeout   # let the slower reveal play out
	# The reveal now HOLDS on WIN/LOSE with a Continue button — it must not have
	# auto-advanced to the shop.
	# Null-safe: if the scripted presses miss their window the round node can be
	# gone, and chaining off a null get_node() kills the whole scenario silently
	# instead of reporting a failure.
	var round_node: Node = game.get_node_or_null("RoundHost/Round")
	expect("round still present", round_node != null)
	var reveal: Node = round_node.get_node_or_null("ScoreReveal") if round_node != null else null
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
	# The HUD must stand down while the shop is up, or the balance renders twice
	# (HUD top-left + shop header top-right) and the titles overlap.
	expect("game HUD hidden during shop", not game.get_node("HUD").visible)
	# …and come back when we return to a round.
	shop.continue_pressed.emit()
	await _frames(8)
	expect("game HUD restored after shop", game.get_node("HUD").visible)
	await capture("23_after_shop")
	get_tree().quit()


## Drives the shop directly: buy an offer, reroll, sell a card — asserting the
## money and board move correctly.
func _run_shop() -> void:
	await _settle()
	await _goto("res://scenes/game.tscn")
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


## The front-of-house flow: main menu → options → credits → tutorial.
func _run_menu() -> void:
	await _settle()
	var menu: Node = get_tree().current_scene
	expect("boots into the main menu", menu.name == "MainMenu", menu.name)
	await capture("80_main_menu")

	# Options overlay: every control present, and a change writes through.
	menu._open(load("res://scenes/options_menu.tscn"))
	await _frames(6)
	var opts: Node = menu._overlay
	expect("options overlay opened", opts != null)
	await capture("81_options")
	Settings.set_master_volume(0.5)
	Settings.set_screen_shake(false)
	await _frames(2)
	expect("master volume applied", is_equal_approx(Settings.master_volume, 0.5),
		str(Settings.master_volume))
	expect("shake setting applied", Settings.screen_shake == false)
	expect("settings persisted", FileAccess.file_exists(Settings.PATH))
	await capture("82_options_changed")
	Settings.reset_to_defaults()
	menu._close_overlay()
	await _frames(4)

	# Credits overlay.
	menu._open(load("res://scenes/credits.tscn"))
	await _frames(6)
	expect("credits overlay opened", menu._overlay != null)
	await capture("83_credits")
	menu._close_overlay()
	await _frames(4)

	# Play → tutorial, and Skip drops into the game.
	await _goto("res://scenes/tutorial.tscn")
	expect("tutorial reached", get_tree().current_scene.name == "Tutorial")
	await capture("84_tutorial")
	var tut: Node = get_tree().current_scene
	tut._on_next()
	await _frames(4)
	await capture("85_tutorial_page2")
	tut._start_game()
	await _frames(10)
	expect("tutorial starts the game", get_tree().current_scene.name == "Game",
		get_tree().current_scene.name)
	get_tree().quit()


## Pause: Esc over gameplay stops the tree and offers options; Esc in a menu
## must NOT pause.
func _run_pause() -> void:
	await _settle()
	# In a menu, Esc must do nothing.
	await tap(&"cancel")
	await _frames(4)
	expect("no pause in the main menu", not PauseMenu.is_open() and not get_tree().paused)

	await _goto("res://scenes/game.tscn")
	await tap(&"cancel")
	await _frames(6)
	expect("Esc pauses gameplay", PauseMenu.is_open(), "open=%s" % PauseMenu.is_open())
	expect("tree actually paused", get_tree().paused)
	await capture("86_paused")

	# Options from the pause menu, then back.
	PauseMenu._open_options()
	await _frames(6)
	expect("pause opens options", PauseMenu._options != null)
	expect("still paused behind options", get_tree().paused)
	await capture("87_pause_options")
	PauseMenu._close_options()
	await _frames(4)

	PauseMenu.close()
	await _frames(4)
	expect("resume unpauses", not get_tree().paused and not PauseMenu.is_open())
	get_tree().quit()


## The press pips: one per lock, filling as presses land.
func _run_pips() -> void:
	await _settle()
	await _goto("res://scenes/round.tscn")
	var round_node: Node = get_tree().current_scene
	var pips: HBoxContainer = round_node.get_node("Center/Pips")
	expect("a pip per press", pips.get_child_count() == round_node._effective_presses(),
		"%d pips vs %d presses" % [pips.get_child_count(), round_node._effective_presses()])
	await capture("88_pips_empty")
	await tap(&"press")   # start the clock
	for i: int in 2:
		await get_tree().create_timer(0.35).timeout
		await tap(&"press")
	await _frames(4)
	var filled: int = 0
	for p: ColorRect in pips.get_children():
		if p.color != round_node.PIP_EMPTY:
			filled += 1
	expect("2 pips filled after 2 presses", filled == 2, "filled=%d" % filled)
	await capture("89_pips_filled")
	get_tree().quit()


## Global screen effects: prove the shader actually alters the frame, that each
## toggle works independently, and that the setting round-trips through disk.
func _run_fx() -> void:
	await _settle()
	await _goto("res://scenes/game.tscn")
	var rect: ColorRect = ScreenFX.get_node("Rect")
	var mat: ShaderMaterial = rect.material

	# All three on (the default look).
	Settings.set_vhs_effect(true)
	Settings.set_fisheye_effect(true)
	Settings.set_pixelate_effect(true)
	await _frames(6)
	expect("fx overlay visible", rect.visible)
	expect("vhs uniform on", float(mat.get_shader_parameter("vhs_amount")) == 1.0)
	expect("fisheye uniform on", float(mat.get_shader_parameter("fisheye_amount")) == 1.0)
	expect("pixelate uniform on", float(mat.get_shader_parameter("pixelate_amount")) == 1.0)
	var all_on: Image = await _grab("90_fx_all")

	# Fisheye only — the warp stays, the tape grain goes.
	Settings.set_vhs_effect(false)
	Settings.set_pixelate_effect(false)
	await _frames(6)
	expect("vhs uniform off", float(mat.get_shader_parameter("vhs_amount")) == 0.0)
	var fish: Image = await _grab("91_fx_fisheye_only")

	# VHS only — flat picture, scanlines + chroma split.
	Settings.set_vhs_effect(true)
	Settings.set_fisheye_effect(false)
	await _frames(6)
	var vhs: Image = await _grab("92_fx_vhs_only")

	# Pixelation only — chunky blocks, nothing else.
	Settings.set_vhs_effect(false)
	Settings.set_pixelate_effect(true)
	await _frames(6)
	expect("pixelate alone keeps overlay visible", rect.visible)
	var pix: Image = await _grab("94_fx_pixelate_only")

	# All off — the overlay unloads entirely (no screen-texture pass at all).
	Settings.set_pixelate_effect(false)
	await _frames(6)
	expect("overlay hidden when all off", not rect.visible)
	var clean: Image = await _grab("93_fx_off")

	# The effects must actually CHANGE pixels, not just flip a flag.
	var d_all: int = _diff_count(all_on, clean)
	var d_fish: int = _diff_count(fish, clean)
	var d_vhs: int = _diff_count(vhs, clean)
	var d_pix: int = _diff_count(pix, clean)
	var d_pix_vhs: int = _diff_count(pix, vhs)
	expect("all-on differs from off", d_all >= 2000, "diff=%d" % d_all)
	expect("fisheye-only differs from off", d_fish >= 200, "diff=%d" % d_fish)
	expect("vhs-only differs from off", d_vhs >= 2000, "diff=%d" % d_vhs)
	# Pixelation only moves EDGE pixels, and this screen is mostly flat felt —
	# a few hundred sampled points is a real, visible effect here.
	expect("pixelate-only differs from off", d_pix >= 100, "diff=%d" % d_pix)
	expect("pixelate-only differs from vhs-only", d_pix_vhs >= 1000, "diff=%d" % d_pix_vhs)

	# --- Motion calmness ---
	# A screenshot cannot show strobing, so measure it instead. On a STATIC
	# scene, consecutive frames should be nearly identical. If a fast wobble or
	# per-frame grain is running, every single pair differs across the whole
	# screen — that constant churn is what reads as flicker and makes people
	# motion sick. We want most consecutive pairs to be quiet.
	Settings.set_vhs_effect(true)
	Settings.set_fisheye_effect(true)
	Settings.set_pixelate_effect(true)
	await _frames(8)
	var pairs: int = 12
	var quiet: int = 0
	var worst: int = 0
	var prev: Image = await _frame_image()
	for i in pairs:
		var cur: Image = await _frame_image()
		var churn: int = _diff_count(prev, cur)
		worst = maxi(worst, churn)
		if churn < 2000:
			quiet += 1
		prev = cur
	expect("most consecutive frames are still", quiet >= int(float(pairs) * 0.6),
		"%d/%d quiet pairs, worst churn %d" % [quiet, pairs, worst])

	# Legibility check: the shop has the smallest text in the game, so shoot it
	# through the full effect stack and eyeball it.
	Settings.set_vhs_effect(true)
	Settings.set_fisheye_effect(true)
	Settings.set_pixelate_effect(true)
	RunManager.start_run(7)
	Economy.add(30)
	var shop: Node = load("res://scenes/shop.tscn").instantiate()
	get_tree().current_scene.add_child(shop)
	await _frames(8)
	await capture("95_fx_shop_legibility")

	# Settings survive a reload from disk.
	Settings.set_vhs_effect(false)
	Settings.set_fisheye_effect(true)
	Settings.set_pixelate_effect(false)
	Settings.vhs_effect = true          # scribble over the in-memory values…
	Settings.fisheye_effect = false
	Settings.pixelate_effect = true
	Settings.load_settings()            # …and prove the file wins
	expect("vhs persisted as off", Settings.vhs_effect == false)
	expect("fisheye persisted as on", Settings.fisheye_effect == true)
	expect("pixelate persisted as off", Settings.pixelate_effect == false)

	Settings.reset_to_defaults()
	get_tree().quit()


## The current frame as an Image, without writing a file — for frame-to-frame
## motion measurements.
func _frame_image() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


## Screenshot AND return the image so scenarios can compare frames.
func _grab(shot_name: String) -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, shot_name])
	print("[verify] shot %s" % shot_name)
	return img


## Do two frames differ meaningfully? Sampled on a grid; tolerant of the
## animated grain so it only reports real structural differences.
## How many sampled points differ between two frames. Sampled on a fine grid;
## thresholds are per-effect because a full-screen tint (VHS) moves almost every
## pixel while an edge-only effect (pixelation, over a mostly flat background)
## legitimately moves very few.
func _diff_count(a: Image, b: Image) -> int:
	var h: int = mini(a.get_height(), b.get_height())
	var w: int = mini(a.get_width(), b.get_width())
	var diff: int = 0
	for y in range(0, h, 4):
		for x in range(0, w, 4):
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			var d: float = absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
			if d > 0.06:
				diff += 1
	return diff


## Drops straight into a stocked shop and LEAVES IT RUNNING to click around in.
## Unlike every other scenario this one never quits — it's for looking at, not
## asserting. Rerolls are funded so you can spin the offers.
func _run_liveshop() -> void:
	await _settle()
	await _goto("res://scenes/game.tscn")
	RunManager.start_run(7)
	Economy.add(60)
	var shop: Node = load("res://scenes/shop.tscn").instantiate()
	get_tree().current_scene.add_child(shop)
	# Force one RARE into the offers so the holographic foil is on screen.
	shop._offer_ids = [&"copycat", &"multi_plus"]
	shop._refresh()
	await _frames(8)
	await capture("96_liveshop")
	print("[verify] live shop open (Copycat = holographic) — buy/sell/reroll; close when done")


## Boot straight into the score reveal with a rare-joker board, so you can watch
## the slam, the holographic joker cards, and hear the Jimbo/coin cues. Stays up.
func _run_livereveal() -> void:
	await _settle()
	await _goto("res://scenes/score_reveal.tscn")
	var reveal: Node = get_tree().current_scene
	var presses: Array = [
		ScoringRules.evaluate(5500, 1),   # 05:5 straight+odd
		ScoringRules.evaluate(3000, 1),   # 03:0 round
		ScoringRules.evaluate(6300, 1),   # 06:3 odd
		ScoringRules.evaluate(1000, 1),   # 01:0 round + THE ONE
	]
	# A board with two RARE jokers (Copycat, All In) → holographic foil cards.
	var board: Array = [
		JokerCatalog.get_joker(&"copycat"),
		JokerCatalog.get_joker(&"multi_plus"),
		JokerCatalog.get_joker(&"all_in"),
	]
	var log: Array = []
	var ctx: ScoringContext = ScoringEngine.score(presses, board, 3000, RunManager.rng, log)
	reveal.play(ctx, log)
	print("[verify] live reveal — holographic jokers + slam + audio; press Continue / close when done")


## Boot straight into a playable round: press SPACE to start, lock 4 times, watch
## the pips fill and hear the clock/chip cues, then the reveal plays. Stays up.
func _run_liveround() -> void:
	await _settle()
	Audio.play_music(&"round")
	await _goto("res://scenes/round.tscn")
	print("[verify] live round — SPACE to start then lock 4 times; close when done")


## Audio smoke test: every registered stream loads, music routes to the Music
## bus and loops, the SFX pool plays on the SFX bus, and the volume sliders move
## the right bus. No speakers required — it inspects the audio graph directly.
func _run_audio() -> void:
	await _settle()

	# Every SFX name resolved to at least one real stream.
	var missing_sfx: Array = []
	for name: StringName in Audio.SFX:
		if (Audio._sfx_streams.get(name, []) as Array).is_empty():
			missing_sfx.append(name)
	expect("all SFX streams loaded", missing_sfx.is_empty(), str(missing_sfx))

	# Every music track loaded and is set to loop.
	var loops_ok: bool = true
	for name: StringName in Audio.MUSIC:
		var s = Audio._music_streams.get(name, null)
		if s == null or (s is AudioStreamMP3 and not (s as AudioStreamMP3).loop):
			loops_ok = false
	expect("all music loaded and looping", loops_ok)

	# Voices route to SFX; music players route to Music.
	var voices_ok: bool = true
	for v in Audio._voices:
		voices_ok = voices_ok and v.bus == "SFX"
	expect("SFX voices on the SFX bus", voices_ok)
	expect("music players on the Music bus",
		Audio._music_a.bus == "Music" and Audio._music_b.bus == "Music")

	# Variant selection: a multi-variant sound must never pick the same clip
	# twice in a row, and over many plays must use its whole set. `coin` has 3.
	var picks: Array = []
	var repeats: int = 0
	for i in 200:
		var idx: int = Audio._pick_variant(&"coin", 3)
		if not picks.is_empty() and idx == picks[picks.size() - 1]:
			repeats += 1
		picks.append(idx)
	var used: Dictionary = {}
	for p in picks:
		used[p] = true
	expect("variant picker never repeats back-to-back", repeats == 0, "%d repeats" % repeats)
	expect("variant picker uses all 3 variants", used.size() == 3, "used %d" % used.size())
	# A single-variant sound just returns it, no crash.
	expect("single-variant returns index 0", Audio._pick_variant(&"point", 1) == 0)

	# Play a cue and confirm a voice actually started.
	Audio.play_sfx(&"chip")
	await _frames(2)
	var any_playing: bool = false
	for v in Audio._voices:
		any_playing = any_playing or v.playing
	expect("play_sfx starts a voice", any_playing)

	# Music routing: ask for the round track, confirm a Music player is live.
	Audio.play_music(&"round")
	await get_tree().create_timer(0.2).timeout
	expect("play_music starts a track",
		Audio._music_a.playing or Audio._music_b.playing)
	expect("current track tracked", Audio._current_track == &"round")
	# Switching tracks crossfades rather than stacking to full volume on both.
	Audio.play_music(&"shop")
	await get_tree().create_timer(0.2).timeout
	expect("switching track updates current", Audio._current_track == &"shop")

	# The volume sliders drive the right buses (linear→dB, muted at zero).
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	var music_idx: int = AudioServer.get_bus_index("Music")
	Settings.set_sfx_volume(0.5)
	expect("sfx slider moves SFX bus",
		is_equal_approx(AudioServer.get_bus_volume_db(sfx_idx), linear_to_db(0.5)),
		"%.1f dB" % AudioServer.get_bus_volume_db(sfx_idx))
	Settings.set_music_volume(0.0)
	expect("music at 0 mutes the Music bus", AudioServer.is_bus_mute(music_idx))
	Settings.set_master_volume(1.0)
	Settings.set_music_volume(1.0)
	Settings.set_sfx_volume(1.0)

	# The global button hook wires clicks onto real buttons.
	await _goto("res://scenes/main_menu.tscn")
	var play_btn: BaseButton = get_tree().current_scene.get_node("Buttons/Play")
	expect("buttons get a click hook", play_btn.pressed.is_connected(Audio._on_any_button))

	get_tree().quit()


## The animated fire-glow title. Let it run so the flame field develops, shoot
## it, then prove it's actually ANIMATING by diffing two spaced frames (a static
## outline would be identical).
func _run_fire() -> void:
	await _settle()
	var title: Node = get_tree().current_scene.get_node_or_null("Title")
	expect("fire title present", title != null)
	# Turn OFF the screen FX so the shot shows the fire itself, not through grain.
	Settings.set_vhs_effect(false)
	Settings.set_fisheye_effect(false)
	Settings.set_pixelate_effect(false)
	await get_tree().create_timer(1.5).timeout
	var a: Image = await _frame_image()
	await capture("97_fire_title")
	await get_tree().create_timer(0.5).timeout
	var b: Image = await _frame_image()
	# Restrict the diff to the title band so menu-static areas don't dilute it.
	# The title is a small band of the frame, so even vivid flames only move ~100
	# sampled points between two spaced frames — that's plenty to prove motion.
	expect("fire title is animating", _diff_count(a, b) >= 60, "churn %d" % _diff_count(a, b))
	Settings.reset_to_defaults()
	get_tree().quit()


## The holographic foil on rare cards, both in the reveal and in the shop.
func _run_holo() -> void:
	await _settle()
	# Shop: force a rare into the offers so its foil shows where players buy.
	await _goto("res://scenes/game.tscn")
	RunManager.start_run(3)
	Economy.add(30)
	var shop: Node = load("res://scenes/shop.tscn").instantiate()
	get_tree().current_scene.add_child(shop)
	shop._offer_ids = [&"copycat", &"all_in"]   # both RARE
	shop._refresh()
	await _frames(6)
	var foils: int = _count_foils(shop)
	expect("rare shop cards show foil", foils >= 2, "found %d" % foils)
	var a: Image = await _grab("98_holo_shop")
	await get_tree().create_timer(0.5).timeout
	var b: Image = await _frame_image()
	expect("holographic foil animates", _diff_count(a, b) >= 60, "churn %d" % _diff_count(a, b))
	get_tree().quit()


## Count ColorRects running the foil shader anywhere under a node.
func _count_foils(root: Node) -> int:
	var n: int = 0
	for c in root.find_children("*", "ColorRect", true, false):
		var cr := c as ColorRect
		if cr.material is ShaderMaterial and (cr.material as ShaderMaterial).shader != null \
				and String((cr.material as ShaderMaterial).shader.resource_path).ends_with("foil.gdshader"):
			n += 1
	return n


## Catch the transient reveal particle moments: the slam burst and the WIN
## confetti (both too brief for the --game shot, which lands seconds later).
func _run_juice() -> void:
	await _settle()
	await _goto("res://scenes/score_reveal.tscn")
	var reveal: Node = get_tree().current_scene
	var presses: Array = [
		ScoringRules.evaluate(5500, 1), ScoringRules.evaluate(3000, 1),
		ScoringRules.evaluate(6300, 1), ScoringRules.evaluate(1000, 1),
	]
	var board: Array = [JokerCatalog.get_joker(&"copycat"), JokerCatalog.get_joker(&"multi_plus")]
	var log: Array = []
	var ctx: ScoringContext = ScoringEngine.score(presses, board, 300, RunManager.rng, log)
	reveal.play(ctx, log)   # coroutine — runs while we time our captures
	# Beats+jokers stagger by ~0.52s each, then ~0.6s anticipation before the slam.
	var to_slam: float = float(log.size()) * 0.52 + 0.7
	await get_tree().create_timer(to_slam).timeout
	await capture("99_slam_burst")
	await get_tree().create_timer(1.15).timeout   # slam → verdict + confetti
	await capture("99b_win_confetti")
	print("[verify] juice shots captured")
	get_tree().quit()


## Global UI polish: striped felt background, and button hover/press scale.
func _run_ui() -> void:
	await _settle()
	var menu: Node = get_tree().current_scene
	var felt: ColorRect = menu.get_node("Felt")
	expect("felt gets the stripes material",
		felt.material is ShaderMaterial and String((felt.material as ShaderMaterial).shader.resource_path)
			.ends_with("stripes.gdshader"))
	await capture("A0_ui_stripes")   # 6-row striped background behind the menu

	var play: BaseButton = menu.get_node("Buttons/Play")
	expect("button is wired for juice", play.has_meta("uifx"))
	# Hover scales it up (waits comfortably longer than the 0.11s tween).
	UiFx._hover(play, true, false)
	await get_tree().create_timer(0.35).timeout
	expect("hover scales button up", play.scale.x > 1.02, "scale %.3f" % play.scale.x)
	await capture("A1_ui_hover")
	# Press scales it down.
	UiFx._press(play)
	await get_tree().create_timer(0.35).timeout
	expect("press scales button down", play.scale.x < 1.0, "scale %.3f" % play.scale.x)
	# Release returns toward hover size.
	UiFx._release(play)
	await get_tree().create_timer(0.35).timeout
	expect("release restores scale", play.scale.x > 1.02, "scale %.3f" % play.scale.x)
	get_tree().quit()


func _run_default() -> void:
	await _settle()
	await capture("00_boot")
	print("[verify] booted; screenshot saved")
	get_tree().quit()


## Change scene and wait for it to actually be current.
func _goto(path: String) -> void:
	get_tree().change_scene_to_file(path)
	await _frames(12)


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
