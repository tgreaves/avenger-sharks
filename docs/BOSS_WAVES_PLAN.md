# Boss Waves — Design & Implementation Plan

Status:

- **Phase 0 — Existing scaffolding.** A disabled skeleton was already in the
  code (see "What exists today").
- **Phase 1 — DONE.** The boss entity + a complete, winnable boss wave. Making
  Phase 1 testable pulled most of **Phase 2** forward with it (win condition,
  reward, no-timer race, "BOSS" display, key-drop handoff) — see the Phase 1
  "As-built" notes.
- **Phase 2 — MOSTLY DONE** (folded into Phase 1). Remaining tail only: co-op
  death behaviour during a boss fight is untested (should already work via the
  existing rule); confirm during Phase 3+ co-op testing.
- **Phase 3 — DONE.** Boss attacks / behaviour, reworked into a **confined
  bullet-hell fight** (see "Combat model" below). The boss is rooted at the top
  of a walled, one-screen room and threatens via a varied, weighted attack pool;
  contact damage applies. Health-threshold phases still deferred.
- **Phase 3.5 — DONE.** Random boss identity (any of the 7 enemy sprites), themed
  behaviour, plus a spawn-in (invulnerable while materialising). Director picks
  type + behaviour in `design_boss_wave()`.
- **Phase 4 — DONE.** Procedural adds: Director rolls a weighted intensity
  (none 55 / light 30 / heavy 15); when enabled, capped batches trickle in on the
  EnemySpawnTimer during the fight (bee boss themes its adds as a bee swarm).
  Adds don't gate completion — only boss HP does.
- **Phase 5 — DONE.** Trigger cadence (every 5th wave from wave 5), boss titles,
  health growth per encounter, and extensive combat/arena rework (below).
- **Difficulty & feel tuning (post-Phase 5).** A pass to make boss fights read as
  less easy and less "indecisive":
  - **Enrage phase (health-threshold).** Bosses **enrage at 25% HP** (tunable
    `BOSS_ENRAGE_HEALTH_FRACTION`), tightening attack cadence
    (×`BOSS_ENRAGE_CADENCE_MULTIPLIER` = 0.6) for the rest of the fight. Visual
    tell: the boss reddens (`BOSS_ENRAGE_TINT`, persisted between hit flashes via
    `_base_tint`) plus a one-shot scale flex. Base cadence also quickened
    (`BOSS_ATTACK_INTERVAL_BASE` 2.4→1.8, `..._MIN` 1.2→0.9).
  - **Charge attack** (new — CHASE_AIMED profiles: knight/rogue/bee). Halts +
    vibrates as a tell, then lunges at the nearest shark's position captured at
    lunge start (dodgeable by moving), passing THROUGH sharks (player layer masked
    out; contact damage applied manually) and stopping only at a wall. A sub-state
    machine (`CHARGE_TELEGRAPH`/`CHARGING`/`RECOVERING`) that suspends patrol +
    cadence, then returns to the telegraph anchor. All tunable via `BOSS_CHARGE_*`.
  - **Pacing rework.** Movement now sweeps the full arena width edge-to-edge,
    reversing ONLY at the bounds (removed the old `DriftTimer` random mid-travel
    flips that made it dither). New `BOSS_MOVEMENT_STYLE` toggle: `"pace"`
    (default) vs `"rooted"`. **OPEN DECISION** — pace vs rooted not yet settled;
    shipping with the toggle at `"pace"`. Rooted is now a viable option: a rooted
    boss **compensates** for not chasing — its attack cadence tightens
    (`BOSS_ROOTED_CADENCE_MULTIPLIER`) and its wave is guaranteed at least
    `BOSS_ROOTED_MIN_ADDS_INTENSITY` of adds (both applied only while rooted).
  - **Charge wind-up lengthened.** `BOSS_CHARGE_TELEGRAPH_TIME` 0.6 → 0.8s so the
    lunge is a touch more readable/dodgeable.
  - **Health bump.** `BOSS_BASE_HEALTH` 60 → 72 (fights were ending a little fast).
  - **Upgrade screen after a boss.** HEAL ME is excluded from the offered upgrades
    on the screen straight after a boss wave (boss defeat already full-heals both
    sharks, so it would be wasted). Falls back to HEAL ME only if fewer than three
    other upgrades remain unmaxed. See `Player.choose_offered_upgrades()`.
  - **Wall-stuck fix.** Large bosses (snake 14×, bee 16×) reached a side wall
    before their centre crossed the patrol turn-point and pinned there; now also
    reverse on wall contact.
  - **Unified per-type collision.** `collision_offset` now lives in
    `ENEMY_SETTINGS` in **sprite-relative texture px** (same space as
    `sprite_offset`), scaled by the sprite scale in both `Enemy.gd` and
    `Boss.gd` — so ONE value fits the normal enemy and the (larger) boss. Boss
    still gets its own `collision_scale` via `BOSS_TYPE_SETTINGS` where the body
    fills the frame differently. Used to fix the **bee** (small high body → raised,
    tighter capsule) and the **necromancer** (low/right body → shifted on, and a
    taller boss capsule to span head-to-legs). Retires the long-standing "per-type
    collision-capsule tuning" deferral for these two; other types stay on the
    proportional default. Normal-enemy hitboxes for bee/necromancer improve too.
  - **Boss name display.** The top-of-screen TIME slot shows a plain `"BOSS"`
    (long titles didn't fit the narrow slot); the fun name is announced big during
    the swim-in intro instead (`spawn_text` = `"<NAME> IS HERE!"`).
  - **Dev aid.** `DEV_FORCE_BOSS_WAVE_TYPE` pins the boss to one type for testing
    (empty = random). MUST be reset to `""` (and `DEV_FORCE_BOSS_WAVE` to `false`)
    for real play.
  - **Still open:** snake boss renders as a single sprite (a snake is a node
    chain; the boss borrows one sprite) — decision pending (exclude from pool /
    accept / build a segmented snake boss). Further "easy" levers if needed: a
    second enrage threshold, concurrent attacks, denying the bottom-edge safe
    zone, damping the Fish Frenzy burst.

**Combat model (as-built, reworked this session):**
- The boss fight happens in a **confined one-screen room** walled off with the
  arena's own perimeter tiles (`Arena.build_boss_walls`), so the player can't
  kite into empty scrollable space. The **camera locks static** on the room
  centre at the standard zoom. Sharks **swim in from the bottom** through a
  2-tile door that **closes behind them**; on defeat the room's **top door
  opens** (only when the key-holder reaches it, like a normal wave) and the exit
  is relocated there so the wave ends promptly.
- The boss is **rooted to the top** and patrols left/right; danger comes from
  **attack intensity + adds**, not chasing. Attacks are a weighted pool per
  profile: rotating spiral, twin counter-spiral, shotgun fan, wall-with-gap, and
  a **curving spiral** (projectiles that actually arc outward via decaying
  curve). Cadence speeds up on later bosses.
- **Spawn-in:** the boss materialises invulnerable (like normal enemies) and
  only becomes vulnerable + starts attacking when the wave goes live, so it
  can't be pre-damaged.
- **No obstacles** and **no star/power-pellet** spawn on boss waves.
- Only one artillery strike is active at a time.

Each phase was independently testable. The confined-arena combat model went
through heavy playtest iteration (camera lock, room sizing to the 2560×1440
viewport, wall tiles, door mechanics, exit relocation).

## Goal

Add periodic **boss waves** that break the normal survive-the-timer rhythm with
a single large boss enemy the players must destroy. TheDirector procedurally
decides the specifics — including whether the fight also spawns **adds** (normal
enemies) — so boss waves stay varied rather than scripted-identical.

Must work in both single-player and the (now-complete) two-player co-op: damage
attribution per shark, both sharks fighting one boss, shared camera framing.

## Design choices

### Locked in

| Decision | Choice | Rationale |
|---|---|---|
| Boss form | **Single big boss** | One large enemy with a health pool. The `BossHealthBar` already exists for exactly this. |
| Boss identity | **Buffed existing enemy first** | Start with a scaled-up existing enemy (e.g. giant necromancer) with a huge health pool, reusing its existing attack; swap in bespoke art/behaviour later. Fastest path to a playable loop. |
| Win condition | **Deplete boss health** | Boss wave ends when `boss_health` reaches 0 — a damage race, not a survival timer. |
| Timer | **None (pure damage race)** | No countdown and no fail-on-time; players take as long as they need. (A soft enrage timer could be revisited later but is out of scope.) |
| Cadence | **Every Nth wave** | Tunable constant (e.g. `BOSS_WAVE_INTERVAL`), first no earlier than some wave X. Replaces the placeholder `BOSS_WAVE_MULTIPLIER = 1000000`. |
| Reward | **Large score bonus + health restore** | Big points on defeat, plus sharks heal (breathing room) going into the next wave. No guaranteed upgrade. |
| Adds | **Procedural, Director-decided** | Some boss fights spawn accompanying normal enemies ("adds"); some don't. Director rolls **intensity** per boss wave: often none, sometimes light, occasionally heavier (weighted toward none/light). |
| Adds spawning | **Periodic trickle, capped** | When enabled, adds spawn in small batches over time (reusing the reinforcements timer) with a low on-screen cap. Adds never gate completion — only boss HP does. |
| Co-op — boss | **Shared boss, per-shark damage credit** | Both sharks damage one boss; kill/score credit uses the existing `owner_player` / `scoring_player_for()` plumbing. |
| Co-op — death | **Waits out the fight** | A downed shark stays out for the whole boss fight and revives at the start of the next normal wave (existing co-op rule, unchanged). Game over only if both are down. |
| Co-op — scaling | **Boss health scales with player count** | Higher `boss_health` in 2-player (≈×1.75) since two sharks out-damage one. Keeps the fight meaningful in co-op. |

### Open — still to resolve during implementation

- **Boss health values & scaling curve.** Base `boss_health`, how it grows with
  wave number, and the exact 2-player multiplier (≈×1.75 starting point) — tune
  by feel in Phase 5.
- **Cadence numbers.** The interval N and the earliest boss wave X — tune in
  Phase 5. Add a DEV constant to force a boss wave for testing.
- **Which existing enemy** to buff into the first boss (necromancer is the
  leading candidate — it already has the spiral attack and highest health).
- **Health-restore amount** on boss defeat (full vs. partial).
- **Adds composition** when heavier intensity rolls (which enemy types, batch
  size, cap).

## What exists today (the disabled skeleton)

- **`TheDirector.gd`**
  - `design_wave()` — `if wave_number % BOSS_WAVE_MULTIPLIER == 0` → calls
    `design_boss_wave()` and **returns early**, so a boss wave skips all normal
    enemy/spawn/timer generation.
  - `design_boss_wave(_wave_number)` — sets only three keys: `boss_wave = true`,
    `boss_health = 1000`, `spawn_text = "ALERT! BOSS DETECTED!"`. No enemy, no
    attacks, no adds, no timer.
- **`Main.gd`**
  - `wave_intro`/start (~line 611): `if wave_design.boss_wave → $HUD.boss_health_reveal()`
    **else** `spawn_enemy("start_spawn", ...)`. So on a boss wave **nothing
    spawns** — the arena is empty but for the players.
  - `BossHealthBar` hidden at game start (~line 401).
  - Normal wave-end path is `_on_wave_time_left_timer_timeout()` → drop key →
    `wave_end()`. A boss wave never starts that timer, so **there is currently no
    way for a boss wave to end** — it would hang.
- **`HUD.gd`**
  - `boss_health_reveal()` — animates `BossHealthBar` from 0 up to `boss_health`
    over 2s and shows it. `BossHealthBar` node exists in `HUD.tscn` (red fill).
  - Nothing decrements the bar; it is not wired to any entity.
- **`Constants.gd`**
  - `BOSS_WAVE_MULTIPLIER = 1000000` — placeholder; boss waves effectively never
    trigger. Also `spawn_text` is consumed by the normal wave-intro banner.

**Summary of gaps:** (1) no boss entity to fight, (2) no win condition / the
wave can't end, (3) no damage plumbing to the health bar, (4) trigger disabled,
(5) no attacks, (6) no adds, (7) co-op integration unverified.

---

## Phase 1 — The boss entity — DONE

Delivered *something to shoot* AND a complete winnable boss wave (most of the
original Phase 2 came along for the ride, because a boss you can't defeat isn't
testable).

### As-built

- **`Scripts/Boss.gd` + `Scenes/Boss.tscn`** — a single large boss, a buffed
  reskin of the necromancer sprite (run + death animations reused from the same
  sheet). Added to `enemyGroup` so the existing shark-spray / grenade collision
  and cleanup treat it like any other enemy body. Exposes `death(source,
  attacker)` (same signature as `Enemy.death`) so both projectile paths damage
  it with zero changes to those scripts.
- **Health pool:** `configure(health)` sets HP; each `death()` hit decrements by
  1, flashes the sprite, and emits `boss_damaged`. At 0 it emits `boss_defeated`,
  plays the death anim/sound, and frees via a StateTimer.
- **Scale is data-driven** (mirrors `ENEMY_SETTINGS`): `BOSS_SPRITE_SCALE` (7×),
  `BOSS_COLLISION_SCALE` (1.75× — the shared capsule fits the creature at sprite
  4× / collision 1×, so 7/4 = 1.75× keeps it proportional), and
  `BOSS_SPRITE_OFFSET` (lifts the low-in-frame art over the centred capsule, like
  the necromancer's `sprite_offset`). All applied in `Boss.configure()`.
- **Spawn:** `Main.spawn_boss()` instances the boss at `BOSS_SPAWN_POSITION`
  (upper-middle, clear of the swim-in lane), scales health ×1.75 in 2-player,
  and connects its signals. Called from `start_wave()`'s boss branch.
- **Damage → HUD:** `_on_boss_damaged` → `HUD.update_boss_health`. Reveal
  (`boss_health_reveal`) reads the spawned boss's actual (scaled) max health.
- **Drift:** gentle random drift + wall bounce so it isn't a static target. Real
  movement/attacks are Phase 3.

### Win condition + lifecycle (Phase 2 items folded in here)

- **Win = deplete health.** `_on_boss_defeated` awards `BOSS_DEFEAT_SCORE_BONUS`
  to the killing shark (`scoring_player_for`), full-heals all living sharks
  (+ `update_low_energy_music`), hides the health bar, drops the key at the
  boss's death position, and routes into the existing `wave_end()` — so the
  normal hunt-key → exit → upgrade flow runs.
- **No survival timer:** the boss branch skips `WaveTimeLeftTimer` and
  `EnemySpawnTimer`. TIME slot shows **"BOSS"** (`update_time_left_display`).
- **Intro banner:** `wave_intro` shows "WAVE N / ALERT! BOSS DETECTED!" with no
  "SURVIVE X SECONDS".
- **Director:** `design_boss_wave` sets safe defaults for the keys `start_wave`
  reads (obstacle_number, total_enemies=0, total_spawns=0, reinforcements=0), so
  it no longer faults on the missing normal-wave design. `DEV_FORCE_BOSS_WAVE`
  forces every wave to a boss wave for testing.
- **Cleanup:** boss leaves `enemyGroup` on death (so the wave-end `swim_escape`
  sweep skips it); `return_to_main_screen` nulls the ref and hides the bar.

### Phase 2 tail still open

- **Co-op death during a boss fight** is untested. It *should* work unchanged
  (downed shark waits out the fight, `are_all_players_dead()` gates game over,
  revive at next normal wave start), but hasn't been exercised — confirm during
  Phase 3+ co-op testing.

## Phase 3 — Boss attacks / behaviour — DONE (first pass)

Gave the boss a reason to be dangerous.

### As-built

- **Movement:** roams (random drift + wall bounce); danger comes from
  projectiles rather than chasing. (Chosen over a chase.)
- **Attacks** (reuse `EnemyAttackScene`, standard damage):
  - **Spiral** — a full ring of `BOSS_SPIRAL_PROJECTILE_COUNT` (20) shots every
    `BOSS_SPIRAL_INTERVAL` (3s), on its own `SpiralTimer`.
  - **Aimed volley** — a `BOSS_AIMED_PROJECTILE_COUNT` (3) shot fan across
    `BOSS_AIMED_SPREAD_DEGREES` at the nearest shark every `BOSS_AIMED_INTERVAL`
    (1.2s), on its own `AimedTimer`.
- **Contact damage:** ramming a shark calls `player_hit()` (which has its own
  grace period, so sustained contact doesn't drain every frame); still bounces
  off walls. Boss collision mask gained the player layer (bit 1) for this.
- **Co-op:** aimed volleys target `get_nearest_player`. Timers stop on death.
- All cadence/count/speed values are tunable constants.

### Deferred to a later phase (see "Random boss identity & varied behaviour")

- Health-threshold phase changes (faster / denser under 50% HP). **DONE** in the
  post-Phase 5 difficulty tuning — enrage at 25% HP tightens cadence.
- Per-wave variety in sprite and attack/movement style.

## Phase 3.5 — Random boss identity & varied behaviour — DONE

Keeps boss waves interesting by randomising both appearance and behaviour.

### As-built

- **Sprite/identity:** `design_boss_wave()` picks a random type from
  `BOSS_TYPE_SETTINGS` (all 7 enemy types). `Boss.configure()` borrows the
  shared enemy `SpriteFrames` (all types' run/death anims) from a throwaway
  `Enemy` instance and plays `<type>-run` / `<type>-death`.
- **Per-type scale:** enemy frames have different native sizes, so each type has
  its own `scale` in `BOSS_TYPE_SETTINGS` (small 32px knight/wizard/rogue/skeleton
  ~12×, bee ~10×, necromancer ~7×, snake ~14×). Collision scales proportionally
  from the necromancer-tuned capsule (`type_scale * 1.75/7`).
- **Behaviour themed to sprite** (`BOSS_TYPE_SETTINGS[type].behaviour`). Four
  profiles in `Boss.gd`:
  - `ROAM_SPIRAL` — drifts, fires spiral + aimed volleys (wizard).
  - `CHASE_AIMED` — pursues nearest shark, aimed volleys (knight/rogue/bee).
  - `STATIONARY_BULLETHELL` — holds position, denser/faster spiral
    (skeleton/snake).
  - `ARTILLERY_RAIN` — roams, aimed volleys + POLLUTION-STRIKE drops on a timer
    (necromancer), reusing `Main.spawn_artillery_strike()`.
- **Deferred:** health-threshold phase changes (open item from Phase 3) — now
  **DONE** (enrage at 25% HP, see the post-Phase 5 tuning note); per-type
  collision-capsule tuning remains (currently one capsule scaled proportionally).

## Phase 4 — Procedural adds — DONE

### As-built

- `design_boss_wave()` rolls a weighted `adds_intensity`
  (`BOSS_ADDS_INTENSITY_WEIGHTS`: none 55 / light 30 / heavy 15).
- If not `none`, `Main._start_boss_adds()` reads `BOSS_ADDS_SETTINGS`
  (cap / batch / interval per intensity) and starts the otherwise-unused
  `EnemySpawnTimer`. On boss waves that timer routes to
  `spawn_boss_adds_batch()`, which spawns up to `batch` enemies while under the
  on-screen `cap`, then reschedules.
- Adds don't gate completion — only boss HP does. They swim out with the normal
  wave-end sweep (they're in `enemyGroup`).
- The timer stops naturally on boss defeat (wave leaves `GAME_RUNNING`).

### Adds rework (post-Phase 5) — fired out, same type as the boss

- **Ejected from the boss.** Adds no longer appear at random arena positions
  (which, on a boss wave, could even land *outside* the sealed room). Each add
  now spawns from inside the boss (`spawn_boss_add_fired`) and is flung outward,
  the batch **fanned** across `BOSS_ADDS_FAN_SPREAD_DEGREES` centred on the aim
  at the nearest shark. It reuses the existing `SPAWN_OUTWARDS` AI mode: fly
  outward for `BOSS_ADDS_LAUNCH_TIME` (its own per-instance timer so the
  mini-skeleton default is untouched), then switch to `CHASE`. Adds are **live
  immediately** (`instant_spawn`) — shootable and dangerous during the launch.
- **Same kind as the boss.** Adds always match the boss's own type (bee queen →
  bees, skeleton lord → skeletons, …), pulled from `wave_design.boss_type`. This
  retired the per-type `adds_type` override (bee/skeleton) — now redundant.
- **Rooted compensation.** A rooted boss (see the movement note below) guarantees
  at least `BOSS_ROOTED_MIN_ADDS_INTENSITY` of adds even if the Director rolled
  fewer, so a stationary boss still pressures the sharks.
- **Snake caveat.** The snake is a grouped/segmented enemy, so a snake boss's
  adds spawn full snake chains and only the head segment obeys the launch. If it
  reads badly in play, map snake adds to a simpler type.

## Phase 5 — Trigger, polish, tuning — DONE

- **Cadence — DONE.** `BOSS_WAVE_INTERVAL`/`BOSS_WAVE_FIRST` (every 5th wave from
  wave 5) via `TheDirector.is_boss_wave()`; `DEV_FORCE_BOSS_WAVE` forces one.
- **Boss health scaling — DONE.** `BOSS_BASE_HEALTH` + `BOSS_HEALTH_WAVE_GROWTH`
  per boss encounter, ×`BOSS_HEALTH_2P_MULTIPLIER` (1.75) in 2-player.
- **HUD titles — DONE.** Random fun title per type (`BOSS_TYPE_SETTINGS[...].titles`).
  Announced during the swim-in ("<NAME> IS HERE!"); the top TIME slot shows "BOSS"
  (see the post-Phase 5 tuning note — long titles didn't fit the narrow slot).
- **Reward — DONE (Phase 1).** Score bonus + full heal on defeat.
- **Confined-arena combat rework — DONE.** See "Combat model" in the status
  header — this was the bulk of the session's work.

### Still deferred / future

- **Audio:** no dedicated boss music yet (deliberately deferred; hook is to swap
  `AudioStreamPlayerMusic` like power-pellet does with `SharkAttackMusic`).
- **Health-threshold phases — DONE** (post-Phase 5 tuning). Bosses enrage at 25%
  HP, tightening attack cadence for the rest of the fight; base cadence also
  quickened. Follow-up levers if still too easy: a second enrage threshold, a
  concurrent second attack per tick, denying the bottom-edge safe zone, and
  damping the Fish Frenzy burst (all noted, not built).
- **Co-op play-test:** the confined room, spawn-in, and wave-end have been
  tested in 1-player. Two-player boss fights (camera lock with two sharks, both
  swimming into the room, co-op death during the fight) are **untested** — the
  main open item before calling boss waves fully done.
- **Balance:** health values, attack cadence/density, and adds intensity are
  first-pass; tune after more play.

### Notes / gotchas found in testing

- Relocating the exit/markers into the boss room put extra `CharacterBody2D`s on
  the shared collision layer. All player projectiles (`SharkSpray`, `Grenade`,
  `EnemyAttack`) now guard their damage call with `has_method(...)` so a shot
  hitting a non-damageable body (exit marker, start marker, room wall/door) stops
  harmlessly instead of crashing.
- The necromancer boss capsule floated above the sprite until the boss reused
  each enemy type's tuned `sprite_offset` from `ENEMY_SETTINGS`.

## Attack-type backlog (ideas)

Candidate additions to the weighted attack pools to keep fights varied. Grouped
by implementation cost. Each "cheap" one is a new `BOSS_ATTACK_*` const, a
`_attack_*()` in `Boss.gd`, and a weight in `BOSS_ATTACK_POOLS`.

**Cheap — reuse `_fire_projectile` + the pool pattern**

- **Expanding rings / pulse.** Fire several full rings in quick succession, each
  ring's gap rotated a notch from the last, so the shark must keep sliding as the
  rings expand. (A timed burst of `_attack_rotating_spiral`.)
- **Falling curtain.** The boss sits up top, so rain vertical columns of shots
  with a moving gap that walks left↔right (the `WALL` attack turned vertical and
  repeated). Reads very differently from the aimed patterns.
- **Aimed burst-fire.** 3–4 quick `SHOTGUN` fans in a row, each re-aimed at the
  shark's current position — punishes standing still without being a wall.
- **Shockwave on charge impact.** When a `CHARGE` lunge slams a wall
  (`_begin_charge_recover`), emit a ring burst from the impact point, so the
  dodge-the-lunge moment also means "don't be by the wall it hits". Nearly free;
  ties two systems together (CHASE_AIMED profiles).

**Medium — small `EnemyAttack` extension (builds on `curve_rate`)**

- **Homing seekers — DONE.** `BOSS_ATTACK_HOMING`, in every profile's pool at a
  low weight. A short fan of colourful missiles (`Scenes/HomingSeeker.tscn`,
  `Scripts/HomingSeeker.gd`, using `Sprites/spaceMissiles_003.png`) that curve
  toward the nearest shark at a **capped turn rate** (`BOSS_SEEKER_TURN_RATE`, so
  juking dodges them), then **time out into a small ring burst**
  (`BOSS_SEEKER_LIFESPAN` → `_mini_explode`). Distinct missile sprite (rotated to
  face travel) so they read differently from the round fireball. Unlike other boss
  shots they are **shootable** — the seeker rides the enemy collision layer and
  exposes `death()`, so a shark's spray destroys it. **Any** death triggers the
  mini-explosion (timeout, ramming a shark, a wall, or being shot — guarded by
  `_exploded` so it fires once), so it's best shot from a distance. The wave-end
  sweep `queue_free`s it directly, bypassing the burst. Feel values are `BOSS_SEEKER_*`.
- **Bouncing shots.** Projectiles that ricochet off the sealed room's walls a
  few times before expiring — fills space unpredictably. Needs wall-reflection
  in `EnemyAttack`.

**Involved — new entity, higher impact**

- **Sweeping laser beam.** Telegraph a line, then fire a solid beam that sweeps
  the room. This is essentially the turret/laser already sketched in `TODO.md` —
  build once, reuse for a boss attack and a future turret enemy.
- **Mines / depth charges.** Drop stationary orbs that arm after a delay then pop
  into a small ring. The rogue's `EnemyTrap` is most of the tech already; thematic
  for the necromancer/skeleton.

## Co-op considerations (cross-cutting)

The two-player feature is complete; boss waves must respect it:

- **Damage credit** per shark via `owner_player` / `scoring_player_for()`.
- **Targeting** among players via `get_nearest_player` / `get_random_living_player`
  (never hard-coded `$Player`), consistent with the single-player-assumption
  audit already done.
- **Death rule** unchanged: downed shark sits out, game over only when all down.
- **Camera / shake** already shared via `CoopCamera`. NOTE: boss waves lock the
  camera static on the room — untested with two sharks (a shark could in theory
  move off the locked view; the room is one screenful so it should be fine).
- **Boss health scaling** higher in 2-player via `BOSS_HEALTH_2P_MULTIPLIER`
  (1.75). DONE.
