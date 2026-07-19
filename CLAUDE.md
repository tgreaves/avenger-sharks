# Avenger Sharks — working notes for Claude

2D twin-stick shooter in **Godot 4.7** (GL Compatibility renderer). Ships on
Steam, itch.io, and web. Author: Tristan Greaves.

## Verifying changes (no CI — validate locally)

Godot binary: `D:\Program Files\Godot\Godot_v4.7-stable_win64.exe`

- **Single-file parse check** (fast):
  `godot --headless --check-only --script Scripts/<File>.gd`
  ⚠️ This does **not** register autoloads, so it reports false
  `Identifier not found: Storage / SteamClient / constants / TheDirector`
  for the singletons. Those are expected noise, not real errors.
- **Whole-project compile** (authoritative, loads autoloads):
  `godot --headless --editor --quit-after 200` then grep the output for
  `SCRIPT ERROR|Parse Error|Compile Error`. Clean = no matches.
- There is no headless way to actually *play* a wave; gameplay/feel changes
  need a human play-test in the editor.

## Environment gotchas

- If the Godot **editor is open**, the GDExtension DLLs
  (`addons/godot-git-plugin`, `addons/godotsteam`) are file-locked, so a
  headless run logs `Can't open GDExtension dynamic library` / `Cannot get
  class 'GitPlugin'`. These are lock artifacts, **not** code problems — ignore.
- The `~lib*.dll` files that appear untracked in `addons/*/win64/` are the
  editor's copy-lock temp files. **Do not commit them.**
- Indentation is **tabs** (GDScript). Match it exactly or the parse fails.

## Architecture

- **Autoloads** (`project.godot`): `constants` (→ `Scripts/Constants.gd`, note
  the lowercase name used everywhere), `Storage`, `SteamClient`, `Logging`,
  `TheDirector`. One script per entity/system in `Scripts/`, matching scene in
  `Scenes/`.
- **All tunables live in `Constants.gd`.** Prefer adding/adjusting a constant
  there over hard-coding numbers in logic.
- **`Main.gd` (~1300 lines) is the god object**: `game_status` state machine,
  spawning, scoring, menu routing, Steam achievements. Flagged for extraction
  in `TODO.md` but not yet split. Reaching into child nodes via `$Node/Child`
  from Main is the established idiom.
- **`TheDirector.gd`** procedurally designs each wave (`wave_design` dict);
  `Main` reads keys off it (`boss_wave`, `adds_intensity`, `boss_type`, …).

## Co-op (two-player) rules — respect in any gameplay code

- Never hard-code `$Player`. Use `get_players()`, `get_nearest_player(pos)`,
  `get_random_living_player()`. Damage/score credit flows through
  `owner_player` / `scoring_player_for()`.
- Downed shark sits out the rest of the wave; game over only when all are down.

## Boss waves (current focus area)

- `Boss.gd` + `Boss.tscn`; boss is added to `enemyGroup` so shark spray/grenade
  collision treats it like any enemy. It exposes an enemy-compatible API
  (`death`, `swim_escape`, `is_enemy_alive`, …) so group-iterating systems work.
- Boss fights happen in a **confined walled room** with a **static-locked
  camera**; sharks swim in from the bottom.
- Adds trickle in on `EnemySpawnTimer` (routed to `spawn_boss_adds_batch()` on
  boss waves). Adds are ejected **from inside the boss**, fanned toward a shark,
  using the `SPAWN_OUTWARDS` AI mode (launch outward → `CHASE`).
- **DEV flags in `Constants.gd`** (`DEV_FORCE_BOSS_WAVE`,
  `DEV_FORCE_BOSS_WAVE_TYPE`) force/pin boss waves for testing and **must be
  reset before release**.
- Design + status: `docs/BOSS_WAVES_PLAN.md`. Keep it and `CHANGELOG.md` in sync
  when boss behaviour changes (established commit convention).

## Docs

`docs/BOSS_WAVES_PLAN.md`, `docs/COOP_PLAN.md`,
`docs/PHASE_4B_UPGRADE_PLAN.md`, plus `CHANGELOG.md` and `TODO.md` (the latter
also holds a "Code Health & Optimisation" backlog).
