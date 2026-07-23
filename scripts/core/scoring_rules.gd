class_name ScoringRules
extends RefCounted
## Pure, integer-millisecond scoring for a single locked press.
##
## Everything here is static and side-effect-free so it can be unit-tested
## headlessly (see DevCapture --timer). NEVER touches a float: the press comes in
## as integer milliseconds and every condition is an integer test, so there are
## no epsilon/precision pitfalls (research decision #3).
##
## Display precision "tier" controls how many decimal digits are shown AND the
## granularity the player can aim at — tier 1 (tenths) has big forgiving windows
## for new players; tier 3 (milliseconds) is the true precision game.

## Base condition payouts. Upgradeable later — a card or run-modifier can bump
## these, which is why they're data, not literals inline.
const COND := {
	&"straight":       {"points": 100, "mult": 5,  "label": "Straight!"},
	&"round":          {"points": 80,  "mult": 4,  "label": "Round Number"},
	&"odd":            {"points": 10,  "mult": 2,  "label": "Odd"},
	&"even":           {"points": 10,  "mult": 2,  "label": "Even"},
	&"the_one":        {"points": 80,  "mult": 8,  "label": "THE ONE!!"},
	&"all_or_nothing": {"points": 100, "mult": 10, "label": "All or Nothing"},
	&"secret":         {"points": 166, "mult": 11, "label": "Secret Time"},
}


## Decompose a press into its displayed digits at the given tier.
## Returns: {total_ms, tier, sec, frac_ms, dec, dec_str, sec_str, last_digit,
##           digit_string, display}
static func digits(total_ms: int, tier: int) -> Dictionary:
	total_ms = maxi(total_ms, 0)
	var sec: int = total_ms / 1000
	var frac_ms: int = total_ms % 1000
	# Decimal value shown at this tier (tenths / centiseconds / milliseconds).
	var divisor: int = int(pow(10, 3 - tier))
	var dec: int = frac_ms / divisor
	var dec_str: String = str(dec).pad_zeros(tier)
	var sec_str: String = str(sec)  # no leading zero — the "0 doesn't count" rule
	return {
		"total_ms": total_ms,
		"tier": tier,
		"sec": sec,
		"frac_ms": frac_ms,
		"dec": dec,
		"dec_str": dec_str,
		"sec_str": sec_str,
		"last_digit": int(dec_str[dec_str.length() - 1]) - int("0"[0]),
		"digit_string": sec_str + dec_str,
		"display": "%s:%s" % [str(sec).pad_zeros(2), dec_str],
	}


## Evaluate every base condition a press matches.
## Returns: {points, mult, conditions:[{name,points,mult,label}], bad:bool, digits}
## `conditions` is ordered so the reveal can pop them one at a time.
static func evaluate(total_ms: int, tier: int) -> Dictionary:
	var d: Dictionary = digits(total_ms, tier)
	var matched: Array[Dictionary] = []
	var bad: bool = false

	# Bad Time (6:66) — a hidden trap. Wastes the press (0/0) and flags the beat
	# for cards that care ("67 Card" etc.). Needs centisecond precision to reach.
	if d["sec"] == 6 and d["frac_ms"] >= 660 and d["frac_ms"] <= 669:
		bad = true

	if not bad:
		var is_round: bool = d["dec"] == 0
		if is_round:
			matched.append(_cond(&"round"))
		# Straight: every digit equal (leading-zero seconds ignored). Needs 2+ digits.
		if _all_equal(d["digit_string"]) and d["digit_string"].length() >= 2:
			matched.append(_cond(&"straight"))
		# Odd / Even on the last shown decimal digit. Even is gated off round
		# numbers so 03:00 isn't trivially "even" too.
		if d["last_digit"] % 2 == 1:
			matched.append(_cond(&"odd"))
		elif not is_round:
			matched.append(_cond(&"even"))
		# THE ONE — exactly 01:00. Stacks with round (it's a jackpot).
		if d["sec"] == 1 and d["dec"] == 0:
			matched.append(_cond(&"the_one"))
		# All or Nothing — the last hittable tick before 0 at this tier.
		if d["sec"] == 0 and d["dec"] == 1:
			matched.append(_cond(&"all_or_nothing"))

	var points: int = 0
	var mult: int = 0
	for c: Dictionary in matched:
		points += c["points"]
		mult += c["mult"]

	return {
		"points": points,
		"mult": mult,
		"conditions": matched,
		"bad": bad,
		"digits": d,
	}


## Does the press's displayed value contain digit n anywhere (for reactive cards
## like Deuce — "when you hit a 2")?
static func contains_digit(total_ms: int, tier: int, n: int) -> bool:
	return str(n) in digits(total_ms, tier)["digit_string"]


static func _cond(name: StringName) -> Dictionary:
	var base: Dictionary = COND[name]
	return {"name": name, "points": base["points"], "mult": base["mult"], "label": base["label"]}


static func _all_equal(s: String) -> bool:
	for i: int in range(1, s.length()):
		if s[i] != s[0]:
			return false
	return true
