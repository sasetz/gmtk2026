extends SceneTree
## Proves the RECONNECTED model: the number comes from the countdown-stop
## (ScoringRules), the face-up table cards are the deceptive modifiers, and the
## OBVIOUS high-base time (a straight) is a trap while a humble easy property
## (odd) secretly wins. Everything is visible — fair by construction.
##
## Run: godot --headless --path <project> --script res://tools/prove_timer_table.gd

func _init() -> void:
	var table: Array = [
		TimerModCard.make(&"odd", 40, 6, 1.0, false, "ODD → +40 pts, +6 mult"),
		TimerModCard.make(&"straight", 0, 0, 1.0, true, "STRAIGHT → score 0"),
		TimerModCard.make(&"even", 0, 2, 1.0, false, "EVEN → +2 mult"),
	]
	var target: int = 350
	print("=== TABLE (all visible) ===")
	for c: TimerModCard in table:
		print("  • " + c.text)
	print("Target %d\n" % target)

	# Candidate stops the player might aim for, by time-property.
	var stops: Array = [
		["STRAIGHT 05:5 (obvious — highest base)", 5500, 1],
		["ODD 06:3 (humble, wide window)", 6300, 1],
		["EVEN 06:2", 6200, 1],
		["ROUND 03:0", 3000, 1],
	]
	var results: Array = []
	for s: Array in stops:
		var r: Dictionary = ModifierTable.resolve(s[1], s[2], table)
		results.append([s[0], r])
		print("%-38s → %5d   %s" % [s[0], r["score"], "PASS" if r["score"] >= target else "miss"])

	# Assertions.
	var straight_score: int = results[0][1]["score"]
	var odd_score: int = results[1][1]["score"]
	print("\n[verify] obvious STRAIGHT scores %d (trap) → %s" % [
		straight_score, "MISS" if straight_score < target else "clears"])
	print("[verify] humble ODD scores %d → %s" % [
		odd_score, "clears" if odd_score >= target else "MISS"])
	var ok: bool = straight_score < target and odd_score >= target and odd_score > straight_score
	print("[verify] reconnected trap: %s" % ("WORKS & FAIR" if ok else "*** BROKEN ***"))

	print("\n--- why (ODD breakdown) ---")
	for step: String in results[1][1]["steps"]:
		print("   " + step)
	print("--- why (STRAIGHT breakdown) ---")
	for step: String in results[0][1]["steps"]:
		print("   " + step)
	quit()
