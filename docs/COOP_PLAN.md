# Couch Co-op — Architecture & Implementation Plan

Status: **Phase 1 complete** (play-tested — single-player unchanged).
Phases 2–6 not started.

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
| Death / revive | **Shared lives / co-op game over** | One shared life pool; game over when it is empty. Reuses most of the existing `game_over()` flow — changes *when* it fires, not the flow. Simplest scoring model (score is already global). |
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

The sharp edge of the whole feature.

- Input is global today. Add a `device_id` to each player and route all input
  reads through a small `PlayerInput` wrapper that resolves the existing action
  names (`left`, `shoot_left`, `fish_frenzy`, …) against the assigned device.
  Assign e.g. P1 = keyboard+mouse or gamepad 0, P2 = gamepad 1.
- Spawn N players at wave start rather than relying on the scene-instanced one;
  give each a per-player start offset (`initial_player_position`).
- Replace hardcoded haptics device `0` with the player's `device_id`.
- Recommend a small standalone **input-device spike** first — Godot's mixed
  keyboard/gamepad device handling for couch play is fiddly.

## Phase 3 — Shared zoom-to-fit camera

- Remove `Camera2D` from `Player.tscn`; add a **`CoopCamera`** on `Main`/`Arena`.
- Each frame: center on the midpoint of living players; set `zoom` from their
  bounding-box diagonal, clamped between a min (players together / single player)
  and a max separation. Lerp for smoothing.
- Preserve the wave-1 zoom-in intro tween (currently `$Player/Camera2D`).
- Move screen-shake (`shake()`) from the player camera to the shared camera.
- Single-player uses the same rig (fixed zoom, follows one shark) — one camera
  path to maintain.

## Phase 4 — HUD for two players

- **Per-player** (duplicate): energy bar, fish-frenzy bar, powerup bar, upgrade
  summary. Cleanest as a `PlayerHUD` sub-scene instantiated once per player,
  bound to that player, anchored bottom-left / bottom-right.
- **Shared** (single): score, high score, wave/time, boss health.
- Between-wave upgrade screen: decide independent picks (two pickers) vs one
  shared pick. Independent is truer to the roguelite feel but doubles the UI and
  focus-management work — the pause/focus-memory logic in `Main.gd` assumes one
  picker.

## Phase 5 — Wave lifecycle & shared lives

- The wave-end "hunt key → hunt exit → go through door" sequence (`Player.gd`
  state machine + `Main.gd` signals) is single-actor. Simplest rule: **wave ends
  when the key is collected by any player**; both sharks then exit (or the
  survivor does).
- Add a **shared lives pool** on `Main`: a death decrements it; respawn at next
  wave if lives remain; **game over when it hits zero**. Reuses the existing
  `game_over()` path.
- `is_player_alive()` / `is_player_cheating_death()` become "any player…"
  aggregates.
- Score stays shared (already global in `Main`) — no per-player reconciliation.

## Phase 6 — Menu, config, polish

- Main-menu player-count toggle (reuse the existing `game_mode` toggle pattern).
- "Press A to join" drop-in, or fixed 2P start — TBD.
- Audit single-player assumptions in: Fish Frenzy, power-pellet music (global —
  fine), dinosaur rampage, artillery targeting (`$Player.position` — needs a
  target choice among players).

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
