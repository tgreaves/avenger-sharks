# Phase 4b — Per-player upgrade screen (simultaneous 2P picking)

Goal: at wave end, each player picks their **own** upgrade from their **own**
three choices, **at the same time** (no turn-taking). The wave proceeds once
**both** have confirmed.

## Why the current approach can't be reused as-is

The existing upgrade screen uses Godot's **Control focus system**: one
`UpgradeChoiceContainer` with three `Choice/Button` nodes, navigated by the
engine's global `ui_up`/`ui_down`/`ui_accept` and `grab_focus()`. Godot tracks
**exactly one focused Control per viewport**, and the built-in `ui_*` navigation
drives whicheverthat is. So two players cannot each hold an independent
highlight and navigate simultaneously — they would fight over the single focus.

**We keep the `Button` nodes for layout/appearance, but stop using Godot focus
to navigate them.** Instead each player gets an independent "highlighted index"
driven by their own device via the `PlayerInput` abstraction, and we render the
highlight ourselves.

## Current flow (single player), for reference

1. `Main.upgrade_screen()` builds the 3 eligible upgrades into
   `upgrade_one_index / two / three`, fills the `Choice1/2/3` TextureRect / Title
   / Description from `$Player.upgrades`, `grab_focus()`es Choice2, fades the
   container in, sets `game_status = UPGRADE_WAITING_FOR_CHOICE`.
2. Choice buttons' `pressed` → `HUD._on_upgrade_button_pressed(n)` →
   `upgrade_button_pressed(n)` → (scene-wired HUD→Player) →
   `Player._on_hud_upgrade_button_pressed(n)`.
3. That maps `n`→ the chosen upgrade index, bumps `upgrades[choice][0]`, applies
   per-upgrade side effects (MAGNET / ARMOUR / FISH AFFINITY / MORE POWER /
   HEAL ME…), calls `hud.update_upgrade_summary()`, emits
   `player_made_upgrade_choice`.
4. `Main._on_player_player_made_upgrade_choice()` hides the container, sets
   `game_status = PREPARE_FOR_WAVE`.
5. Pause during the screen stashes which button had focus
   (`upgrade_focus_memory_*`) and restores it on unpause.

Key facts that help:
- Each player's `upgrades` dict is **already per-player**.
- The offered choices are currently **shared** (one set of three).
- `_on_hud_upgrade_button_pressed` already lives on **Player**, so "apply my
  choice to me" is per-player already — it's the *offering* and *navigation*
  that are single-player.

## Design

### Offered choices — per player

`upgrade_screen()` currently computes one eligible list from `$Player`. Make it
compute a set **per player** (each player's own eligible upgrades, shuffled,
3 chosen). Store on each `Player` (e.g. `offered_upgrades: Array[String]` of
length 3) rather than the single `upgrade_one/two/three_index` on Main.

1-player keeps working: player 1 gets a set; the loop just has one player.

### UI — unified vertical column layout (LOCKED)

Both modes use the **same vertical column** primitive — three choices stacked
top → bottom — so there is one layout and one navigation axis everywhere:

- **1-player:** a single column, **centered**. (This changes 1P from the old
  horizontal 3-across row — an accepted, visible change.)
- **2-player:** two columns — player 1 **left**, player 2 **right** (matching
  the score / powerup side convention).

Build one `UpgradeColumn` (a `VBoxContainer` of three `Choice` sub-panels:
TextureRect / Title / Description, reused from the current design). Instance it
once (centered) for 1P, twice (left/right) for 2P. The authored horizontal
`UpgradeChoiceContainer` is replaced by this.

- Highlight is **manual**, not Godot focus and not Button hover: one visual
  (scale bump / modulate / a highlight `Panel` behind the choice) on the
  player's currently-highlighted `Choice`, driven by our own cursor index.
  Disable the Buttons' focus (`focus_mode = FOCUS_NONE`) so the engine never
  draws its own focus box; we never call `grab_focus()`.

### Navigation & confirm — per player, keys/controller AND mouse

All input paths feed the **same** per-player highlight, so there is exactly one
consistent highlight (this fixes the current focus-box vs mouse-hover split):
- A per-player `upgrade_cursor` (0..2) and `upgrade_confirmed` (bool).
- **Up/down** (that player's move input, edge-triggered) moves the cursor —
  single axis, all modes (unified column). Reuse `PlayerInput`.
- **Mouse** (only for the mouse-owning player, `PlayerInput.uses_mouse()`):
  hovering a choice **sets** the cursor to that choice's index (same highlight
  as pressing down to it); it does not use Button hover styling. In 2P the mouse
  therefore only affects player 1's column.
- **Confirm** = that player's fire button (`is_just_pressed("shark_fire")`), or
  a **mouse click** on a choice (mouse-owning player). Both lock in whatever is
  currently highlighted.
- On confirm: apply via the existing `_on_hud_upgrade_button_pressed`-style path
  for **that** player, lock in their choice (show a "READY" state on their
  panel), set `upgrade_confirmed = true`.
- The CPU player auto-picks (e.g. random or first eligible) after a short delay
  so it doesn't stall the wave.

Where does the per-frame navigation live? Options:
- On `Main` while `game_status == UPGRADE_WAITING_FOR_CHOICE`, iterating players
  and reading each `player.input`. (Central, matches how Main polls state.)
- Or a small `UpgradeChooser` helper. Central-on-Main is simplest first.

### Completion gate

Track confirmations; when **all players** have `upgrade_confirmed`, hide the
panels and go to `PREPARE_FOR_WAVE` (replacing the single
`player_made_upgrade_choice` trigger). A player who has confirmed shows a locked
"READY — waiting for other player" state.

### Pause interaction

The `upgrade_focus_memory_*` logic exists only to restore Godot button focus
after a pause. With manual cursors there is no engine focus to restore — the
`upgrade_cursor` values simply persist across pause (they are plain vars).
So this logic is **removed**, simplifying `handle_pause_input()` and the unpause
path. (Net simplification.)

## Slices

The unified vertical layout means 4b-2 already builds the exact column + cursor
2P needs, so 4b-3 is mostly "add a second column + gate".

- **4b-1 — Per-player offered upgrades.** Move the offer computation +
  `offered_upgrades` onto Player; still using the existing UI, sourced from
  `player.offered_upgrades`. Verify 1P unchanged.
- **4b-2 — Vertical column + manual cursor (1P).** Replace the horizontal
  Button/focus UI with the centered vertical `UpgradeColumn`, per-player cursor,
  manual highlight, up/down navigation + fire-to-confirm via `PlayerInput`.
  Remove the focus-memory pause logic. Verify 1P.
- **4b-3 — Second column + simultaneous 2P.** Instance a second column (P1 left,
  P2 right), per-player cursors, both-confirmed gate, CPU auto-pick. Verify 2P.

Slicing this way keeps 1-player working and testable at every step, and defers
the second column / gating to last.

## Open questions (resolve before 4b-3)

1. **Panel layout — RESOLVED.** Unified vertical column: 1P centered, 2P two
   columns (P1 left / P2 right). Single up/down navigation axis everywhere.
2. **Navigation control** — move-to-highlight (up/down) + fire-to-confirm
   (recommended, reuses existing inputs) vs aim-to-choose.
3. **CPU pick** — random eligible, or a simple priority? Random is fine for a
   helper; it just shouldn't stall.
4. **1-player feel / mouse — RESOLVED.** 1P adopts the vertical cursor UI. The
   **mouse is kept** as a co-equal input for the mouse-owning player: hover sets
   the highlight, click confirms — feeding the same single cursor as the keys,
   so both are consistent. (No Godot focus box, no Button hover styling.)
4. **1-player feel** — unifying on the custom cursor UI means 1P loses Godot
   button focus + mouse-click selection. Acceptable? (If mouse-click must stay
   for 1P, we keep Buttons clickable in parallel with the cursor.)
