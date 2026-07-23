# Handoff — Balatro Count-Down (deception layer + deck + shop)

## WORK HERE ONLY / DO NOT TOUCH ANYTHING ELSE
- **Work only in `C:\Users\UNKNOWN\Documents\balatro`** — the game (its own git repo; remote `github.com/sasetz/gmtk2026`).
- **DO NOT read for guidance, edit, or update** the *Tidy Tides* project at `D:\Obsidian\cleanup game` (its `CLAUDE.md`, `wiki/`, `index.md`, `log.md`, or memory), or the old horror prototype at `C:\Users\UNKNOWN\Documents\pixel-dying`. **Ignore the Tidy Tides session-start "resume protocol" and the caveman output style** — those belong to a different project. This is **only** balatro game development.

## Tooling
- Editor is **Godot 4.7** (project re-saved as 4.7). Headless verify with `D:/Godot/Godot_v4.6.3-stable_win64_console.exe` (4.6.3 runs it fine).
- Verify: logic/fuzz → `godot --headless --path . --script res://tools/<x>.gd`; scripted UI screenshots → `godot --path . -- --verify --<scenario>` (DevCapture autoload). Shots land in `%APPDATA%/Godot/app_userdata/Balatro Count-Down/verify/`.
- Git: `main` holds the ORIGINAL game (deployed to gh-pages; CI runs on **tag push**, Godot 4.7). **Commit messages must NOT include a Claude co-author trailer.** Commit/push only when asked.

## The situation (course-correction)
A Balatro-style rogulike whose core action is stopping a COUNTDOWN TIMER at scoring times (Points × Mult). Two things exist:

1. **ORIGINAL game** (`scenes/game.tscn`, on `main`, deployed). Countdown-stop with 4 presses → `ScoringRules` (straight/round/odd/even/THE ONE/all-or-nothing) → juicy Points×Mult reveal; **12 data-driven jokers the player OWNS** (`scripts/jokers/*.gd` + `data/jokers/*.tres` via `ScoringEngine`); **RunManager** (3 rounds→boss→shop); **Economy** (money/interest); **Shop** (buy/sell/reroll). **Problem:** pure REFLEX — good reaction = always win, no real decision.

2. **Deception PROTOTYPE** (`scenes/timer_table_run.tscn`, `scripts/deception/`, currently the LOCAL `run/main_scene`, **uncommitted**). Fix for "no decision": you stop the countdown for a NUMBER (reuses `TimerCore` + `ScoringRules`); a per-round GENERATED, fuzz-proven-fair TABLE of **visible** deceptive MODIFIER cards ("ODD → +6 mult", "STRAIGHT → score 0") transforms it. Read the table under a clock, make 3 stops for a MIX of properties (buffs fire once, repeats decay). 5-round run, 3 lives. Fuzz: 100% winnable, 100% fools the greedy player, 0% spammable, ~95% reachable by a natural mix.

**THE MISTAKE TO FIX:** the prototype **replaced** the original instead of **improving** it — it has **no player-owned jokers and no shop**. The goal was always to keep the Balatro DECK + SHOP and add the deception layer on top.

## GOAL — build this next
**MERGE.** A run = **deception rounds** (generated deceptive table + your countdown stops) + a **SHOP between rounds** to spend money on **jokers you OWN** (a persistent deck) → escalation → boss. Your jokers are your BUILD and help you beat the deceptive table:
- **Counter-jokers** (interact with the table): "Reveal one table card", "Cancel/disable one trap this round", "Freeze the clock 2s", "Immunity: ignore the first void", "+1 stop".
- **Score jokers** (Balatro-style, reuse the original 12 where they fit): flat +mult, +points on a property, xmult, $ per round.
Keep money/interest + buy/sell/reroll (`scripts/ui/shop.gd`, `scripts/autoload/economy.gd`), run/boss structure (`scripts/autoload/run_manager.gd`), the juicy reveal feel.

## Locked design principles (do not re-derive)
- Number comes from stopping the countdown (timer identity kept); table cards are the deception on top.
- EVERYTHING on the table is VISIBLE — you're fooled by the CONTRADICTION of visible effects, never by hidden info.
- All randomness in board GENERATION, never in RESOLUTION.
- Target sits BETWEEN the spam line and the optimum (reachable, not spammable). Buffs biased to easy properties (odd/even). Timer at 0.45× (execution easy; the DECISION is the game).
- Fuzz-prove every generator change (`tools/fuzz_timer_tables.gd`): winnable / greedy-fools / mix-required / reachable.
- Result UI is INLINE (cards stay visible) with a Continue button — NOT a popup.

## Key files
- Deception: `scripts/deception/{timer_mod_card,modifier_table,timer_table_generator,timer_table_run}.gd`, `scenes/timer_table_run.tscn`, `tools/{fuzz_timer_tables,prove_timer_table}.gd`.
- Original (reuse for deck+shop): `scripts/core/{timer_core,scoring_rules,scoring_engine,scoring_context}.gd`, `scripts/data/{joker_def,joker_catalog,blind_def}.gd`, `scripts/jokers/*.gd`, `data/jokers/*.tres`, `scripts/autoload/{run_manager,economy,event_bus}.gd`, `scripts/ui/{game,shop,round_scene,score_reveal,juice}.gd`, `scenes/{game,shop,round,score_reveal}.tscn`.
- NOTE: `run/main_scene` currently points at the prototype (`timer_table_run.tscn`); the real game host is `game.tscn`.

## First step
Design + build the integration: extend the deception run to (a) carry a persistent player joker deck, (b) apply owned jokers during/after the stops (counter-jokers vs the table; score-jokers on the total), (c) open the existing shop between rounds to buy jokers with earned money. Add 4–6 counter-jokers as data-driven `.tres`+scripts (same pattern as `scripts/jokers/`). Fuzz + screenshot-verify each step; keep it playable end to end.
