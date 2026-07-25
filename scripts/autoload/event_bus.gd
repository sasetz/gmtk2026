extends Node
## The game's spine. Everything that crosses a system boundary rides these
## signals: scene/overlay changes, economy, the four lifecycles, card activation,
## and the shop. Nodes subscribe to what they care about and push state back out
## through the managers.

## Scene / UI
signal switch_scene(new_scene: SceneController.Scene)
signal switch_overlay(new_overlay: SceneController.State)
signal toggle_pause

## Economy
signal money_changed(amount: int)
signal money_spent(amount: int)

## Lifecycle
signal run_started
signal run_ended
signal round_started
signal round_scored(passed: bool)
signal stopwatch_started
signal stopwatch_clicked
signal stopwatch_ended
signal lap_changed(lap: int)

## Cards
signal card_activated(card_index: int)

## Shop
signal shop_entered
signal shop_left
signal card_bought(new_card_index: int)
signal card_sold(old_card_index: int)
