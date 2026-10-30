# OBSIDIAN — Vertical Slice Prototype (Godot 4.3+)

Two playable scenes built in Godot 4 with GDScript only (no external assets; every mesh,
material and UI element is generated in code with a consistent obsidian / neon art direction):

| Scene | File | What it proves |
|---|---|---|
| **Nova Aetheris** (The City) | `scenes/city/NovaAetheris.tscn` | On-foot + driving, speedometer mini-map, smartphone (Jobs / Property / Stats), Spire gate portal |
| **The Spire Ruins** (The Battlefield) | `scenes/spire/SpireRuins.tscn` | Swordsman / Sniper classes, AI targets, tactical LOS mini-map, rewards, Rank C modal, two-step Armory |

Validated with Godot **4.7.2** headless (import, both scenes, and `tools/SmokeTest.tscn`: 48 gameplay checks).

## Run

1. Open the `obsidian/` folder in Godot 4 (Project Manager → Import → select `project.godot`).
2. Press **F5**. The city loads first; walk into the Spire Gate at the north edge to travel to the battlefield.

Headless regression test (no window needed):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tools/SmokeTest.tscn
```

## Controls

| Context | Keys |
|---|---|
| On foot (both scenes) | **WASD** move · **Shift** sprint · **Space** jump · mouse look · **Esc** release / recapture mouse |
| City | **E** enter / exit vehicle, confirm gate travel · **P** phone (or the PHONE button) |
| Phone › CALLS | **Message** / **Call** a player in the session · **Call Rook** for the valet: **Request** / **Fix** / **Return** |
| Vehicle | **W/S** throttle & brake/reverse · **A/D** steer · **Space** handbrake · **E** exit |
| Spire | **1 / 2** choose class · **LMB** strike / fire · **RMB** block / aim · **R** reload · **B** Armory · **Esc** pause |

## Systems map

### Autoloads (`scripts/autoload/`)
- **GameState.gd** — Credits, match Points, selected class, owned properties & gear, return-from-Spire flag. Also re-registers the input map if it is ever wiped.
- **RankManager.gd** — Renown and the ladder **D → C → B → A → S** (thresholds 0 / 500 / 1500 / 3500 / 7000). `add_renown()` emits `rank_advanced`, `meets_rank("C")` gates the store.
- **JobManager.gd** — Job board from `CityData.JOBS`, active job + multi-stage objectives, pays Credits + Renown on completion (+5 % credits per owned Heights property).
- **RankModal.tscn** (`scripts/ui/RankModal.gd`) — global CanvasLayer 100 that pauses the game and shows *"Congratulations — Advanced to Rank C"* wherever the threshold is crossed.
- **Session.gd** — player-to-player communication: roster of session players (high-level multiplayer peers; a simulated roster of three answers offline), direct **text messages** with unread counts, and **voice calls** (ring / accept / decline / end signalling, microphone capture → 16 kHz PCM over RPC → generator playback, mute). Attach any `MultiplayerPeer` and the same code talks to real players.
- **Valet.gd** — Rook Hale's automated valet & mechanic: **Request** spawns an owned vehicle at a road node ≥ 45 m away and a `ValetDriver` NPC drives it along the road graph to the player, parks at the kerb and climbs out; **Return** removes it instantly; **Fix** puts a damaged vehicle on the service queue (`repair_seconds_per_percent`) and Rook rings back when it is done.

### City (`scripts/city/`)
- **CityController.gd** — scene glue: camera target switching, mouse capture, HUD/phone wiring, job → objective beacon.
- **PlayerController.gd** — camera-relative WASD, sprint/jump, `InteractArea` detects the vehicle, `enter_vehicle()` / `exit_vehicle()`.
- **VehicleController.gd** — arcade CharacterBody3D car: throttle/brake/reverse, speed-sensitive steering, grip blend + handbrake drift, head-on impact speed loss, wheel/roll visuals, headlights. `get_mph()` feeds the speedometer. Has a `vehicle_id` + `paint` (from `CityData.VEHICLES`), an **autopilot** input path for the valet, and reports crash damage to `GameState.damage_vehicle()`.
- **ValetDriver.gd** — NPC chauffeur: follows a `RoadNetwork` path through the vehicle's autopilot (corner/approach speed, un-stick reverse, kerb stop), parks, releases the car and walks off.
- **RoadNetwork.gd** — the 6×6 lattice of lane centre lines (x or z ∈ ±26, ±78, ±137): nearest node / lane point, A* road paths, spawn-node search.
- **CameraRig.gd** — ORBIT (mouse look on foot) / CHASE (settles behind the car, stretches with speed).
- **CityGate.gd** — Area3D portal with pulsing field; prompt on enter, **E** loads the Spire.
- **CityBuilder.gd** — procedural 5×5-block city from `CityData.gd`: Core Plaza obelisk, The Heights towers + property villas, Neon Docks, parks, lamps, lane lines, parked cars, boundary.
- **ObjectiveMarker.gd** — beam + ring + label at the active objective.

### UI (`scripts/ui/`)
- **RadarMap.gd** — base class: SubViewport top-down render of the live world, circular shader mask, overlay drawing helpers.
- **CityMiniMap.gd** — markers (player arrow, vehicle, objective, gate, properties) + **Speedometer**: Green < 50 mph, Yellow 50–70, Red > 70 (label and ring colour).
- **TacticalMiniMap.gd** — Spire map; enemy dots drawn **only while a physics ray from the player's eye to the enemy's chest hits nothing on the World layer** (short fade when LOS breaks).
- **PhoneUI.gd** — animated slide-up phone: Home, **Jobs** (accept / track / cancel), **Property** (buy with confirm step, insufficient-funds feedback), **Stats** (Rank badge, Renown progress bar, Credits, Points…), **Calls** (players in session with Message / Call, message threads, the Rook Hale valet contact) and **Garage** (owned vehicles with condition bars, dealership with delivery by valet). The **call overlay** sits beside the docked phone: incoming calls (Answer / Decline, ringtone), live call timer + mic meter + Mute, and for Rook the recorded greeting *"Hey, how can I help you, or what do you want?"* followed by the **Request / Fix / Return** bar.
- **CityHUD.gd**, **SpireHUD.gd** — HUD layers (wallet strip, objective banner, prompts, toasts / health, ammo, crosshair, scope, hit markers, class select, pause).
- **StoreUI.gd** — Armory with the **two-step purchase rule** (see below).
- **UIKit.gd** (`scripts/shared/`) — styled panels, buttons, tags, progress bars; **Palette.gd** — materials and collidable primitives.

### Spire (`scripts/spire/`)
- **SpireCombat.gd** — match controller: class select → spawn, enemy `defeated` → Points + Renown, respawn, overlays, return to city.
- **SpirePlayer.gd** — one controller, two classes.
  *Swordsman*: tweened swing arc with a timed hitbox window (one hit per target per swing), block with a 0.3 s **parry** window that staggers hunters, 88 % damage reduction on a late block.
  *Sniper*: RMB slides the camera to first person + FOV 16 with scope HUD; LMB raycasts from the view centre with **bullet adjustment** = hip/ADS spread + gravity drop relative to a 60 m zero; headshots ×2; 5-round mag, reload.
- **TrainingDummy.gd** — `kind = DUMMY` (tracking target post) or `HUNTER` (wander → chase → wind-up → strike, obstacle sidestep, stagger). Floating damage numbers, death animation, respawn.
- **SpireArenaBuilder.gd** — Central Plaza: dais + shattered spire with four ramps, cover rings, two vantage platforms with ramps, ruin shells, colonnade, rubble, braziers, ruined perimeter.

### Two-step purchase rule (StoreUI)
1. **Step 1 – Rank verification.** Mythic (Obsidian Edge) and Legendary (Voidpiercer, Spire Sigil) items require **Rank C**. Below that the card is tagged `LOCKED – REQUIRES RANK C` and the detail panel contains **no purchase controls at all**.
2. **Step 2 – Purchase options.** Only after verification passes does *Open purchase options* reveal *Buy for credits* / *Buy for points*.

Physics layers: 1 World · 2 Player · 3 Enemy · 4 Vehicle · 5 Trigger.

---

## Node hierarchies

Nodes marked *(code)* are created by the attached script in `_ready()`, so the `.tscn` files stay small; the runtime tree looks like this.

### NovaAetheris.tscn
```
NovaAetheris (Node3D)                       CityController.gd
├── WorldEnvironment                        night sky, glow, fog, SSAO
├── MoonLight (DirectionalLight3D)
├── CityBuilder (Node3D)                    CityBuilder.gd
│   ├── Ground (StaticBody3D)               (code)
│   ├── LaneLines (Node3D)                  (code)
│   ├── Block_i_j (Node3D) ×25              (code) Sidewalk, buildings, bands, lamps, plaza / villas / docks / park
│   ├── ParkedCars (Node3D)                 (code)
│   ├── Bound{N,S,E,W} (StaticBody3D)       (code)
│   └── District signs (Label3D)            (code)
├── Player (CharacterBody3D)  [Player.tscn] PlayerController.gd   layer 2, mask World|Vehicle
│   ├── CollisionShape3D (Capsule)
│   ├── Model (Node3D)                      (code) torso, head, visor, pack, legs
│   └── InteractArea (Area3D, mask Vehicle)
│       └── CollisionShape3D (Sphere r3.2)
├── Vehicle (CharacterBody3D) [Vehicle.tscn] VehicleController.gd  layer 4, mask World|Player
│   ├── CollisionShape3D (Box)
│   └── Model (Node3D)
│       ├── Body (Node3D)                   (code) chassis, cabin, lamps, underglow, 2× SpotLight3D
│       └── wheel hubs ×4 (Node3D)          (code) tyre + rim
├── CityGate (Area3D) [CityGate.tscn]       CityGate.gd   layer 5, mask Player|Vehicle
│   ├── CollisionShape3D (Box 10×8×7)
│   └── pillars, lintel, PortalField, PortalRing, lights, labels   (code)
├── ObjectiveMarker (Node3D)                ObjectiveMarker.gd → Beam, Ring, Label3D (code)
├── CameraRig (Node3D)                      CameraRig.gd
│   └── Yaw (Node3D)
│       └── Pitch (Node3D)
│           └── SpringArm3D (mask World)
│               └── Camera3D (current)
├── CityHUD (CanvasLayer 10)                CityHUD.gd
│   └── Root (Control, full rect)           (code)
│       ├── CityMiniMap (RadarMap)          SubViewport→Camera3D(ortho) · TextureRect(mask shader) · Overlay · Speedometer strip
│       ├── Wallet strip (PanelContainer)   RANK tag · CREDITS · RENOWN
│       ├── Objective banner (PanelContainer)
│       ├── Toasts (VBoxContainer)
│       ├── Prompt (PanelContainer)
│       ├── Controls hint (Label)
│       └── PHONE [P] (Button)
└── PhoneUI (CanvasLayer 20)                PhoneUI.gd
    ├── Dim (ColorRect)                     (code)
    └── Dock (Control, bottom-right)        (code)
        └── Phone (PanelContainer, 380×690)
            └── Screen (VBox): status bar · page host (Home / Jobs / Property / Stats) · home bar
```

### SpireRuins.tscn
```
SpireRuins (Node3D)                         SpireCombat.gd
├── WorldEnvironment                        dusk sky, warm fog, glow, SSAO
├── SunLight (DirectionalLight3D)
├── Arena (Node3D)                          SpireArenaBuilder.gd
│   ├── Plaza, seams, scorch marks, SpawnPad          (code)
│   ├── Wall ×~30 + WallCap, Bound{N,S,E,W}           (code)
│   ├── Dais (8-sided) + 4 Ramp pivots, SpireColumn, cracks, SpireCore, Shards   (code)
│   ├── Cover (Node3D): Barricade ×6, Slab ×8, Crate ×8 (+ stacks), Pylon ×4     (code)
│   ├── VantageDeck ×2 + pillars, parapets, ramp, light, label                  (code)
│   ├── Ruin shells ×2, Column ×14, Rubble ×~24, Brazier ×8 + OmniLight3D       (code)
│   └── "CENTRAL PLAZA" (Label3D)
├── PlayerSpawn (Marker3D)                  (0, 0.6, 48)
├── Enemies (Node3D)
│   ├── Dummy1..8 (CharacterBody3D) [TrainingDummy.tscn]  kind = DUMMY,  group "enemy", layer 3
│   └── Hunter1..3 (CharacterBody3D) [TrainingDummy.tscn] kind = HUNTER
│       ├── CollisionShape3D (Capsule)
│       └── Model (Node3D)                  (code) body, head, visor, arm/blade or target rings, Label3D
├── SpirePlayer (CharacterBody3D) [SpirePlayer.tscn, instanced on deploy]  SpirePlayer.gd  layer 2, mask World|Enemy
│   ├── CollisionShape3D (Capsule)
│   ├── Pivot (Node3D, y 1.55)
│   │   └── SpringArm3D (mask World, 3.2 → 0.05 when aiming)
│   │       └── Camera3D (fov 75 → 16, h_offset 0.55 → 0)
│   └── Model (Node3D)                      (code)
│       ├── torso / Helmet / Visor / legs
│       ├── SwordPivot (Node3D) → Blade, BladeEdge, Guard, Grip
│       ├── Shield (Node3D) → ShieldPlate, ShieldLine
│       ├── Rifle (Node3D) → Receiver, Barrel, Scope, RailGlow, Stock, Muzzle (OmniLight3D flash)
│       └── HitBox (Area3D, mask Enemy, monitoring only during swing window)
└── SpireHUD (CanvasLayer 10)               SpireHUD.gd
    ├── Root (Control)                      (code)
    │   ├── Crosshair · Scope · HitMarker (custom-drawn Controls)
    │   ├── Status panel: class, health bar, ammo
    │   ├── Match stats: POINTS · RENOWN · RANK + progress
    │   ├── TacticalMiniMap (RadarMap, top-right)
    │   ├── Reward popups · Toasts · Controls hint
    ├── ClassSelect (Control overlay)       Swordsman / Sniper cards, Return to city
    ├── Pause (Control overlay)             Resume · Open Armory · Change class · Return
    └── StoreUI (Control)                   item list + detail: Step 1 rank verification → Step 2 purchase options
```

### Autoload: RankModal.tscn
```
RankModal (CanvasLayer 100, process_mode ALWAYS)   RankModal.gd
└── Root (Control) → Dim (ColorRect) → CenterContainer → Panel: rank badge, "Congratulations — Advanced to Rank C", body, Continue
```

## Tuning knobs
- Rank thresholds: `RankManager.THRESHOLDS`. Dummy = 50 pts / 45 renown, Hunter = 150 pts / 90 renown (`TrainingDummy._ready`). Jobs pay 120–200 renown, so Rank C (500) arrives after roughly one job plus six takedowns.
- Vehicle feel: exports on `VehicleController` (`max_speed` 42 m/s ≈ 94 mph, `steer_rate`, `grip`).
- Sniper ballistics: `SpirePlayer.BULLET_SPEED`, `ZERO_RANGE`, `HIP_SPREAD`, `AIM_SPREAD`.
- City layout, jobs, properties, gear and vehicle catalogue, phone contacts: `scripts/city/CityData.gd`.
- Valet: `Valet.min_spawn_distance` (45 m), `repair_seconds_per_percent` (0.5), `min_repair_seconds` (6); driver feel on `ValetDriver` (`cruise_speed` 15 m/s, `park_distance`, `kerb_park_distance`). Rook's voice lines are `audio/rook_*.wav` (macOS `say -v Daniel`); ringtone / ping / connect blips are generated sine tones.
