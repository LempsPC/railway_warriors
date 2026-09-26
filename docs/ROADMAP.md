# Railway Warriors — development roadmap

Lembitu's plan for how this game gets built. The step list below is the original;
the **Status** notes are maintained alongside the code and should be updated as
things land.

Reference point for the game itself: *Locoland*, but on a modern engine and running
well on modern hardware. 3D, Godot, GDScript.

---

## Step 1 — What game engine

*Mängumootori ja 2D või 3D valik.*

Game shall be 3D and engine is Godot, will be using GDScript.

**Status: done.** Godot 4.7, Forward+ renderer, GDScript only. No C#, no GDExtension.

---

## Step 2 — Team

Development team:

- Lembitu

**Status: done.** Solo project. Branches named after other people
(`dev-gabri-navigation`) exist from earlier experimentation.

---

## Step 3 — Budget

Extremely limited. Budget source: Lembitu.
Not planning to fund game development externally unless really needed
(like buying some 3D assets).

**Status: done — standing constraint.** Implications for day-to-day decisions:
prefer procedural/generated content over purchased assets, prefer engine built-ins
over paid plugins, and keep third-party dependencies at zero. The spline track
generator (`track_spline.gd`) is an example of the preferred direction — geometry
made in code rather than modelled and bought.

---

## Step 4 — Learning

Familiarizing with the game engine: Godot.
Each team member shall be able to develop simple concepts in Godot.

**MUST HAVE LIST TO DO BEFORE DEVELOPING:**

- Gamedev course (8 hours): https://www.youtube.com/watch?v=TLG2yVpLDT8
- Develop helpdesk simulator in its purest form
- Demo your game on gamedev meeting or Lapikud software team meeting

**Status: done.** Lembitu has completed these.

---

## Step 5 — Start developing core concepts

**← current step.**

Core concepts, each proven individually before being combined:

| Concept | Status | Where |
|---|---|---|
| Pathfinding via tracks | **done** | `track_pathfinding.gd` — Dijkstra over a position-keyed graph |
| Movement via railways | **done** | `train_navigation.gd` — shared arc-length polyline |
| Coupling and decoupling on tracks | **done** | `train_navigation.gd` — attach/detach, drive-to-couple |
| Static objects (obstacles) | **partial** | Detached wagons block graph edges within `OBSTACLE_RADIUS`; no general static-obstacle type yet |
| Ballistics | **done** | `projectile.gd` — lobbed arc, damages a `Health` component |
| Enemy detection | **done** | `target_detector.gd` — `Area3D` range, nominates the nearest hostile |
| HP and ammo system | **done** | `health.gd` (hp, factions, death), `ammo.gd` (per-unit magazine), `ammo_supply.gd` (resupply) |

The last three landed together as a single **combat vertical slice**: an armed
wagon detects a target, fires, and the target takes damage and dies. They were
bundled rather than proven one at a time because they are not separable even in
principle — HP has nothing to test against without a damage source, and
ballistics has nothing meaningful to hit without HP. That is a departure from
"prove each concept individually", which still holds for genuinely independent
concepts like pathfinding vs. coupling.

`origin/ballistics` stays unmerged and should now be treated as **reference
material only**. It is a standalone Godot project of ~60 lines; the combat code
in the main project was written fresh, keeping only the parabola from
`bullet.init_movement()`. There is nothing left there worth merging, and no
reason to reconcile the two `project.godot` files.

Also worth trying: *teha tower defence simulator* — build a tower defence
simulator as a concept exercise.

Current side-quest not in the original list: **generated track**. `track_spline.gd`
(`@tool`, on the `dynamic-railway-experiment` branch) builds rail mesh and
navigation points from a `Curve3D`, aiming to replace hand-placed rail pieces.

### Ammo model

Decided after the combat slice landed, and now implemented:

- **Every unit carries its own ammo**, armed or not. Ammo is a property of the
  rail unit, not of the gun bolted to it.
- **Every rail unit shows a health bar**; units that can shoot also show an ammo
  bar.
- **A depleted unit is restocked** either at a repair depot — *not implemented*,
  see step 8 — or by an **ammo wagon**, which slowly and infinitely refills
  every friendly unit in range.

Two judgement calls worth knowing about, either of which is cheap to change:

1. *"Refills all ammo"* is implemented as a **radius**, not as "everything
   coupled to me". A 12 m `supply_range` covers a coupled train anyway, and it
   also resupplies friendly units simply parked alongside, so one rule serves
   both readings without a separate coupling check.
2. Unarmed wagons still hold rounds they cannot personally spend. That follows
   the rule literally — they are carrying cargo — and gives a later transfer or
   depot mechanic something to move around.

The repair depot is the obvious next consumer: `AmmoSupply` is a plain component
that mounts on any node, so a depot is a static building with one attached, not
new code.

### Suggested next moves

1. The **repair depot** — the other half of the resupply rule, and the first
   static building. Mostly an `AmmoSupply` on a placed node plus whatever
   repairs hit points.
2. A real static obstacle representation, replacing the special-cased
   parked-wagon radius check. The new enemy unit has the same gap — it is not a
   pathfinding obstacle, so trains drive straight through it.
3. Move selection and commands out of `Train._input` into their own system.
   It is the blocker for a second controllable train, and combat makes a second
   train the obvious next thing to want.
4. Stop rebuilding the whole nav graph in `track_pathfinding._process()`. It is
   now the dominant per-frame cost in the scene.
5. Give the enemy a reason to shoot back — the `Weapon` scene mounts on an enemy
   unit unchanged, and the enemy already carries `Ammo`, so this is mostly
   step 9 (AI) rather than new combat code.

---

## Step 6 — Simulate

When core concepts are individually feasible, put them all together and start
simulating different scenarios.

**Status: not started.** Blocked on step 5.

---

## Step 7 — Low-level testing

Make a series of unit tests for each core concept and unit in the game. Unit tests
have to simulate almost any possible scenario with the unit.

**Status: not started.** The repo has no test framework today. When this step
begins, GUT or gdUnit4 are the usual GDScript choices — pick one deliberately
rather than accreting ad-hoc test scenes.

Note that several core systems are currently hard to test in isolation, which is
worth keeping in mind while writing step-5 code:

- `track_pathfinding` reads the live scene tree rather than taking a graph as input
- `Train` owns its own mouse input and raycasting (there is a `TODO` about this)

---

## Step 8 — Add items to make it a game

Add items such as:

- UI
- Menus
- Interfacing with trains
- Most main game items — trains, wagons, weapons, depots, etc.

**Status: not started**, with two pieces already leaning on it. The **repair
depot** is specified (restock ammo, repair damage) but unbuilt; `AmmoSupply` is
the component it will mount. Health and ammo currently read as floating bars
over each unit rather than through any UI layer.

---

## Step 9 — AI

Make the enemy do enemy things.

**Status: not started.** `enemy_wagon.tscn` exists as a deliberately brainless
target for the combat slice — hit points and a collider, no behaviour. Two
shortcuts in the combat code are explicitly deferred to this step: the enemy
does not move or shoot back, and `Projectile` tracks its target in flight
instead of leading it, because leading needs to know the target's velocity.

---

## Step 10 — Multiplayer?

Add a multiplayer port. Start with local LAN, then make it smarter.

**Status: not started.** Open question, hence the "?".
