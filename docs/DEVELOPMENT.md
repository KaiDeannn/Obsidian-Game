# OBSIDIAN — Development Documentation

Godot 4 (validated on 4.7.2). Two scenes: **Nova Aetheris** (the city) and **The Spire Ruins** (the battlefield). Everything visual is built in code from `Palette.gd` / `UIKit.gd`; scene files stay small. This document records how the game is put together, what each system does, how to extend it, and how it is tested.

Run the game: open the project in Godot and press Play (`scenes/city/NovaAetheris.tscn` is the main scene).
Headless regression test: `godot --headless --path . --quit-after 60000 res://tools/SmokeTest.tscn` (145 checks).

---

## 1. Project layout

```
project.godot                autoloads, input map, display
scenes/city/                 NovaAetheris.tscn, Player.tscn, Vehicle.tscn, CityGate.tscn
scenes/spire/                SpireRuins.tscn, SpirePlayer.tscn, TrainingDummy.tscn, BattleFighter.tscn
scenes/ui/                   RankModal.tscn (autoload)
scripts/autoload/            GameState, RankManager, JobManager, Session, Valet, Cinematic, BattleManager
scripts/city/                city gameplay: player, vehicle, camera rig, gate, builder, road network, valet driver, objective marker
scripts/spire/               arena builder, combat controller, player, AI (TrainingDummy, BattleFighter), thrown blades
scripts/ui/                  HUDs, phone, mini-maps, store, rank modal
scripts/shared/              Palette, UIKit, WeaponModels, CinematicData, BattleData
audio/                       Rook's voice lines (macOS `say`), ringtone, ping, connect blip
assets/weapons/engineer/     Engineer weapon models (*.glb) and their card pictures (cards/)
tools/                       SmokeTest, DemoDirector + preview directors, ExportMaps
docs/                        this file
```

### Autoloads (order matters: later ones may reference earlier ones)

| Autoload | Role |
|---|---|
| `GameState` | credits, points, class, properties, gear, vehicles + damage, equipped Engineer weapon, `intro_played`, input-map safety net |
| `RankManager` | renown, rank ladder D→C→B→A→S (0/500/1500/3500/7000), `rank_advanced` |
| `JobManager` | job board, active job, multi-stage objectives, payouts |
| `RankModal` | pauses the game and shows the rank-up modal |
| `Session` | player-to-player texts and voice calls over high-level multiplayer (simulated roster offline) |
| `Valet` | Rook's valet & mechanic: Request / Fix / Return, `ValetDriver` drives the car along `RoadNetwork` |
| `Cinematic` | data-driven camera sequences (section 3) |
| `Battle` (`BattleManager.gd`) | match setup, pending match, results and rewards (section 4) |

---

## 2. Core loop (what the player does)

1. **Opening cinematic** (first entry only): fly-over of the gate, The Heights and Core Plaza, settling behind the player.
2. **City**: walk / drive (E enters the parked car), phone (P) with Jobs, Property, Stats, Calls (texts, voice calls, Rook the valet), Garage, Weapons, Battles.
3. **Battles**: pick Solo / Tournament / Clan War and a preferred map on the phone, press Find match. The Spire gate becomes "your portal" (objective marker, mini-map pin, HUD line). Walk or drive to it and press E.
4. **The Spire**: class select (Swordsman / Sniper), arena fly-in, 3-2-1-FIGHT, the match. Results screen pays Renown and Points; Rematch or Return.
5. **Training ground**: entering the gate with no pending match gives the open arena with dummies and hunters, as before.

---

## 3. Cinematic system

**Files**: `scripts/autoload/Cinematic.gd`, `scripts/shared/CinematicData.gd`.

A sequence is an `Array` of shot dictionaries. The autoload spawns a temporary `Camera3D`, plays the shots, shows letterbox bars, titles and a fade, and restores the previous camera when done. Space / Esc / Enter skip (unless `skippable: false`).

```gdscript
Cinematic.play_named("city_intro", {"resolve": _resolve_cine_point})
await Cinematic.play([{"type": "orbit", "center": Vector3.ZERO, "radius": 30, "height": 20, "duration": 4}], {"fade_in": false})
```

Shot types:

| type | keys |
|---|---|
| `fly` | `from`, `to` (each `{"pos", "look"}` or a String anchor), `duration`, `ease` (`in_out` default, `in`, `out`, `linear`) |
| `orbit` | `center`, `radius`, `height`, `look_height`, `from_angle`, `to_angle`, `duration` |
| `track` | `node` (Node3D / NodePath / anchor), `offset`, `look_offset`, `duration` — follows a moving node |
| `hold` | `duration` — keeps the last camera |

Common keys: `fov`, `title`, `subtitle`, `hold` (extra seconds at the end of the shot).

**Anchors**: any `pos` / `look` / `center` / `to` may be a String. The scene passes a `resolve: Callable(key) -> Dictionary|Vector3|Node3D`; `CityController._resolve_cine_point` knows `player_back`, `player_high`, `player_head`, `gate`, `player`; `SpireCombat._resolve_cine_point` knows `player_back`, `player`. This is what makes sequences reusable: the same `city_intro` ends exactly where the gameplay camera sits regardless of where the player spawned.

**Signals**: `started(name)`, `shot_started(index, shot)`, `finished(name, skipped)`. The caller is responsible for disabling input and hiding its HUD (`CityController._play_intro` is the reference implementation).

**Catalogue** (`CinematicData.SEQUENCES`): `city_intro` (4 shots, ~22 s), `gate_transit`, `match_ready` (plays when a match is found in the city), `battle_intro` (arena fly-in before the countdown; its first shot is reused as the tournament spectator view).

**Adding a cinematic**: add an entry to `SEQUENCES`, play it with `play_named`, and, if it needs scene positions, add the anchor keys to that scene's resolver. Opts: `fade_in`, `fade_out`, `skippable`, `letterbox`.

**Gotchas**: a killed `Tween` never emits `finished`, so shots are awaited with a polling `_wait_tween` that returns on skip. The reveal fade after a sequence runs in the background (`_reveal`) so callers resume the moment the camera is handed back; tools and tests set `GameState.intro_played = true` to bypass the opening.

---

## 4. Battle system (from the design document)

**Files**: `scripts/shared/BattleData.gd`, `scripts/autoload/BattleManager.gd`, `scripts/spire/SpireCombat.gd`, `scripts/spire/BattleFighter.gd`, `scripts/spire/SpireArenaBuilder.gd`, `scripts/ui/SpireHUD.gd`, `scripts/ui/TacticalMiniMap.gd`, phone page `_build_battles` in `PhoneUI.gd`.

### 4.1 Match setup (`Battle.setup_match(mode, preferred_map, allies, seed)`)
- **Golden Rule**: every opponent is generated at exactly the player's rank (`RankManager.rank_letter()`); any class can face any class.
- **Map rule**: the opponent gets a random preference. If it equals the player's, that map is used; otherwise the system picks one of the three at random. `pending["map_rule"]` explains the outcome and the HUD toasts it.
- **Modes** (`BattleData.MODES`): `solo` (one opponent), `tournament` (three rounds, three opponents), `clan_war` (you + up to four picked clan members vs five).
- **Tournament tiers**: `can_enter_tournament(tier)` is true only for the player's own rank.
- **Clan war picks**: `eligible_clan_members(tier)` returns members who are online *and* at that rank; at most four are taken.
- The message "Your match is ready. Follow the markers to your portal. Good luck!" is emitted with `match_ready`.

### 4.2 City side
`CityController` listens to `match_ready` / `match_cleared`: objective marker and mini-map pin on the Spire gate, HUD objective line, gate prompt "YOUR PORTAL — Press [E] to enter the …", and the `match_ready` cinematic. The BATTLES phone app shows mode cards, tournament tiers, the clan roster with eligibility, map preference cards, Find match, Cancel match and the last result. Stats shows "Battles won".

### 4.3 Arena (`SpireArenaBuilder.map_id`)
| map | layout | class zones labelled |
|---|---|---|
| `ruins` | the original plaza: dais + ramps, cover rings, two vantage decks, ruin shells, colonnade | Central Plaza, High Spires, Mid-Tier Balconies, Shadow Corridors, Ramp Entrances, Chokepoints |
| `rooftop` | five roofs at 5–11 m with parapets, AC units and ramps to street level | High Spires, Ramp Entrances |
| `forest` | ~70 trunks with canopies, fallen logs, a shrine | Shadow Corridors |

The builder reads `Battle.pending["map"]` at `_ready`; with no pending match it builds the Ruins training ground.

### 4.4 Match flow (`SpireCombat`)
1. `Battle.has_pending()` → training enemies are removed, the class-select banner shows mode / map / rank.
2. Deploy → `_start_match()`: `battle_intro` cinematic (skippable), fighters spawned and frozen, `hud.countdown()` 3-2-1-FIGHT, fighters released, `match_active = true`.
3. Per mode:
   - **Solo**: opponent downed → win. Player downed → "DOWNED — ATTEMPT RESTARTS": both revive at their spawns, `attempts += 1` (document: restart from the beginning of that attempt).
   - **Tournament**: each opponent downed → "ROUND n WON", the next opponent spawns, player healed. Three wins → win. Player downed → "ELIMINATED — SPECTATING": the arena orbit plays, then the loss result (document: eliminated players spectate until the match ends).
   - **Clan War**: five a side, fighters respawn (`respawns = true`), the player respawns after 3 s. Score is kills; first to `kill_target` (8) wins, or the higher score at `time_limit` (240 s).
4. `_end_match(won)` → `Battle.finish(won, stats)` pays `win_renown/points` or `loss_*` (+ per-round bonuses for tournaments), then `hud.show_results` with Rematch (same mode and preference) or Return. Per-takedown rewards in matches are small (+10 pts, +5 renown) so the match result dominates.

### 4.5 AI fighters (`BattleFighter`, extends `TrainingDummy`)
`setup(data)` before `add_child`. Classes and behaviour:

| class | weapon category (dot colour) | behaviour |
|---|---|---|
| Swordsman | melee (red) | hunter loop: chase, wind-up, strike (parryable) |
| Ninja | thrown (violet) | fast melee variant |
| Sniper | ranged (amber) | holds 16–30 m, accurate hitscan every 2.4 s, 34 dmg |
| Archer | ranged | holds 9–20 m, 17 dmg every 1.2 s |
| Assault | ranged | holds 5–13 m, 8 dmg every 0.38 s with spread |
| Engineer | explosive (orange) | lobs a charge every 2.6 s that bursts for 22 dmg in 3.2 m |

Targets are the nearest living opponent (`players` + `ally` groups for enemies, `enemy` group for allies). Ranged fire needs line of sight (World-layer ray). HP scales with rank (120 + 25 per tier). Allies sit on the Player physics layer so the player's blade ignores them. `revive()` is used for rounds, solo restarts and clan-war respawns.

### 4.6 Vision system
The tactical mini-map shows enemy dots only with line of sight (World-layer ray from the player's eye to the enemy's chest), fading 0.6 s after LOS breaks. Dot colour is the fighter's weapon category (`BattleData.WEAPON_COLORS`); allies are drawn cyan without LOS. There is no lock-on anywhere; all aiming is manual.

---

## 4b. City visuals (modern metropolis pass)

**Files**: `scripts/city/CityBuilder.gd`, `Pedestrian.gd`, `TrafficDriver.gd`, `scenes/city/NovaAetheris.tscn` (environment + sun), `Palette.pbr`, `VehicleController._build_model`.

- **Look**: bright daytime. Sun `DirectionalLight3D` (energy 1.6, warm white) with 4-split cascaded shadows (PSSM, 200 m); procedural blue sky; sky-driven ambient blended 40 % with a neutral colour; sky reflections plus screen-space reflections for the glass; SSAO; ACES tone mapping; subtle glow (bloom); light aerial fog; MSAA 2x + FXAA.
- **Materials** (all `StandardMaterial3D`, physically based): blue curtain-wall glass (metallic 0.88, roughness 0.06), dark storefront glass, clear railing glass, white and grey concrete, asphalt, light pavement, lane paint, metal, grass, hedge, water.
- **Architecture**: `_glass_tower` (three-storey white podium with storefront band and canopy, planted terrace with umbrella tables, glass tower with white floor bands and corner columns, roof garden), `_midrise_building` (retail base, window strips, alternating balconies with glass rails and planters, optional roof garden), `_build_commerce` (mixed-use blocks, plaza pool), `_build_villas` (white houses with roof gardens and plunge pools on the CityData property plots), `_build_plaza` (white dais in a reflecting pool, bridges, flowerbeds, cafe seating, the station shelter).
- **Roads**: every corridor is a dual carriageway. The centre line carries a 2 m grass median with a hedge (gaps at intersections); dashed dividers at ±3.5 m, edge lines at ±5.9 m, zebra crossings on each approach. **Cars drive on the right-hand lane, 2.3 m off the centre line** (`RoadNetwork.lane_point` gives a look-ahead point for lane keeping; `ValetDriver` and `TrafficDriver` both use it). Parked cars sit in the kerb lane.
- **Life**: 34 `Pedestrian` figures walking pavement loops (visual only, no collision); 6 traffic cars on three loops through the vehicle autopilot (they collide like any car; NPC-driven cars never record crash damage).
- **Unchanged**: the 6×6 road lattice, block positions, property positions, job stage positions, the Spire gate trigger, the station pick-up spot, all gameplay scripts. The player's car now starts in the inner lane (`CityData.VEHICLE_SPAWN` z = 29).
- **Tuning**: counts are the constants `PEDESTRIANS` / `TRAFFIC_CARS` at the top of `CityBuilder.gd`; lighting lives in the scene's `Environment_city` sub-resource.

---

## 4c. Engineer class and weapons

**Files**: `scripts/city/CityData.gd` (`PREMIUM_WEAPONS`), `scripts/shared/WeaponModels.gd`, `scripts/spire/Explosive.gd`, `scripts/spire/SpirePlayer.gd` (engineer section), `tools/build_weapon_models.py`, `tools/RenderWeaponCards.gd`, `assets/weapons/engineer/` (`*.glb` models, `cards/*.jpg` pictures rendered from those models).

- **Class**: `GameState.CLASS_ENGINEER`, key **3** on class select. LMB uses the equipped weapon, Q (`weapon_next`) cycles the catalogue live, RMB does nothing. The Swordsman and Sniper are unchanged.
- **Models**: built in Blender 3.6 by `tools/build_weapon_models.py` (`blender --background --python tools/build_weapon_models.py -- assets/weapons/engineer [render_dir]`): lathed canister bodies, bevelled plates, tapered shells, levers, pull rings, emissive cores, Principled materials. One `.glb` per weapon id; after rebuilding run the editor import. `WeaponModels.build(w)` returns the held model, `build_munition(w)` the flying one.
- **Data** per weapon: `kind` (`launcher` / `grenade` / `mine`), `trait`, `radius`, `cooldown`, and where relevant `speed`, `gravity`, `burst`, `fuse`, `freeze_time`, `trigger_radius`, `arm_time`, `max_active`.

| weapon | rarity | damage | kind | effect (`trait`) |
|---|---|---|---|---|
| Oathkeeper | Mythic | 88–100 | launcher | arcing round, 5.5 m blast, slow (1.8 s) |
| Sunblaze | Legendary | 42–50 | launcher | three-round burst, 2.8 m blasts |
| Skyfall | Legendary | 75–85 | launcher | straight plasma bolt, 4.5 m splash |
| Cinder-Canister | Legendary | 65–75 | grenade | 4.5 m blast, shortest cooldown |
| Sol-Orb | Legendary | 78–90 | grenade | 45 % burst + burn zone ticking for 3.6 s (`burn`) |
| Frost-Stasis | Legendary | 30–45 | grenade | enemies frozen 3.5 s (`freeze`) |
| Scarlet-Fuse | Legendary | 72–82 | grenade | 2.5 s countdown, knockback + stagger (`concussion`) |
| Void-Orb | Legendary | 70–80 | grenade | pulls enemies within 7 m inward, then crushes (`implosion`) |
| Sunstone | Mythic | 90–115 | grenade | 8 m burst, white-out flash, 40 % self-damage inside 4 m (`shatter`) |
| Hellfire-Mine | Legendary | 75–88 | mine | arms in 1 s, bursts on an enemy within 2.8 m, max three (`blast`) |

- **`Explosive`**: one node per round / grenade / mine. Modes `impact` (ray-swept flight with gravity scale), `timed` (bounces, rests, countdown label) and `proximity` (static, armed after `arm_time`). `detonate()` applies the trait, spawns the blast sphere, shockwave ring and light, and emits `detonated`. Area damage falls off to 50 % at the rim. Enemies gained `freeze(seconds)` / `is_frozen()`; frozen or staggered ranged fighters neither move nor fire.
- **Adding a weapon**: one entry in `PREMIUM_WEAPONS`, one build function in `tools/build_weapon_models.py`, then run `tools/RenderWeaponCards.tscn` to render its card picture (`WeaponModels.stage()` is the shared lit stage, also used by the phone's 3D viewer). A new effect is one more `match` arm in `Explosive.detonate()`.

---

## 5. Other systems (reference)

- **Phone** (`PhoneUI.gd`): Home, Jobs, Property, Stats, Calls (contacts, messages, call overlay with ringtone/timer/mic meter; Rook's valet bar after his recorded greeting), Garage (vehicles, condition, dealership), Weapons (Engineer arsenal, Equip), Battles.
- **Session** (`Session.gd`): texts and voice over RPC, simulated roster offline; attach any `MultiplayerPeer` for real players.
- **Valet** (`Valet.gd`, `ValetDriver.gd`, `RoadNetwork.gd`): Request spawns the car at a road node ≥45 m away and drives it along A* road paths to the kerb beside the player; Return despawns; Fix queues repairs and Rook calls back.
- **Engineer weapons** (`CityData.PREMIUM_WEAPONS`, `WeaponModels.gd`, `Explosive.gd`, `SpirePlayer` engineer section, `tools/build_weapon_models.py`): the ten Legendary & Mythic weapons from the Engineer document. See section 4c.
- **Progression**: jobs and takedowns pay Renown and Points; crossing 500 Renown shows the Rank C modal and unlocks Mythic / Legendary gear in the Spire armory (two-step purchase rule).

---

## 6. Testing and previews

- `tools/SmokeTest.tscn` — headless, 145 checks across progression, city, comms + valet, Engineer weapons, cinematic system, battle setup, matches in the Spire (solo win and restart, ranged AI fire, tournament elimination, clan war), Spire combat, rank modal. Run after every change. Timing-sensitive sections wait on conditions (`_wait_until`) rather than fixed delays where possible.
- Preview directors (`tools/DemoDirector.gd`, `CommsValetPreview.gd`, `PremiumWeaponsPreview.gd`) drive the real game for Movie Maker recordings: `godot --path . --write-movie preview/x.avi --fixed-fps 30 res://tools/X.tscn`, then encode with ffmpeg (CRF 17–23 keeps a two-minute clip under 20 MB).
- GDScript rules of thumb in this codebase: `:=` cannot infer from autoload members, Dictionary values, ternaries or untyped loop variables — type them explicitly; `match` is a reserved word (the combat controller uses `fight` for the match dictionary); new `class_name` scripts need an editor import (`--import`) before headless runs see them.

---

## 7. Changelog

- **2026-10-21** — vertical slice: city (driving, phone with Jobs / Property / Stats, gate), Spire (class combat, LOS mini-map, rank modal, armory).
- **2026-10-29** — player-to-player comms (texts, voice calls) and Rook's valet (Request / Fix / Return, driving NPC); flat theme.
- **2026-11-03** — first weapon set (ninja blades), Weapons app, Q cycling (replaced on 2026-11-06).
- **2026-11-06** — the ninja weapon set was removed and replaced by the ten Engineer Legendary & Mythic weapons: Blender-built models, a playable Engineer class, launcher / grenade / mine behaviour with six detonation effects.
- **2026-11-05** — city visual overhaul: sunlit modern metropolis (PBR materials, glass towers with podiums and terraces, greenery and water, dual carriageways with medians and crossings, traffic, pedestrians, daylight lighting and post-processing); lane keeping for NPC drivers.
- **2026-11-04** — scalable cinematic system with the opening fly-over; battle system from the design document (Solo / Tournament / Clan War, Golden Rule, map rule, portal flow, three arenas, six AI classes, vision dots, results and rewards); this document.
