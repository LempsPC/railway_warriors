# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Railway Warriors is a **Godot 4.4** 3D game featuring RTS-style train navigation with graph-based pathfinding. Trains navigate a rail network using Dijkstra's algorithm, with right-click destination selection via camera raycasting.

## Running the Project

This is a Godot 4.4 project with no external build system. All development happens through the Godot editor:

- **Open**: Launch Godot 4.4, open the project folder (`project.godot`)
- **Run**: Press `F5` in the editor, or use `godot --path . scenes/main.tscn` from CLI
- **Main scene**: `scenes/main.tscn` (configured in `project.godot`)

There are no unit tests, linting tools, or CI pipelines in this project.

## Architecture

### Core Systems

**Track Pathfinding** ([scripts/track_pathfinding.gd](scripts/track_pathfinding.gd))
- Runs on the floor panel node that parents all rail pieces
- Builds a weighted graph from `NavigationPoint` group members at scene load
- Implements Dijkstra's algorithm (`find_path(from, to)`) returning an ordered array of node names
- Visualizes paths using sphere marker nodes
- Call `update_graph()` to rebuild after dynamic scene changes

**Train Navigation** ([scripts/train_navigation.gd](scripts/train_navigation.gd))
- CharacterBody3D controller that moves along a computed path
- Right-click fires a raycast from the RTS camera to determine destination
- On hit, finds the nearest `NavigationPoint` and calls pathfinding, then follows the path array
- Uses acceleration and velocity smoothing for movement

**RTS Camera** ([scripts/rts_camera.gd](scripts/rts_camera.gd))
- WASD pan, Q/E rotation, mouse wheel zoom
- Zoom range: -20 to +20 (vertical offset)
- All movement uses `lerp` for smoothness

**Connection Detection** ([scripts/connections.gd](scripts/connections.gd))
- Area3D on each track segment's connection points
- Detects overlapping bodies to establish bidirectional links between track nodes
- Populates the graph that `track_pathfinding.gd` reads

### Scene Hierarchy

```
main.tscn
├── DirectionalLight3D
├── RTS_Camera.tscn        ← rts_camera.gd
├── FloorPanel             ← track_pathfinding.gd (parents all rail pieces)
│   ├── rail_straight.tscn
│   ├── rail_turn.tscn
│   ├── rail_junction_right.tscn
│   └── ...                (each piece has sphere.tscn connection points)
└── train.tscn             ← train_navigation.gd (exports: camera, pathfinding refs)
```

### Input Map

| Action | Key |
|--------|-----|
| Camera move | WASD |
| Camera rotate | Q / E |
| Camera zoom | Mouse wheel |
| Set destination | Right click |

### NavigationPoint Convention

Track pieces expose `NavigationPoint` nodes that must be added to the `NavigationPoint` group. The pathfinding system discovers all nodes in this group to build its graph. Connection nodes use `connections.gd` (Area3D) to detect adjacency and register edges.
