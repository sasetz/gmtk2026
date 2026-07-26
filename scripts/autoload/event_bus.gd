extends Node
## The game's spine. Everything that crosses a system boundary rides these
## signals: scene changes, economy, the four lifecycles, card/combo/button
## activation, and the shop. Nodes subscribe to what they care about and push
## state back out through the managers.

## Scene / UI
signal switch_scene(new_scene: SceneController.Scene)
signal toggle_pause

## Economy
signal money_changed(amount: int)
signal money_spent(amount: int)

## Lifecycle
signal run_started
signal run_ended
signal round_started
signal round_scored(passed: bool)
## A finished round, gated behind a continue button before the shop / game over.
signal round_result(won: bool, is_boss: bool, reward: int)
signal stopwatch_started
signal stopwatch_clicked
signal stopwatch_ended
signal lap_changed(lap: int)

## Activation pulses (for visual flare)
signal card_activated(card_index: int)
signal combo_triggered(combo: ComboDef)
signal button_fired(button: ButtonDef)

## Tutorial
## Point the player at something on the round screen: "stopwatch", "button",
## "card", or "none" to clear it.
signal tutorial_highlight(role: StringName)
signal tutorial_finished

## Shop
signal shop_entered
signal shop_left
signal shop_rolled
signal card_bought(new_card_index: int)
signal card_sold(old_card_index: int)
