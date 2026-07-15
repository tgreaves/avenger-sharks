# Boss Waves — Design & Implementation Plan

Status:

- **Phase 0 — Existing scaffolding.** A disabled skeleton is already in the code
  (see "What exists today"). No boss can currently be fought.
- **Phase 1 — TODO.** The boss entity: a single large enemy with a health pool
  the sharks deplete.
- **Phase 2 — TODO.** Win/lose condition + wave lifecycle integration.
- **Phase 3 — TODO.** Boss attacks / behaviour.
- **Phase 4 — TODO.** Procedural adds (TheDirector decides if/when the fight is
  complicated by normal enemies).
- **Phase 5 — TODO.** Trigger cadence, HUD polish, audio, co-op framing.

Each phase is independently testable. Phase 1 gets *something to shoot*; Phase 2
makes it a real, completable wave; Phases 3–5 add depth and variety.

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

## Phase 1 — The boss entity

Get *something to shoot* that has health and dies.

- New `Boss` scene + script (or a buffed existing enemy per open decision 1),
  added to a `bossGroup` (and likely `enemyGroup` so existing shark-spray
  collision / scoring works with minimal change).
- `boss_health` drives an internal HP; taking a `death("PLAYER-SHOT", owner)`
  hit reduces HP instead of dying outright, and updates `BossHealthBar`.
- Spawn it at boss-wave start (replace the `boss_health_reveal()`-only branch in
  `Main.gd` with: reveal bar **and** spawn the boss, e.g. arena centre / away
  from the player entrance).
- No attacks yet — it can just sit or drift. Verify: bar reveals, shots lower
  it, both sharks' shots count (co-op), bar empties.

### Damage plumbing

- Reuse the co-op projectile ownership: `SharkSpray`/grenade already carry
  `owner_player`; the boss's hit handler credits score via
  `scoring_player_for(attacker)` on defeat.
- Update `BossHealthBar.value` on each hit (Main or HUD helper —
  `HUD.update_boss_health(current)`).

## Phase 2 — Win condition & wave lifecycle

Make a boss wave a real, completable wave.

- When boss HP hits 0: trigger the wave-end path. Simplest is to route into the
  existing `wave_end()` — drop the key on the boss's death position, then the
  normal hunt-key → exit → upgrade flow runs (co-op: both sharks escape).
- The boss-wave branch must **not** start `WaveTimeLeftTimer` — there is no
  survival timer (pure damage race).
- **Reward on defeat:** award a large score bonus (via `scoring_player_for()`
  attribution / split as appropriate) and restore shark health (amount TBD —
  see open items) before the next wave.
- HUD: hide `BossHealthBar` on wave end / game over / return to menu (audit the
  existing visibility toggles).
- **Co-op death:** reuse the existing rule unchanged — a downed shark waits out
  the whole boss fight and revives at the next normal wave start;
  `are_all_players_dead()` still gates game over.
- Time display: a boss wave has no countdown, so hide TIME or show "BOSS" in its
  place. Audit `update_time_left_display()`.

## Phase 3 — Boss attacks / behaviour

Give the boss a reason to be dangerous.

- One or more attack patterns (reuse existing enemy attack scenes where
  possible: spiral like the necromancer/dinosaur, artillery-style, charges).
- Movement: chase nearest shark (`get_nearest_player`) or a pattern.
- Phases (optional): behaviour shifts as `boss_health` crosses thresholds
  (e.g. faster / new attack under 50%).
- Co-op: attacks should target among players (use `get_nearest_player` /
  `get_random_living_player`, consistent with the single-player-assumption audit
  already done for artillery/dino).

## Phase 4 — Procedural adds

TheDirector decides, per boss wave, how much to complicate the fight.

- In `design_boss_wave()`: roll an **intensity** — `none` / `light` / `heavy`,
  weighted toward none/light — rather than a simple on/off. Store it in
  `wave_design` (e.g. `adds_intensity`). If not `none`, author the add
  composition (eligible types, batch size, on-screen cap, cadence) using the
  existing spawn-ratio machinery from `design_wave()`.
- `Main.gd` boss-wave branch: if adds are enabled, run a **periodic trickle** —
  small batches on the reinforcements timer, capped at a low on-screen count —
  alongside the boss, reusing `spawn_enemy`. Adds do **not** gate wave
  completion; only boss HP does.
- The intensity roll is the "keep it interesting" lever: many boss waves have no
  adds, some a light trickle, a few a heavier mix.

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
