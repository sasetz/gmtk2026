class_name ScoringContext
extends RefCounted
## The mutable accumulator carried through one round's scoring.
##
## Faithful Balatro model: there is ONE running `mult`. Presses seed it; then
## jokers apply left-to-right, each either adding to `points`, adding to `mult`,
## or multiplying `mult` (xmult). Because it's a single running value mutated in
## order, a ×mult joker picks up whatever +mult sat to its left — which is
## exactly what makes card ordering a decision. `final = points × mult`.

var presses: Array[Dictionary] = []   # ScoringRules.evaluate() results, in order
var jokers: Array = []                # JokerDef instances, left-to-right

var base_points: int = 0
var base_mult: int = 0

var points: int = 0                   # running chips
var mult: float = 0.0                 # running mult (float so xmult works)
var dollars: int = 0
## Set by e.g. All In when its bet fails — zeroes the whole score.
var voided: bool = false

var target: int = 0
var rng: RandomNumberGenerator

## Which beat is resolving (reactive cards read this in on_score_eval).
var current_beat: Dictionary = {}
var current_index: int = -1
## Which joker is resolving (positional cards like Copycat read this).
var current_joker_index: int = -1


func _init(press_results: Array = [], score_target: int = 0, run_rng: RandomNumberGenerator = null) -> void:
	presses.assign(press_results)
	target = score_target
	rng = run_rng if run_rng != null else RandomNumberGenerator.new()
	for r: Dictionary in presses:
		base_points += int(r["points"])
		base_mult += int(r["mult"])
	# points/mult start at ZERO and are built up by the engine (beats first, then
	# jokers) so the reveal can animate the accumulation from 0. base_* are kept
	# only for reference.
	points = 0
	mult = 0.0


## Apply one joker's returned effect struct to the running totals, in place.
## Recognised keys: points, mult, xmult, dollars, void.
func apply(effect: Dictionary) -> void:
	if effect.is_empty():
		return
	points += int(effect.get("points", 0))
	mult += float(effect.get("mult", 0.0))
	if effect.has("xmult"):
		mult *= float(effect["xmult"])
	dollars += int(effect.get("dollars", 0))
	if effect.get("void", false):
		voided = true


## Total condition hits across all presses — All In and similar bet cards read it.
func conditions_hit() -> int:
	var n: int = 0
	for r: Dictionary in presses:
		n += (r["conditions"] as Array).size()
	return n


func final_score() -> int:
	if voided:
		return 0
	return int(round(float(points) * mult))


func passed() -> bool:
	return final_score() >= target
