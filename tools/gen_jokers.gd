extends SceneTree
## Generates the 12 joker .tres files from code, so the data and the per-card
## script stay in sync and there's no hand-authored .tres syntax to get wrong.
##
## Run: godot --headless --path <project> --script res://tools/gen_jokers.gd

const OUT := "res://data/jokers"

# id → [Script, display_name, kind, rarity, cost, params, description]
# kind: 0 passive, 1 active.  rarity: 0 common, 1 uncommon, 2 rare.


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_make(JokerMultiPlus.new(), &"multi_plus", "Multi +4", 0, 0, 4,
		{"mult": 4.0}, "+4 Mult, every round.")
	_make(JokerRoundRobin.new(), &"round_robin", "Round Robin", 0, 0, 5,
		{"points": 30.0}, "+30 Points each time you hit a round number.")
	_make(JokerDeuce.new(), &"deuce", "Deuce", 0, 1, 5,
		{"points": 24.0, "mult": 6.0}, "Any press showing a 2: +24 Points and +6 Mult.")
	_make(JokerOddAlly.new(), &"odd_ally", "Odd Ally", 0, 0, 4,
		{"mult": 2.0}, "+2 Mult on every odd hit.")
	_make(JokerSlowReveal.new(), &"slow_reveal", "Slow Reveal", 0, 1, 5,
		{"slow_factor": 0.3, "slow_seconds": 1.0},
		"Hit a round number and the timer crawls at 0.3x for 1s.")
	_make(JokerCopycat.new(), &"copycat", "Copycat", 0, 2, 7,
		{}, "Copies the main effect of the card to its right.")
	_make(JokerGamblersRuin.new(), &"gamblers_ruin", "Gambler's Ruin", 0, 1, 6,
		{"mult": 10.0, "destroy_chance": 0.2},
		"+10 Mult. 1 in 5 chance to shatter at end of round.")
	_make(JokerAllIn.new(), &"all_in", "All In", 1, 2, 7,
		{"xmult": 2.0}, "x2 Mult — but score 0 if no condition is hit all round.")
	_make(JokerExtraBeat.new(), &"extra_beat", "Extra Beat", 1, 1, 6,
		{"press_bonus": 1.0, "target_mult": 1.15}, "+1 press. Target +15%.")
	_make(JokerCompoundInterest.new(), &"compound_interest", "Compound Interest", 0, 1, 5,
		{"base": 1.0, "step": 1.0}, "End of round: $1, growing by $1 each round.")
	_make(JokerRerollRebate.new(), &"reroll_rebate", "Reroll Rebate", 0, 0, 4,
		{"discount": 1.0}, "Shop rerolls cost $1 less.")
	_make(JokerMicroscope.new(), &"microscope", "Microscope", 0, 2, 6,
		{"points": 50.0}, "+50 Points on THE ONE or All or Nothing.")
	print("jokers written to ", ProjectSettings.globalize_path(OUT))
	quit()


func _make(def: JokerDef, id: StringName, name: String, kind: int, rarity: int,
		cost: int, params: Dictionary, desc: String) -> void:
	def.id = id
	def.display_name = name
	def.description = desc
	def.kind = kind
	def.rarity = rarity
	def.cost = cost
	def.params = params
	var path: String = "%s/%s.tres" % [OUT, id]
	var err: int = ResourceSaver.save(def, path)
	print("  %s  (%s)" % [path, "ok" if err == OK else "ERR %d" % err])
