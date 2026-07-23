class_name JokerCopycat
extends JokerDef
## "Copycat" — copies the main effect of the card immediately to its right. The
## card that makes board ORDER a decision.
##
## v1 is deliberately one-hop: it copies the right neighbour's on_final_scoring
## once and does not chain through another Copycat (recursive chains are on the
## cut list), so two Copycats side by side don't loop.

func on_final_scoring(ctx) -> Dictionary:
	var right: int = ctx.current_joker_index + 1
	if right >= ctx.jokers.size():
		return {}
	var neighbour = ctx.jokers[right]
	if neighbour is JokerCopycat:
		return {}
	return neighbour.on_final_scoring(ctx)
