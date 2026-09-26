# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Railway Warriors** is a 3D RTS built in **Godot 4.7** where the units are trains.
Spiritual reference point: *Locoland* — but on a modern engine and expected to run
well on modern hardware. It's a spare-time project, so prefer small, self-contained
changes that keep the scene playable over large refactors.

Current state is a navigation/movement prototype: one player train made of coupled
wagons, a hand-placed rail network plus an experimental generated spline track,
RTS camera, click-to-select, click-to-move, and uncouple/re-couple.

Performance is an explicit design goal — see "Known rough edges" for the parts
that will not survive scaling up to many trains.

## Roadmap — where the project is

The full plan lives in [docs/ROADMAP.md](docs/ROADMAP.md). **Read it before
proposing what to work on next, and update its status notes when something lands.**

Steps 1-4 (engine choice, team, budget, learning) are done. The project is in
**step 5: developing core concepts individually**, before step 6 combines them.

| Core concept | Status |
|---|---|
| Pathfinding via tracks | done |
| Movement via railways | done |
| Coupling / decoupling | done |
| Static objects (obstacles) | partial — only parked wagons block edges |
| Ballistics | done — `projectile.gd` |
| Enemy detection | done — `target_detector.gd` |
| HP and ammo system | done — `health.gd`, `ammo.gd`, `ammo_supply.gd` |

Those last three landed together as one combat vertical slice (see "Combat"
below). They were bundled rather than sequenced because none of them can be
proven alone: HP has nothing to test against without a damage source, and
ballistics has nothing meaningful to hit without HP.

`origin/ballistics` is a **separate standalone Godot project**, not a feature branch
of this one — it has its own `project.godot`. It is now **reference material only**:
the combat code here was written fresh, keeping just the parabola from
`bullet.init_movement()`. Do not try to merge the branch or reconcile the two
`project.godot` files.

Two constraints from the roadmap that affect everyday decisions:

- **Budget is extremely limited and self-funded.** Prefer procedural/generated
  content and engine built-ins; assume zero third-party dependencies and no paid
  assets unless the user says otherwise. `track_spline.gd` is the model here —
  geometry made in code rather than bought.
- **Step 7 is a serious unit-testing pass** over every core concept. Nothing needs
  testing infrastructure yet, but prefer code that could be tested in isolation
  later — the current `track_pathfinding` (reads the live scene tree) and `Train`
  (owns its own input handling) are the existing counter-examples.

## Commands

The Godot editor binary lives outside the repo:

```bash
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --editor --path .
```

Run the game directly (main scene is `scenes/main.tscn`):

```bash
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --path . scenes/main.tscn
```

There is no test suite, linter, or CI. The two useful non-interactive checks are:

```bash
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --check-only --script scripts/train_navigation.gd
```

(parse-checks one GDScript file; exits non-zero and prints `Parse Error` on failure —
this is the closest thing to a lint step, worth running on every script you edit)

```bash
~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --quit
```

(imports all resources and loads the project; catches broken `.tscn` references and
missing UIDs without opening a window)

## Architecture

### The navigation graph is keyed by world positions, not node names

This is the single most important thing to know. `graph` in
[track_pathfinding.gd](scripts/track_pathfinding.gd) is
`Dictionary[Vector3 -> Dictionary[Vector3 -> float]]` — keys are
`global_transform.origin` values, edge weights are Euclidean distance. Paths
returned by `shortest_path()` are arrays of `Vector3`, consumed directly as
waypoints. Nothing looks up nodes by name.

Consequence: edges are snapshots of positions taken when `connections.gd` ran, so
moving a rail piece at runtime does not update existing `connections_ids`.

### How the graph gets built

1. Each rail piece scene (`rail_straight`, `rail_turn`, `rail_junction_right`,
   `rail_seperation_right`) has a `Points` child containing `sphere.tscn` instances.
2. `sphere.tscn` is an `Area3D` in the `navigation_point` group running
   [connections.gd](scripts/connections.gd). Its exported `connections_list`
   hand-wires the neighbours *within* one rail piece; `area_entered` adds links
   *between* pieces when two spheres overlap at a joint.
3. [track_pathfinding.gd](scripts/track_pathfinding.gd) is attached to the `Track`
   node in `main.tscn` (a `floor_panel.tscn` instance that parents every rail piece).
   `get_node_data()` walks `get_children()` and reads **`child.get_child(0)`** as the
   points container.

**Rule that falls out of step 3: any direct child of `Track` must have its points
container at child index 0.** `track_spline.gd` explicitly calls
`move_child(points_node, 0)` to satisfy this. A rail piece that violates it will
crash or silently contribute nothing.

Note the `navigation_point` global group exists and every sphere is in it, but the
graph builder does not query the group — it walks the tree. Either is fine; just
don't assume the group is load-bearing.

### Pathfinding

`shortest_path(click_pos, start_pos, obstacles)` is the entry point:

- `find_nearest_segment()` projects both the train position and the click onto the
  closest *edge* (not node), so the train can start and stop mid-segment.
- It then runs `dijkstra()` for all four (start endpoint × dest endpoint)
  combinations and keeps the cheapest total, then splices the exact start position
  and the projected destination onto the ends.
- `obstacles` is an array of world positions (parked wagons). `_edge_blocked()`
  removes any edge passing within `OBSTACLE_RADIUS` (1.5) of one.
- Returns `null` when unreachable. `dijkstra()` bails out as soon as the cheapest
  unvisited node is at `INF` — without that guard it would fabricate a bogus
  single-node path across disconnected networks.
- `visualize_path()` spawns `point.tscn` markers for 1 second. These reuse the
  Area3D sphere scene, so they set `monitoring`/`monitorable` to false — otherwise
  they would register themselves as track connections.

### Train movement: one shared arc-length polyline

[train_navigation.gd](scripts/train_navigation.gd) (`class_name Train`, a `Node3D`
whose `CharacterBody3D` children are the wagons) does **not** make each wagon chase
the one ahead. Instead:

- `route` is a polyline = the track the train currently occupies (wagon positions,
  rear→front) followed by the computed path ahead. `route_cum` holds cumulative arc
  length; `head_s` is the lead wagon's distance along it.
- Every wagon samples the same polyline at `head_s - i * wagon_spacing`, so trailing
  wagons trace the rails through curves instead of cutting corners.
- Wagons are positioned by assigning `global_position` directly. They are
  `CharacterBody3D` only so they have a collider for mouse picking — **no physics
  movement, no `move_and_slide`**. Don't "fix" this by switching to velocity-based
  movement; it would break rail following.
- Braking is kinematic: decelerate once `remaining <= v² / 2a`.
- `set_destination()` compares the distance from each end of the train to the target
  and, if the rear is closer, calls `wagons.reverse()` so the train backs up rather
  than turning around. Wagon yaw keeps its existing heading on reversal (a wagon is
  symmetric, so flipping 180° would just look like a spin).

### Coupling

All of it lives in `Train`, driven by `_input`:

| Click | Target | Effect |
|---|---|---|
| Left | any | select/deselect this train (green tint via `material_override`) |
| Right | own wagon | uncouple it and everything behind it (`_detach_clicked`) |
| Right | detached wagon | drive to it and couple on arrival (`_command_attach`) |
| Right | anything else | `set_destination()` |

Detached wagons go into `detached_wagons` and are then passed as pathfinding
obstacles — except the one being driven to, which must stay passable.
`_complete_attach()` fires when the train has stopped one `wagon_spacing` short of
the target and makes that wagon the new front unit.

The code carries a `# TODO move input and raycasting out of here` — with more than
one train this has to become a separate selection/command system. Worth doing before
adding a second controllable train.

### Generated track (`dynamic-railway-experiment`)

[track_spline.gd](scripts/track_spline.gd) is a `@tool` script on a `Path3D`
(`class_name TrackSpline`). From a `Curve3D` it generates:

- an `ArrayMesh` with three surfaces — ballast box, left rail, right rail — extruded
  along baked curve samples;
- a `Points` container of nav spheres every `nav_spacing` metres, wired into a
  linear chain.

Press the **Rebuild Track** button in the inspector after editing the curve, or call
`rebuild_track()`. It also rebuilds on `_ready` at runtime.

Gotcha it already works around: `sphere._ready()` runs during `add_child()` with an
empty `connections_list`, so `_build_navigation()` repopulates both
`connections_list` and `connections_ids` *after* every sphere is in the tree (global
transforms aren't valid before that).

This is the direction of the current branch — the long-term aim is to stop
hand-placing rail pieces.

### Combat

Four small nodes, none of which know about `Train`. Everything hangs off a unit
as a child node, so a damage source never has to know what it just hit.

- [health.gd](scripts/health.gd) (`class_name Health`, a plain `Node`) — hp,
  `faction` (PLAYER/ENEMY), `take_damage()`, `died`. The static
  `Health.find_in(body)` is the entry point every other part uses: "does this
  body have hit points, and whose side is it on?". `free_unit_on_death` frees
  the parent; player wagons set it **false** because `Train` holds references to
  them.
- [ammo.gd](scripts/ammo.gd) (`class_name Ammo`, a plain `Node`) — rounds the
  unit carries. A sibling of `Health` on the **unit**, never a property of the
  gun, so a resupply source can top a unit up without knowing what it mounts.
  `supply(float)` banks fractional resupply until it makes whole rounds, and
  that leftover lives on the receiving unit so partial progress survives driving
  out of range and back.
- [target_detector.gd](scripts/target_detector.gd) (`Area3D`) — nominates the
  nearest living hostile in its radius. It only *picks*; it never fires.
- [weapon.gd](scripts/weapon.gd) (`class_name Weapon`, `scenes/weapon.tscn`) —
  owns cooldown, range and damage, builds its own `TargetDetector` sized from
  `attack_range`, aims (yaw only) and fires. It draws rounds from the host
  unit's `Ammo`; with no `Ammo` on the unit it warns and fires unlimited.
  Mounted as a child of a wagon, **not** a method on `Train`.
  `inherit_faction_from_unit` reads the faction off the host unit's `Health`, so
  the same scene works on either side.
- [ammo_supply.gd](scripts/ammo_supply.gd) (`class_name AmmoSupply`, `Area3D`) —
  an infinite, slow resupply source. Tops up every friendly unit with an `Ammo`
  component inside `supply_range` at `rounds_per_second`. It is a plain
  component on a host unit, so the repair depot can mount the same node when it
  exists.
- [projectile.gd](scripts/projectile.gd) (`Area3D`, `scenes/projectile.tscn`) —
  lobbed shell. Interpolates flat from muzzle to aim point and adds a parabolic
  bulge to y; that parabola is the one piece kept from the spike's `bullet.gd`.
  Unlike the spike it interpolates rather than integrating a velocity, so a
  fired shot cannot drift past its target, and it tracks its target's current
  position in flight (a deliberate prototype shortcut — real target leading
  belongs with enemy AI in step 9).

`scenes/enemy_wagon.tscn` is the test dummy: a red `CharacterBody3D` with
`Health` (faction ENEMY), `Ammo` and status bars, no AI. One instance sits in
`main.tscn` at `(15, 0.39, -19.8)`, next to the east end of the hand-placed
line, ~32 m from the train's start — far enough that the player has to drive to
it. Drive the train there and the weapon engages by itself.

`scenes/ammo_wagon.tscn` is the mobile resupply: an olive wagon with `Health`,
`Ammo` and an `AmmoSupply`. It is coupled into the player train as the third
unit, so uncoupling and re-coupling it is how you see supply stop and restart.

### Ammo economy

Every rail unit carries `Ammo`, armed or not — a wagon's magazine is part of the
unit. The shipped numbers make supply the binding constraint during a sustained
fight rather than a formality:

| | value |
|---|---|
| unit magazine | 12 rounds |
| weapon cooldown | 1.2 s, i.e. 0.83 rounds/s while engaging |
| `AmmoSupply.rounds_per_second` | 0.5 |
| `AmmoSupply.supply_range` | 12 m |

So a gun firing continuously drains about a third of a round per second and
empties a full magazine in roughly 36 s, after which it is supply-limited to a
shot every two seconds. Cut the ammo wagon loose and it simply runs dry.

`supply_range` of 12 m is generous on purpose: it covers a coupled train (2.5 m
between wagons) *and* friendly units merely parked nearby, so one radius rule
serves both without a separate "is it coupled to me" check.

### Status bars

[unit_status_bars.gd](scripts/unit_status_bars.gd) (`class_name UnitStatusBars`)
draws a health bar on every rail unit and an ammo bar on the ones that can
shoot — it looks for a `Weapon` child to decide. Built at runtime from a
generated `Image` on a `Sprite3D`, plus the hit flash.

It is **one sprite with a redrawn texture**, not a background quad plus a fill
quad, and that is not a style choice: billboarding replaces the node basis with
the camera's while keeping the node's *world* translation, so a child offset for
"the left end of the bar" would rotate with the wagon instead of facing the
camera. Encoding the fill in the image sidesteps it. Redraws only happen when a
value changes, which for ammo means per whole round.

**Rule: combat `Area3D`s must set `collision_layer = 0`.** `connections.gd` adds
*any* overlapping area to the track graph, so a detectable detector riding on a
wagon — or a shell flying over the rails — would silently inject junk nodes into
pathfinding. Both `TargetDetector` and `Projectile` do this in `_ready` and only
connect `body_*` signals, which is also why nav spheres (areas) are invisible to
them while wagons and the ground (bodies) are not.

The enemy is **not** registered as a pathfinding obstacle, so a train will
happily drive through it. That is the same gap as the general static-obstacle
work still open in step 5.

### Camera

[rts_camera.gd](scripts/rts_camera.gd) on a three-node rig:
`CameraPosition → CameraRotationX → CameraZoomPivot → Camera3D`. Everything lerps to
a target rather than moving directly. Zoom is the camera's local Z, clamped -20..20.

`Train.shoot_ray_from_mouse()` reaches the camera via
`camera_position_node.get_child(0).get_child(0).get_child(0)` — changing the rig
depth silently breaks picking.

### Input map

| Action | Binding |
|---|---|
| `left` / `right` / `up` / `down` | WASD pan |
| `rotate_left` / `rotate_right` | Q / E |
| `camera_zoom_in` / `camera_zoom_out` | mouse wheel |
| Ctrl held | A/D rotate instead of panning |
| `R` | defined in the input map, unused |

Select / command are hardcoded mouse buttons in `Train._input`, not input actions.

## Known rough edges

Don't treat these as bugs to fix unasked, but know they exist:

- **`track_pathfinding._process()` rebuilds the entire graph every frame.** It's the
  first thing to fix when track stops changing at runtime or when the network grows.
  Replace with an explicit rebuild call on track edits.
- `Vector3` dictionary keys mean float-exact matching. It works because keys always
  originate from the same dictionary, but any recomputed position will miss.
- `connections.gd` `_on_area_entered` adds a one-way link per area; bidirectionality
  depends on both areas detecting each other.
- `track_pathfinding.gd` carries a large commented-out JSON save/load block and an
  unused `find_closest_node()`; `connections.gd` has an unused `blink_blue()`.
- `sphere.tscn` (red, nav point) and `point.tscn` (blue, path marker) are
  near-duplicates of the same scene.
- Older docs/commits mention `find_path()` and `update_graph()` — those no longer
  exist.
- New `class_name` scripts are not visible to other scripts until the global
  class cache is rebuilt. `--headless --path . --quit` does **not** do it and
  will report bogus `Could not find type "X"` parse errors; run
  `--headless --editor --path . --quit` once after adding a `class_name`.
- `--check-only --script <file>` parses one file with no class cache, so it
  reports the same bogus errors for any script referencing another `class_name`.
  For those, the whole-project load is the real check.

## Working in this repo

- `.godot/` is gitignored; `.gitattributes` forces LF. Scene files are text, so
  `.tscn` merge conflicts are real and painful — prefer editing one scene per branch.
- Several parallel branches exist (`master`, `dev-gabri-navigation`,
  `dev-navigation-lemps-ai-assisted`, `dynamic-railway-experiment`). Confirm the
  intended target before merging.
- The project was recently upgraded 4.4 → 4.7 (`config/features` in `project.godot`).
  If something behaves oddly, engine-version drift is a plausible first suspect.
- Prefer editing `.gd` files directly; reserve `.tscn` edits for cases where the
  editor is genuinely needed, and let the user do node re-parenting in the GUI.
