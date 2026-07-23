@tool
class_name JokerDef
extends Resource
## One Joker card, authored as a .tres in data/jokers/.
##
## Data-driven on purpose (cloned from pixel-dying's ItemDef): tuning a card's
## cost, rarity or numbers should never mean touching code. The *behaviour* lives
## in a small per-card script (see scripts/jokers/*.gd) that extends this and
## overrides only the hooks it uses — the scoring engine never switches on id.

enum Rarity { COMMON, UNCOMMON, RARE }
## Passive = triggers during/after scoring. Active = armed before a round (a bet).
enum Kind { PASSIVE, ACTIVE }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

@export var kind: Kind = Kind.PASSIVE
@export var rarity: Rarity = Rarity.COMMON
@export var cost: int = 4
## Free-form numbers the behaviour script reads, so sibling cards can share one
## script and differ only by data (e.g. "+N mult" with n from here).
@export var params: Dictionary = {}


func sell_value() -> int:
	return maxi(1, cost / 2)


# --- helpers for card scripts (keep the per-card scripts tiny) -------------

## Does the beat currently resolving carry the named base condition?
func beat_has(ctx, cond_name: StringName) -> bool:
	for c: Dictionary in ctx.current_beat.get("conditions", []):
		if c["name"] == cond_name:
			return true
	return false


## The displayed digit string of the current beat (for "contains an N" cards).
func beat_digits(ctx) -> String:
	return ctx.current_beat.get("digits", {}).get("digit_string", "")


func num(key: String, fallback: float) -> float:
	return float(params.get(key, fallback))


# --- hooks (all no-op by default; a card overrides only what it needs) -----
# Every hook receives the shared ScoringContext / run state and returns an
# effect struct {chips, mult, xmult, dollars, message} where relevant, which the
# engine applies in strict left-to-right order.

func on_round_start(_ctx) -> void:
	pass


## The player locked in a press. ctx.current_beat holds the time + base result.
func on_press(_ctx) -> Dictionary:
	return {}


## Called per beat during scoring, left-to-right. Reactive cards ("when you hit a
## 2…") check ctx themselves here — one mechanism covers every such card.
func on_score_eval(_ctx) -> Dictionary:
	return {}


## After all beats, before Points×Mult is totalled. Global ×mult stamps here.
func on_final_scoring(_ctx) -> Dictionary:
	return {}


func on_round_end(_ctx) -> Dictionary:
	return {}


func on_shop_enter() -> void:
	pass


func on_sell() -> void:
	pass
