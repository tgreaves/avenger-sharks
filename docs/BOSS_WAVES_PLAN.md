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
- **Phase 3 — DONE (first pass).** Boss attacks / behaviour: roams + spiral +
  aimed volleys + contact damage. Health-threshold phases deferred.
- **Phase 3.5 — DONE.** Random boss identity (any of the 7 enemy sprites) and a
  behaviour profile themed to that sprite. Four profiles: roam+spiral,
  chase+aimed, stationary bullet-hell, artillery-rain. Director picks type +
  behaviour in `design_boss_wave()`.
- **Phase 4 — DONE.** Procedural adds: Director rolls a weighted intensity
  (none 55 / light 30 / heavy 15); when enabled, capped batches of random
  enemies trickle in on the (otherwise-unused) EnemySpawnTimer during the fight.
  Adds don't gate completion — only boss HP does.
- **Phase 5 — TODO.** Trigger cadence (replace the placeholder multiplier), HUD
  polish, audio, co-op camera framing, and balance tuning.

Each phase is independently testable. Phase 1 got *something to shoot* and a
full spawn → deplete → win loop; Phase 3 makes it a real fight; Phases 4–5 add
variety and polish.

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

- Health-threshold phase changes (faster / denser under 50% HP).
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
- **Deferred:** health-threshold phase changes (open item from Phase 3), and
  per-type collision-capsule tuning (currently one capsule scaled proportionally).

## Phase 4 — Procedural adds — DONE

### As-built

- `design_boss_wave()` rolls a weighted `adds_intensity`
  (`BOSS_ADDS_INTENSITY_WEIGHTS`: none 55 / light 30 / heavy 15).
- If not `none`, `Main._start_boss_adds()` reads `BOSS_ADDS_SETTINGS`
  (cap / batch / interval per intensity) and starts the otherwise-unused
  `EnemySpawnTimer`. On boss waves that timer routes to
  `spawn_boss_adds_batch()`, which spawns up to `batch` random enemies via
  `spawn_enemy_random_position` while under the on-screen `cap`, then reschedules.
- Adds don't gate completion — only boss HP does. They swim out with the normal
  wave-end sweep (they're in `enemyGroup`).
- The timer stops naturally on boss defeat (wave leaves `GAME_RUNNING`).

## Phase 5 — Trigger, polish, tuning

- **Cadence:** replace `BOSS_WAVE_MULTIPLIER = 1000000` with a real rule
  (`BOSS_WAVE_INTERVAL`, every Nth wave, first no earlier than wave X). Add a DEV
  constant to force a boss wave for testing.
- **Boss health scaling:** base `boss_health`, growth with wave number, and the
  2-player multiplier (≈×1.75 starting point). Tune by feel.
- **HUD:** boss name/title over the bar, reveal flourish, defeat animation.
- **Audio:** boss music (swap `AudioStreamPlayerMusic` like power-pellet does
  with `SharkAttackMusic`), defeat sting.
- **Camera:** verify the shared co-op camera frames boss + both sharks sensibly
  (the boss may be large; check zoom cap).
- **Reward tuning:** score-bonus amount and health-restore amount (full vs.
  partial) on defeat.

## Co-op considerations (cross-cutting)

The two-player feature is complete; boss waves must respect it:

- **Damage credit** per shark via `owner_player` / `scoring_player_for()`.
- **Targeting** among players via `get_nearest_player` / `get_random_living_player`
  (never hard-coded `$Player`), consistent with the single-player-assumption
  audit already done.
- **Death rule** unchanged: downed shark sits out, game over only when all down.
- **Camera / shake** already shared via `CoopCamera`.
- **Boss health scaling** likely higher in 2-player (open decision, Phase 5).
