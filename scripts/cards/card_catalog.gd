class_name CardCatalog
extends RefCounted
## The pool of cards, converted from the old jokers. The DataGenerator draws
## from here for the run's starting deck and the shop offers. Each call returns
## fresh instances so per-run state (Compound Interest's counter, Gambler's Ruin)
## never leaks between runs. Each card carries a face texture chosen for its type.

const FACES := {
	&"decimal_dollars": preload("res://assets/art/cards/card_money.tres"),
	&"multi_plus": preload("res://assets/art/cards/card_multi.tres"),
	&"round_robin": preload("res://assets/art/cards/card_round_up.tres"),
	&"deuce": preload("res://assets/art/cards/card_two.tres"),
	&"odd_ally": preload("res://assets/art/cards/card_orange.tres"),
	&"microscope": preload("res://assets/art/cards/card_glitch.tres"),
	&"all_in": preload("res://assets/art/cards/card_red.tres"),
	&"gamblers_ruin": preload("res://assets/art/cards/card_luck.tres"),
	&"slow_reveal": preload("res://assets/art/cards/card_slow.tres"),
	&"extra_beat": preload("res://assets/art/cards/card_blue.tres"),
	&"compound_interest": preload("res://assets/art/cards/card_greed.tres"),
	&"reroll_rebate": preload("res://assets/art/cards/card_chips.tres"),
}


static func pool() -> Array[Card]:
	var cards: Array[Card] = []
	cards.append(_make(CardDecimalDollars.new(), "decimal_dollars", "Decimal Dollars",
		"Earn $1 for each lock on a consecutive decimal.", 4))
	cards.append(_make(CardMultiPlus.new(), "multi_plus", "Multi +4",
		"+4 mult on every stopwatch.", 4))
	cards.append(_make(CardRoundRobin.new(), "round_robin", "Round Robin",
		"+30 points when a lock lands on a round number.", 5))
	cards.append(_make(CardDeuce.new(), "deuce", "Deuce",
		"+24 points and +6 mult on every lock ending in .2.", 5))
	cards.append(_make(CardOddAlly.new(), "odd_ally", "Odd Ally",
		"+2 mult on every odd lock.", 5))
	cards.append(_make(CardMicroscope.new(), "microscope", "Microscope",
		"+50 points for a lock dead on a whole second.", 6))
	cards.append(_make(CardAllIn.new(), "all_in", "All In",
		"x2 mult on every stopwatch.", 6))
	cards.append(_make(CardGamblersRuin.new(), "gamblers_ruin", "Gambler's Ruin",
		"+10 mult, but a 1-in-5 chance to shatter each round.", 6))
	cards.append(_make(CardSlowReveal.new(), "slow_reveal", "Slow Reveal",
		"A round-number lock slows the clock for a moment.", 5))
	cards.append(_make(CardExtraBeat.new(), "extra_beat", "Extra Beat",
		"+1 lock per stopwatch, but a stiffer target.", 5))
	cards.append(_make(CardCompoundInterest.new(), "compound_interest", "Compound Interest",
		"Pays a growing dollar bonus each round it survives.", 5))
	cards.append(_make(CardRerollRebate.new(), "reroll_rebate", "Reroll Rebate",
		"Shop rerolls cost $2 less.", 4))
	return cards


static func _make(c: Card, id: String, name: String, desc: String, cost: int) -> Card:
	c.id = StringName(id)
	c.display_name = name
	c.description = desc
	c.cost = cost
	c.texture = FACES.get(c.id, null)
	return c
