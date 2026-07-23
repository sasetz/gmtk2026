extends Node
## Loosely-coupled signal hub.
##
## Used for reactive UI/economy events that don't need ordering — money changed,
## round won, shop opened. The *scoring* pipeline deliberately does NOT go
## through here: scoring needs strict left-to-right order and a mutable
## accumulator, which is the ScoringEngine's job, not a fire-and-forget signal.

## Economy
signal money_changed(amount: int)
signal money_spent(amount: int)

## Run / round lifecycle
signal run_started
signal run_ended(won: bool)
signal round_started(blind: Resource)
signal round_scored(total: int, target: int, passed: bool)
signal ante_changed(ante: int)

## Shop
signal shop_entered
signal shop_left
signal card_bought(joker: Resource)
signal card_sold(joker: Resource)

## Juice — the score reveal broadcasts its beats so audio/screenshake can react
## without the reveal code knowing about them.
signal reveal_beat(kind: StringName, payload: Dictionary)
