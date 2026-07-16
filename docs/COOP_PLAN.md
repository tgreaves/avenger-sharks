# Couch Co-op — Architecture & Implementation Plan

Status (all play-tested, single-player unchanged throughout):

- **Phase 1 — DONE.** Decoupled the single-player reference.
- **Phase 2a — DONE.** Input via `PlayerInput`; player-count menu selector.
- **Phase 2b — DONE.** Second player spawns with synchronised swim-in,
  device-scoped input, and a distinct tint. Includes the shared zoom-to-fit
  camera (Phase 3, merged in).
- **Phase 3 — DONE** (merged into 2b).
- **Phase 5 — DONE.** Co-op death (downed shark sits out, respawns next wave,
  game over only when all down), per-player scoring + dual-score HUD,
  per-player fish/frenzy, and shared wave-end key hunt / escape.
- **Phase 7 — DONE.** CPU-controlled player 2.
- **Phase 4 — DONE.** Per-player powerup bar (4a) and simultaneous per-player
  upgrade screen (4b): vertical column UI with a manual cursor (keys/controller
  + mouse), per-player offers/summary, CPU deliberation + confirm flash.
- **Phase 6 — IN PROGRESS.** Device-setup / join screen, per-mode high scores,
  and the single-player-assumption audit DONE. Only two-gamepad hardware
  verification remains. (Player-selectable colours dropped from scope.)

The full two-player feature is complete and play-tested. Only Phase 6 (menu/
config polish + the two-gamepad hardware check) remains; it does not block play.

Resequenced after the 2b audit — see "Re-plan: entanglement finding".

Design decisions locked in (see "Design choices" below), effort concentrated in
Phases 1–2. Each phase is independently testable; Phase 1 ships with zero
behaviour change.

## Goal

Add local two-player ("couch co-op") support while keeping single-player working
unchanged.

## Design choices

| Decision | Choice | Rationale |
|---|---|---|
| Camera | **Shared zoom-to-fit** | One camera tracks the midpoint of living players and zooms out as they separate (capped at a max distance). Best fit for a fast single-arena shooter; split-screen adds large cost for little benefit here. |
| Death / revive | **Per-shark energy; out until next wave; game over when both down** | The game has no "lives" — just a per-shark energy bar (death = energy hits zero). A downed shark sits out the rest of the wave and respawns at full energy next wave; game over only when *both* sharks are down in the same wave. No lives pool (corrected from the original plan). See Phase 5. |
| Players | **1–2, selectable at main menu** | Single-player must remain the default and behave exactly as today. |

## Why this is hard today

`$Player` is a hardcoded singleton: instanced directly in `Main.tscn` and
referenced ~77 times across the scripts (54 in `Main.gd` alone) as `$Player`,
`get_node("Player")`, or `== "Player"` collision checks. It drives input, the
camera, enemy AI targeting, the HUD, scoring, and the entire wave-end sequence.

The core of the work is turning the single `$Player` into a `players[]`
collection. The shared-camera + shared-lives choices deliberately sidestep the
hardest parts (per-player score reconciliation, revive state, split rendering).

## Single-player assumptions baked into the code

1. `$Player` is a scene-instanced singleton (`Main.tscn`), referenced ~77×.
2. The camera lives on the player (`$Player/Camera2D`) — one camera, one shark.
3. Input is global (`Input.get_vector("left","right",...)`) and haptics are
   hardcoded to device `0` (`Input.start_joy_vibration(0, ...)`).
4. Enemies target a single `get_node("Player")` in every AI mode.
5. The wave-end sequence (`is_player_alive()`, `is_player_cheating_death()`,
   hunt-key → hunt-exit → go-through-door) is a linear single-actor state machine.
6. HUD shows one energy bar, one fish bar, one upgrade picker.

---

## Phase 1 — Decouple the single player reference

Pure refactor, **no behaviour change**; shippable on its own.
**Status: code-complete, pending play-test.**

### As-built approach

Rather than a separate `PlayerManager` node, the source of truth is a Godot
**group** plus three accessor helpers on `Main`:

- Players join the `"players"` group in `Player._ready()` (code-only — no scene
  diff, and idempotent via an `is_in_group` guard).
- `Main.get_players()` → the group array.
- `Main.get_primary_player()` → the canonical player for **stat reads**
  (upgrades, powerups). Currently still resolves via `get_node("Player")` — the
  one deliberate remaining name dependency, replaced in Phase 2.
- `Main.get_nearest_player(pos)` → nearest by distance for **positional
  targeting**. With one player it always returns that player.

### The key distinction that emerged

External `Player` references split into two kinds, and they need *different*
replacements — this wasn't obvious until doing the work:

- **Positional targeting** (who does this entity chase / flee / aim at / snap
  to?) → `get_nearest_player(global_position)`. Converting these makes the
  behaviour genuinely co-op-correct, not just co-op-safe.
- **Non-positional stat reads** (`power_pellet_enabled`, `upgrades`,
  `spray_size`, `max_powerup_levels`) → `get_primary_player()`. These have no
  meaningful "nearest"; in Phase 2, projectile stat reads (e.g. `spray_size`)
  should instead come from the *firing* player, threaded through at spawn.

### What was actually converted (10 sites, 8 files)

- Positional → `get_nearest_player`: Enemy CHASE / RUN_AWAY / attack-aim, Fish
  magnet, Item magnet, Artillery chase, Key follow.
- Stat reads → `get_primary_player`: Enemy (`power_pellet_enabled`, `upgrades`,
  via the cached `@onready var player`), HUD ×4, Dinosaur, SharkSpray.
- Collision identity → `is_in_group("players")`: the Enemy body-collision check
  (`== "Player"`) — this is the one that genuinely *breaks* in co-op, since two
  sibling nodes cannot share the name "Player".
- Artillery `_on_body_entered` now calls `player_hit()` on the entering `body`
  directly instead of looking up "Player" — more correct and co-op-ready.

### Gotchas found while doing it

- **`Enemy.gd` `@onready var player`** is used for *both* kinds. Kept it as the
  primary-player stat reference and converted only the positional sites at their
  point of use, so it no longer caches a single positional target forever.
- **Artillery shake/reset must target the same player.** `shake()` and
  `shake_reset()` fire at different moments; caching the shaken player in a
  `shaken_player` var avoids resetting the wrong camera once there are two.
- **`$Player...` false positives.** `Player.gd` "matches" like
  `$PlayerExplosionTimer` and `$PlayerHitGracePeriodTimer` are child *timer*
  nodes, not the player node — do not touch them.

### Deliberately deferred to Phase 2

- **`Main.gd`'s ~54 direct `$Player.` lifecycle calls** (spawn, camera, energy,
  menu wiring) were left as-is. These are `Main` operating *the local player*;
  converting them to N-player loops is Phase 2 and would be high-churn /
  high-regression-risk with zero Phase-1 benefit.
- Replacing `get_primary_player()`'s internal `get_node("Player")` with true
  multi-player resolution.

### Verification

Single-player must be indistinguishable from before. Play-tested and confirmed
unchanged. Full headless project load is clean (no script/parse errors). Areas
exercised: enemy chase/flee (incl. power pellet), enemy ranged attacks, fish/item
magnet upgrade pull, artillery chase + screen shake + hit, and the wave-end
key-follow → hunt-exit sequence.

## Phase 2 — Multiple player instances & device-scoped input

The sharp edge of the whole feature. Split into 2a (input routing) and 2b
(spawning), because doing the work revealed 2b is entangled with the camera
(Phase 3) — see "Re-plan: entanglement finding" below.

### Phase 2a — Route input through PlayerInput — DONE

- `PlayerInput` promoted to `Scripts/PlayerInput.gd`; every input read in
  `Player.gd` goes through a per-player `input` instance. Runs in `ANY` mode, so
  single-player is unchanged. Haptics use a per-player `haptics_device` (still
  0 for now). Play-tested; committed.
- Also added: `player_count` main-menu selector (1/2), a menu toggle only —
  nothing consumes it yet.

### Phase 2b — Spawn the second player — NOT STARTED (blocked, see below)

- Spawn N players rather than relying on the scene-instanced one; give each a
  per-player start offset (`initial_player_position`).
- Assign devices and switch each player's `input` to a `SPECIFIC` instance;
  set `haptics_device` per player.
- **Player 2 must be visually distinct.** Apply a colour filter/tint to the P2
  shark sprite (e.g. `modulate` or a shader). Watch for interactions with
  existing modulate usage — the shark already recolours for power-pellet
  ("blood thirsty" red) and damage flashes, so the P2 tint must compose with,
  not be clobbered by, those.

### Re-plan: entanglement finding (before writing 2b)

Auditing the ~40 `$Player.` lifecycle calls in `Main.gd` for 2b surfaced that
spawning a second player is **not** cleanly separable from later phases:

- **Camera is a child of `Player`** (`Player.tscn`). Two players ⇒ two cameras
  fighting. Spawning P2 therefore *hard-requires* the shared camera (Phase 3);
  there is no sensible "spawn P2 but keep the player-mounted camera" interim.
- **Energy bar, fish bar, and aiming line live on the Player node**, not the
  HUD — so these duplicate correctly for free when a second Player is spawned.
  Good: less Phase 4 work than the original plan assumed.
- **Powerup bar + upgrade-choice UI live in the shared HUD** and read a single
  player. These can lag as "P1-only" without blocking a playable two-shark
  game — so Phase 4 does *not* block a first playable co-op build.

**Resequencing decision:** merge Phase 3 (shared camera) into 2b, because P2
cannot be framed without it. Phase 4 (shared-HUD powerup/upgrade duplication)
stays deferred — the first playable co-op build ships with P1-only powerup/
upgrade UI, which is an acceptable rough edge. New order below.

### Input-device spike — DONE (validated)

A throwaway spike (`Spikes/PlayerInput.gd`, `Spikes/input_spike.tscn`)
validated the input model. Confirmed by play-test: 1-player any-device works,
and 2-player keyboard+gamepad partitions cleanly. Two-gamepad config is built
and pending only a second controller (hardware) to confirm.

The validated model, to fold into the real `Player.gd`:

- **Two modes, not one:**
  - `ANY` (1-player) delegates to the global `Input.*` calls, which honour the
	project's `device":-1` ("any device") action bindings — so keyboard/mouse
	AND controller drive the one player simultaneously. **This is today's
	behaviour and must be preserved.**
  - `SPECIFIC` (2-player) filters per device. Godot's global
    `Input.is_action_pressed()` cannot filter by device once bindings use
    `device":-1`, so this mode tracks action state from `_input(event)` using
    `event.get_device()` + `event.is_action_pressed/get_action_strength`.
- **Keyboard/mouse need a sentinel device id** (`KEYBOARD_DEVICE`) to be
  distinguished from gamepad 0. Not needed for a two-gamepad pairing (devices
  0 and 1 are already distinct), which is therefore the simpler case.
- **"Fire" is two actions**, not one: `shark_fire` (controller) and
  `shark_fire_mouse` (mouse). The per-player input must route both (spike's
  `is_firing()` helper).

Still open (Phase 2 / Phase 6):

- Two-gamepad no-bleed check with real hardware (arriving — then verify).
- Device-id stability across (re)connection — do pads reliably enumerate 0, 1?
- P1/P2 physical assignment UX (keyboard+pad vs pad+pad) — a Phase 6 menu
  decision; the plumbing supports any assignment.

The spike files under `Spikes/` are throwaway and not wired into the game.

## Phase 3 — Shared zoom-to-fit camera (MERGED INTO 2b)

Merged into 2b: P2 cannot be framed without the shared camera, so this is done
as part of spawning the second player rather than as a later standalone phase.
Details retained here for reference.

### Behaviour spec (locked)

- **Position:** follows the midpoint of all *living* players, lerped smoothly
  (no snapping).
- **Zoom:** zoom-to-fit the players' bounding box plus a margin, but **capped**
  at a maximum zoom-out so sharks/enemies stay readable. Past the cap, the
  trailing player drifts toward the screen edge — acceptable in this single
  bounded arena. (Chosen over "always fit both", which makes sprites too small.)
- **Clamp:** camera stays within the arena limits (never shows past the
  playfield).
- **Screen shake:** shared — one camera, so any shake (artillery, fish frenzy)
  is felt by both players.
- **1-player:** same rig, unchanged. One living player ⇒ midpoint is that
  player and the bounding box is a point ⇒ zoom rests at the 1P default. The
  wave-1 intro zoom tween is preserved by driving the shared camera's zoom.
- **Tuning constants** (in `Constants.gd`, tune by feel after playtest): default
  (min-separation) zoom = today's framing; max zoom-out cap; player margin;
  position and zoom lerp speeds.

### Implementation notes

- Remove `Camera2D` from `Player.tscn`; add a **`CoopCamera`** on `Main`/`Arena`.
- Each frame: center on the midpoint of living players; set `zoom` from their
  bounding-box diagonal, clamped between a min (players together / single player)
  and a max separation. Lerp for smoothing.
- Preserve the wave-1 zoom-in intro tween (currently `$Player/Camera2D`).
- Move screen-shake (`shake()`) from the player camera to the shared camera.
- Single-player uses the same rig (fixed zoom, follows one shark) — one camera
  path to maintain.

## Phase 4 — HUD for two players — DONE

As-built:
- **4a (powerup bar):** per-player. Player 1's bar re-anchored bottom-left;
  player 2 gets a runtime clone bottom-right. `HUD.gd` powerup methods take the
  player and drive that shark's bar.
- **4b (upgrade screen):** simultaneous per-player picking. Godot's single-focus
  button system can't serve two independent cursors, so the screen was rebuilt
  as a vertical column with a **manual** per-player cursor (up/down + mouse
  hover; fire or click to confirm — one consistent highlight, no focus/hover
  split). Each player gets its own column (P1 left / P2 right), its own offered
  upgrades, and its own upgrade summary. CPU "deliberates" then auto-picks; a
  confirm flash plays before the wave advances. The old focus-memory pause logic
  was removed. Rows are fixed-height + top-aligned for cross-column alignment.
- Decision resolved: **independent picks, simultaneous** (not shared, not
  turn-based). Full detail in `docs/PHASE_4B_UPGRADE_PLAN.md`.

Original design notes (retained for reference):

Note (from the 2b audit): energy bar, fish-frenzy bar, and aiming line already
live on the **Player** node, so they duplicate for free when P2 spawns — they
are NOT part of this phase. This phase is only the shared-HUD elements below.

- **Per-player, but currently in the shared HUD** (the real work): powerup bar
  and upgrade-choice / upgrade-summary UI, which today read a single player.
  The first playable co-op build ships these as P1-only; this phase makes them
  per-player (e.g. a `PlayerHUD` sub-scene per player, anchored left/right).
- **Shared** (single, no change): score, high score, wave/time, boss health.
- Between-wave upgrade screen: decide independent picks (two pickers) vs one
  shared pick. Independent is truer to the roguelite feel but doubles the UI and
  focus-management work — the pause/focus-memory logic in `Main.gd` assumes one
  picker.

## Phase 5 — Wave lifecycle & co-op death — DONE

Built as three sub-slices (all play-tested):
- **5.1** — co-op death: downed shark hidden for the wave, `revive_for_new_wave()`
  at next wave start, `game_over()` gated on `are_all_players_dead()`. Also fixed
  a camera zoom-out at wave-end (camera now frames *visible* players, so a lone
  survivor keeps single-player zoom).
- **5.2** — projectile ownership threaded through the kill path; per-shark
  `player_score`/`player_score_multiplier`; dual-score HUD (P1 left, TIME centre,
  P2 right / HIGH SCORE hidden in 2P-human; CPU + 1P keep one score).
- **2a** — per-player `fish_collected`, own bar + own FISH FRENZY; fish score
  credits the collector; collected fish fly to the collector's HUD label
  (converted screen→world so they track at any camera zoom/pan).
- **5.3** — shared wave-end: any-living-player gating (fixed a soft-lock when P1
  died), both sharks hunt the key, single-holder carries it and opens the door,
  the other **follows the holder** and both **escape together** (holder exits
  first, then followers; the screen fade + cleanup are owned by Main and fire
  once the last shark is through). 5.3a (safe) and 5.3b (escape-together) were
  done in one pass.

Original design notes (retained for reference):

**Death model corrected (there is no "lives" mechanic in the game).** The game
uses a **per-shark energy bar**; death = energy hits zero (sudden, once, unless
the one-shot CHEAT DEATH upgrade revives at 75%). `player_hit()` reduces energy;
at `<= 0` the shark goes `EXPLODING` → `player_died.emit()` → `game_over()`. The
original "shared lives pool" idea is **dropped** — it was a mechanic the game
never had.

Co-op death rule (locked):

- **Out until next wave.** When a shark's energy hits zero it becomes inert for
  the rest of the wave (its existing explosion → dead state). It respawns at
  full energy at the next wave start (reusing the wave-start spawn loop that
  already iterates all players).
- **Game over only when BOTH sharks are down in the same wave.** So a single
  death no longer ends the game in 2-player. Today's immediate-game-over path is
  gated behind an "all players dead" check.
- CHEAT DEATH still works per shark (fires before death is finalised).
- No lives counter, no new HUD element — game-over is derived from energy state.

Wave-end sequence:

- The wave-end "hunt key → hunt exit → go through door" sequence (`Player.gd`
  state machine + `Main.gd` signals) is single-actor today. Simplest rule:
  **wave ends when the key is collected by any player**; both sharks then exit
  (or the survivor does).
- P2's death/scoring/key/upgrade signals (deferred in 2b) are wired up here:
  `player_died` → check "all dead" before `game_over()`; `player_got_fish` →
  scores for whichever shark; etc.
- `is_player_alive()` / `is_player_cheating_death()` become "any player…"
  aggregates; add an "all players dead" helper for the game-over gate.
- Score stays shared (already global in `Main`) — no per-player reconciliation.

## Phase 6 — Menu, config, polish — TODO (the only remaining phase)

Everything here is refinement / configurability, not core mechanics (those are
all done). Nothing blocks playing. The items are largely independent — do any
subset in any order.

**Done already:**
- Main-menu player-count toggle (1 / 2 / 2-CPU 3-way cycle), reusing the
  `game_mode` toggle pattern.
- **Device-setup / lobby screen (was item 1) — DONE.** `Scenes/SetupScreen.tscn`
  + `Scripts/SetupScreen.gd`, instanced in `Main.tscn`; new `SETUP_SCREEN` game
  status. Shown after START only for **2P-human** (1P and 2P-CPU start
  directly). **Press-to-join / drop-in:** each unclaimed device (keyboard/mouse
  or a gamepad) presses confirm (A / Enter / Space / left-click) to take the
  next free slot in join order (P1 then P2); back (B / Esc) leaves a slot, or
  cancels to the main menu if none claimed. Confirm with both slots filled
  starts the game. The chosen devices feed `Main.player_devices`, which
  `assign_player_devices()` now reads instead of the old hard-coded pairing
  (keyboard-slot haptics map to gamepad 0 via `_haptics_device_for()`). The
  keyboard slot renders as "KEYBOARD + MOUSE"; columns are top-aligned with a
  fixed-height status box so headings don't shift when a device is claimed.
  Colour picking was dropped from scope (kept the fixed `PLAYER_1/2_TINT`).
- **Separate high scores per mode (was item 4) — DONE.** Three boards, keyed by
  mode in `Main.high_score_key()`: `high_score` (1P), `high_score_2p` (two
  humans), `high_score_2p_cpu` (CPU partner). `high_score()` reads the current
  mode's value (safe `0` default, so old save files need no migration);
  `update_high_score()` writes the matching key. The HUD/menu HIGH SCORE shows
  the current mode and refreshes live as the player-count toggle is cycled
  (`update_player_count_label()`). Storage seeds all three keys.
- **Single-player-assumption audit (was item 2) — DONE.** Swept the systems that
  still assumed one shark and fixed six (all co-op-only; 1P behaviour unchanged
  since the single player is always both "nearest/random living" and the whole
  "any low" set):
  - **Spray size** (`SharkSpray._ready`) read `get_primary_player().spray_size`,
	so P2's BIG SPRAY never enlarged its own spray. Now reads
	`owner_player.spray_size`; `owner_player` is set *before* `add_child` at all
	four spawn sites (else `_ready` runs before it's assigned).
  - **Dinosaur rampage** (`Dinosaur.go_on_a_rampage`) used P1's DOMINANT DINO
	level; the eating shark is now passed through (`go_on_a_rampage(self)`).
  - **Artillery** drops (`_on_artillery_timer`) always centred on P1; now target
	a random living shark via new `get_random_living_player()` (the chase already
	used `get_nearest_player`).
  - **Low-energy tension music** was P1-only (P2's signals unconnected, shared
    `pitch_scale`). Now recomputes from *any* living shark being low
	(`update_low_energy_music()`), P2's signals are wired, and it's re-evaluated
    on death (a downed shark leaves the living set without emitting).
  - **Power-pellet music** (`end_shark_attack`, shared `SharkAttackMusic`) was
	stopped by whichever shark's pellet ended first; now only stops once no shark
	is still power-pelleted.
  - **CIRCLE_SURROUND_PLAYER** spawn placement encircled P1; now encircles a
	random living shark.
  - Left as-is (correct): the wave-start camera snap to `$Player.position`
	(both sharks spawn together and `CoopCamera` takes over immediately).

**Remaining items:**

1. **Two-gamepad hardware verification** (quick; needs a second controller).
   The two-gamepad pairing (P1 = pad 0, P2 = pad 1) has never been tested on
   real hardware — it shares the validated `SPECIFIC` `PlayerInput` code path,
   so it is expected to work but is unverified. The setup screen (now done)
   already supports claiming two pads. The input model itself was proven via the
   spike (`Spikes/`).

Player-selectable shark colours were considered and **removed from scope** — the
game keeps the fixed `PLAYER_1_TINT` / `PLAYER_2_TINT`.

**Suggested sequencing:** only the two-gamepad hardware verification (item 1)
remains, once the second controller is available.

## Phase 7 — CPU-controlled player 2 (also a testing aid) — DONE

All three slices complete and play-tested. Lets 2-player mode be tested solo,
stress-tests the co-op systems, and is a feature in its own right.

As-built notes:
- `AiInput extends PlayerInput`; `PlayerInput.update(owner, delta)` hook ticked
  from `Player._physics_process`. The device version leaves it empty.
- Cautious behaviour ladder: surge-dodge (danger) → keep-distance (spacing band
  with enter/exit **hysteresis** to stop boundary twitch) → opportunistic fish
  (short radius, suppressed while any enemy is within engage range) → follow
  human. Aim/fire at nearest living enemy layers on top; fish frenzy auto-fires.
- Long-range moves (seek fish / follow) route through the arena A* grid (path
  cached, recomputed every few frames); reactive dodge/retreat stay straight-line.
- All tuning values are constants at the top of `Scripts/AiInput.gd`.
- Still subject to the Phase 5 gaps: the CPU cannot yet score its fish or die.

**Key enabler:** `Player.get_input()` reads everything through the
`PlayerInput` abstraction, so an AI is just a `PlayerInput` subclass that
computes the move/aim/button intent from the game world instead of a device.
Player.gd barely changes — the AI shark inherits scatter spray, mini-sharks,
grenades, fire-rate, powerups, etc. for free.

**Decisions (locked):**
- Menu: the player-count toggle becomes a 3-way cycle — `1 → 2 → 2 (CPU)`.
- Scope: built within today's P2 limits — the CPU moves/aims/fires/frenzies now,
  but its fish collection won't score and it can't die until Phase 5. Same gaps
  as human P2 today; full autonomy arrives with Phase 5.

**Slices:**
- **A — skeleton + wiring.** `AiInput` (extends `PlayerInput`) that just follows
  the human player; 3-way menu cycle; assign it to P2 when CPU is selected.
  Proves the seam.
- **B — combat.** Aim + fire at nearest living enemy; trigger fish frenzy when
  available.
- **C — smarts.** Fish-seeking, swim-surge dodging, keep-distance, tuning.

Implementation note: `Player._physics_process` needs to tick the AI each frame
(before `get_input()` reads it) — an "update" hook on `PlayerInput` that the AI
overrides and the device version leaves empty.

---

## Effort & sequencing

- **Phases 1–2 are the real cost** (decoupling + input). Phase 1 is done via the
  `"players"` group + `Main` accessors (not a separate `PlayerManager` node);
  once device input exists, Phases 3–5 are additive.
- Each phase is independently testable; **Phase 1 ships with zero behaviour
  change**, so risk is incremental rather than big-bang.
- Recommend a dedicated `feature/coop` branch (off a `v1.5.0` line), since this
  is larger than the incremental fixes.

## Do these first

1. **Profile A* pathfinding — then optimise if the numbers say so.** *Not* a hard
   blocker (see below), but the right thing to sequence before Phase 1.
2. **Input-device spike** — a 30-minute throwaway to lock down P1/P2 assignment
   for mixed keyboard/gamepad play.

### On the A* re-pathing optimisation

Earlier this was framed as "mandatory groundwork". Revised, honest position:
**profile it first; optimise only if warranted.**

What the code does today (`Constants.gd`, `Enemy.gd` CHASE):

- `ENEMY_CHASE_REORIENT_MIN/MAX = 0.1s` → each chasing enemy recomputes a full
  `AStarGrid2D` path ~10×/second.
- Grid is 65×42 ≈ 2730 cells. Enemy count scales ~`wave × 25`.
- Worst case at ~wave 6 (~50 chasers) ≈ 500 full grid searches/second — but not
  every enemy is in CHASE at once, so the real number is lower.

Caveats: **this has not been profiled.** We don't know the actual frame cost on
target hardware, or the wave counts real players reach. It may already be fine,
or it may tank late waves — this is structural reasoning, not measurement.

Why it is *not* a hard blocker for co-op:

- Phase 1 (decoupling `$Player` → `players[]`) is a pure refactor that functions
  correctly regardless of A* cost. Co-op could be built first and optimised later.

Why it is still the right thing to do *first*:

- It is already an approved code-health TODO item.
- It is cheap and low-risk relative to co-op.
- Pathfinding is far easier to reason about and tune with **one** player before
  adding nearest-of-two-players target selection on top. Optimising after co-op
  means debugging two hard things at once.

Co-op-specific pressure (why co-op removes the headroom to ignore it):

- Target selection gets more expensive per enemy — nearest-of-two comparison, and
  the "nearest" flips more often as players separate, defeating any
  "only re-path when the target cell changes" caching.
- Co-op usually means tuning waves *larger*, not smaller.

Recommended approach:

1. Force a high enemy count (the `DEV_SPAWN_ENEMY_COUNT` flag already exists) and
   measure `_physics_process` / A* cost with the Godot profiler.
2. If comfortably within budget at realistic co-op wave sizes → skip for now,
   build co-op, revisit if late waves stutter.
3. If marginal → do the cheap version first: stagger the per-enemy 0.1s timers so
   they don't all recompute on the same frames, and/or raise the interval to
   ~0.2s. Likely halves the spikes for near-zero risk. (Fuller options — cached
   target cell, per-frame path budget, shared flow-field — are in the code-health
   TODO.)

## Biggest risks

1. Enemy AI target selection combined with the A* cadence — pending profiling
   (see above); may or may not need work.
2. Input device assignment for mixed keyboard/gamepad couch play.
3. The upgrade-screen focus/pause logic, which is intricate and single-picker.
