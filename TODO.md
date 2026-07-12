# Avenger Sharks — TODO

## Gameplay

- Difficulty levels (fish themed, e.g. Minnow upwards)
- Chill mode

## Power-ups & Progression

- More power-up suggestions:
  - Bouncing shots
  - Exploding shots
  - Piercing shots
  - Flame thrower
  - Cursed power-ups :D
- Keep count of fish rescued — use as currency in a pre-game shop:
  - Start with more health
  - Other playable characters

## User Experience

### Boss wave

- Randomly determine boss characteristics
- Energy bar (which zooms up to max when it first appears on the HUD)
- Klaxon and flashing alert

### The Director

- Controls how the game works
- What makes up a wave?
  - Which enemy types are eligible to spawn
	- Define a "minimum" wave for mob types (where appropriate)
  - Balance of enemies / maximum number allowed on screen at a time
	- Define propensity — e.g. `1.0` = standard weighting, `0.5` = half weighting
  - How many spawn at a time
  - How enemies are batched
  - Speed between spawns
  - Speed multiplier for enemies (?)

### Second player character

- Bob the Fish?
  - Faster move speed
  - Unlocks with X total collected fish (currency)

### Statistics

- Ability for the user to reset

### Enemy types

- An enemy that charges the player
- An enemy that lays an egg / drops acid / does something else bad
- Static turret (probably a new Scene to support):
  - Rotate during physics
  - After a random timer: charge animation + second timer
  - Fire a solid laser — persist for a third timer
  - Damages the player
  - Return to turret
  - Statuses: `ROTATING`, `CHARGING`, `FIRING`
  - Turret could fire a homing missile instead

### Wave progression

- Choice of which level
- Palette swaps (different areas) — could use shaders here
- Dialogues (try not to boil the ocean)

### Graphics

- Shaders for water effects
- More vibrant shader for enemy death

### Persistent storage

- Implement encryption

### Steam

- Achievements:
  - Beat a wave
  - Beat 5 waves
  - Beat 10 waves
- Leaderboard support (high scores)

## General Development

- CI/CD pipeline

## Jack's Ideas

- Hammerhead shark:
  - Hits one time to lose one life
  - If it loses two more, then it is done but can take three lives in one hit

---

# Code Health & Optimisation

Findings from a codebase review. Ordered by impact within each section. Line
references are approximate and may drift as the code changes.

## Performance (highest impact — this is a bullet-hell with per-enemy A*)

- [ ] **Enemy A* re-pathing cadence.** Every chasing enemy recomputes a full
  `AStarGrid2D` path to the player every ~0.1s (`Constants.gd`
  `ENEMY_CHASE_REORIENT_MIN/MAX`, used in `Enemy.gd` CHASE). With enemy counts
  scaling as `wave * 25`, this is likely the single biggest CPU cost at high
  waves. Options:
  - Stagger recompute times per-enemy (they are all synced to 0.1 today)
  - Raise the interval to 0.2–0.3s
  - Cache the player's tilemap cell and only re-path when it changes
  - Cap the number of enemies allowed to re-path per frame (pathfinding budget)
  - Consider a shared **flow-field** toward the single player target — scales
	far better than N independent A* searches
- [ ] **`get_tree().get_nodes_in_group(...)` in hot paths.** Allocates a new
  array every call. Hotspots: `Player.gd` grenade targeting (scans all enemies
  every fire), mini-shark iteration; `Enemy.gd` FISH mode (scans all fish every
  reorient); `Fish.gd`. Cache the array where iterated repeatedly in one
  function.
- [ ] **Deep `get_parent().get_node("...")` chains resolved every frame.**
  `Enemy.gd` and `Player.gd` re-resolve `Arena`, `Player`, `HUD` many times per
  physics tick, sometimes chained three deep. Cache as `@onready` references.
  Also improves readability.
- [ ] **Projectile churn.** Shark sprays and enemy attacks are `CharacterBody2D`
  nodes `instantiate()`/`queue_free()`d constantly (Fish Frenzy spawns 32 sprays
  repeatedly). Pool them; consider `Area2D` instead of physics bodies for simple
  bullets.
- [ ] **`set_modulate(lerp(...))` runs on every enemy every frame**
  (`Enemy.gd`) even when already white. Guard it so it stops once white.

## Correctness / Bugs

- [x] **Typo `"PACIFST"`** in `Main.gd` (`if game_mode == "PACIFST"`) — missing
  the `I`. Compared against `"PACIFIST"` everywhere else, so this branch's
  `update_fish_left_display()` never fires.
- [ ] **`left_to_spawn = total_enemies + 5000  # Padding`** in `TheDirector.gd`.
  The wave loop drains 5000+ of padding building `spawn_N` batches, generating a
  large number of reinforcement definitions and inflating `wave_design`.
  Document or remove the magic number.
- [x] **Empty-group `randi_range`** in `Main.gd` `_on_wave_time_left_timer_timeout`
  — `randi_range(0, size()-1)` errors when the enemy group is empty when the
  timer fires. Guard for the empty case.
- [ ] **Infinite `while !valid_spawn` loops** for placement (`Main.gd` spawn
  helpers, `Arena.gd` `add_obstacle`). If the arena fills with obstacles these
  never terminate. Add a max-attempts fallback.
- [ ] **`Arena.gd` extends `TileMap`**, deprecated since Godot 4.3 in favour of
  `TileMapLayer`. Works on 4.7 but is migration debt.

## Refactoring / Maintainability

- [ ] **Break up `Main.gd` (~1300 lines).** The `game_status` state machine,
  spawning, scoring, menu routing, and Steam achievements all live in one node.
  Extract a **Spawner** (the `spawn_*` family), a **ScoreManager**, and a
  **UI/menu router**. Highest-value structural change.
- [ ] **Replace polling with signals/timer callbacks.** `Main._process` and
  `Player._physics_process` poll `$SomeTimer.time_left == 0` every frame across
  many branches. Godot `Timer.timeout` signals already exist (already used for
  `ArtilleryTimer` — it's inconsistent). Removes per-frame branching.
- [x] **Data-drive the power-up / upgrade `match` statements.** `Player.gd` had
  near-identical `match powerup` blocks in the chest pickup and `power_up_tick`
  each recomputing `speed`/`fire_delay`/`spray_size`/`grenade_delay`. Now driven
  by `constants.POWERUP_STAT_FORMULAS` via a single `apply_powerup_level(powerup)`
  helper; MINI SHARK / SCATTER SPRAY remain explicit. Also fixed a latent bug
  where `grenade_delay` was not reset in `prepare_for_new_game`.
- [x] **Dead/confusing code in `grouped_enemy_death()`** (`Enemy.gd`) — removed
  the repeated stray comment blocks and rewrote with a doc comment explaining
  the snake head/body re-parenting algorithm. Behaviour preserved.
- [ ] **Frequent stat writes.** `Storage.increase_stat("player","shots_fired",1)`
  fires every shot. In-memory only (saved later) so cheap-ish, but consider
  batching.

## Quick Wins

- [x] Fix the `"PACIFST"` typo.
- [x] Add `@onready` refs for `arena` / `player` / `hud` in Enemy/Player and
  replace the `get_parent().get_node(...)` chains.
- [ ] Stagger/raise the enemy re-path interval — likely a noticeable FPS gain at
  high waves from one constant change.
- [x] Guard the empty-group `randi_range` in the wave-end key drop.
