# Balatro Count-Down

A Balatro-style rogulike where, instead of playing cards, you **stop a countdown
timer** by pressing a button at scoring times. Godot 4.6, GL Compatibility,
desktop + web. First-playable vertical slice: one full Ante (3 rounds → boss →
shop → win/lose).

## Play

| Input | Action |
|---|---|
| **Space / LMB** | press the button — first press starts the countdown, then lock 4 times |
| **Enter** | confirm / continue / new run |
| Mouse | shop (buy / reroll / sell) |

Lock your presses on scoring times to build **Points × Multiplier**:

| Condition | Example | Points × Mult |
|---|---|---|
| Straight (all digits equal) | `05:5`, `03:33` | 100 × 5 |
| Round number | `03:00`, `10:00` | 80 × 4 |
| Odd / Even last decimal | `06:3` / `06:2` | 10 × 2 |
| THE ONE (exactly `01:00`) | `01:00` | 80 × 8 |
| All or Nothing (last tick) | `00:1` | 100 × 10 |
| Bad Time (hidden trap) | `06:66` | scores 0 |

Beat each blind's target, cash out (reward + interest), spend in the shop, then
face **The Miser** (disables joker mult). Miss a target and the run ends.

## Architecture

Every gameplay fact is verified against fresh Godot 4.6 docs and proven with a
headless assertion harness before it's trusted — see `scripts/autoload/dev_capture.gd`.

| Path | What |
|---|---|
| `scripts/core/timer_core.gd` | The clock. `Time.get_ticks_usec()` reference time (integer µs, immune to frame rate); a rate-integrating design lets Slow Reveal genuinely bend the countdown without losing precision. Press captured in `_input`. |
| `scripts/core/scoring_rules.gd` | Pure, **integer-millisecond** condition detection — zero float comparisons, so no epsilon pitfalls. |
| `scripts/core/scoring_engine.gd` | Generic left-to-right loop. Calls `calculate` hooks on each joker and applies a returned `{points, mult, xmult, dollars, void}` struct — **no match statement**; card order matters (a ×mult picks up the +mult to its left). Emits an animation log. |
| `scripts/core/scoring_context.gd` | The mutable accumulator carried through scoring. |
| `scripts/data/joker_def.gd` + `scripts/jokers/*.gd` | A card = a `Resource` (`.tres`) + a tiny per-card script overriding only the hooks it uses. Adding card #13 is a `.tres` + ~10 lines. |
| `scripts/data/joker_catalog.gd` | Registry; hands out fresh duplicates (cards carry per-run state). |
| `scripts/core/boss_mods.gd` | Boss rule-changes (Miser wired; Mirror coded; Rusher/Flinch defined). |
| `scripts/autoload/run_manager.gd` | Run state machine + blind schedule + payouts. |
| `scripts/autoload/economy.gd` | Money, interest (`min($/5, 5)`), reroll/sell costs. |
| `scripts/ui/score_reveal.gd` | The money moment — replays the engine log: beats fly in, counters roll, jokers fire L→R, `Points × Mult` slams with punch + shake + particles. |
| `scripts/ui/juice.gd` | Reusable game-feel (scale-punch, rolling counter, screen shake). |
| `scripts/ui/shop.gd` · `game.gd` · `round_scene.gd` | Shop, run orchestrator, one round. |
| `shaders/crt.gdshader` · `foil.gdshader` | Portable CRT scanline+vignette (multiply blend, no screen-read) and holographic foil for rare cards. |

## Dev tools

```bash
# headless assertion suites — no human needed
godot --headless --path . -- --verify --timer   # scoring-rule cases
godot --headless --path . -- --verify --score    # engine: reactive/xmult/copycat/void
godot --headless --path . -- --verify --run      # run loop, payouts, boss, miser
godot --path . -- --verify --shop                 # buy / reroll / sell
godot --path . -- --verify --game                 # full flow → screenshot
# regenerate the 12 joker .tres from code
godot --headless --path . --script res://tools/gen_jokers.gd
# web export
godot --headless --path . --export-release "Web"  # → build/web/
```

Screenshots land in `%APPDATA%/Godot/app_userdata/Balatro Count-Down/verify/`.

## Status — done vs. next

**Done & verified (desktop + web):** the timer/scoring core, the juicy reveal,
the 12-card Joker engine, the run → boss → shop loop, the economy, the CRT/foil
look, and an interactive web export.

**Next (defined but not in this slice):** antes beyond 1 (curve is coded, not
walked); the other bosses (Mirror is coded, unscheduled; Rusher/Flinch are
round-side and stubbed); precision tiers 2–3 (supported by the code, only reached
ante 3+); a bundled chunky pixel font (using the engine default for now); drag to
reorder the board; the full ~40-card set.
