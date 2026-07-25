extends Node

signal switch_scene(new_scene: SceneSelector.Scene)
signal switch_overlay(new_overlay: SceneSelector.State)
signal toggle_pause

## Economy
signal money_changed(amount: int)
signal money_spent(amount: int)

## Lifecycle
signal run_started
signal run_ended
signal round_started
signal round_scored
signal stopwatch_started
signal stopwatch_clicked
signal stopwatch_ended
signal lap_changed(lap: int)

## Shop
signal shop_entered
signal shop_left
signal card_bought(new_card_index: int)
signal card_sold(old_card_index: int)
