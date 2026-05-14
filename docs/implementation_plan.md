# Gatewalk Implementation Plan

## 1) Stabilize Current Bugs First
- Free old `sun_light` when rebuilding environment.
- Add `arctic_explorer` to `DiscoveryTracker.ACHIEVEMENT_DEFS`.
- Fix moon shrine count mismatch (spawn 9 or require 8).
- Remove or disable orb collisions after collection.
- Make fallen-player recovery use current map spawn logic and reset velocity.
- Decide water-map direction explicitly (recommended: enable).

## 2) Add Deterministic Regression Checks
- Add seed-based generation checks for normal, arctic, moon, cave, water, gate room, and nexus maps.
- Track stable counts and position hashes for major generated objects.
- Verify deterministic terrain sampling, gate targets, wonders, and scatter placements.
- Add save migration checks covering multi-universe state.

## 3) Introduce `MapContext`
- Create a shared runtime context with seed, map type, settings, noise, grid/cell sizing, water level, and height/routing callables.
- Route map generation, factories, spawn logic, gate placement, wonders, and HUD through this shared context.

## 4) Remove Duplicate Terrain Logic
- Eliminate terrain/river/biome duplication in `Main.gd`.
- Make all procedural placement query one authoritative terrain source from `MapContext`.
- Pass context objects to factories instead of piecemeal callbacks/constants.

## 5) Create `GameSession`
- Extract universe/world/map lifecycle from `Main.gd` into a dedicated session service.
- Centralize slot save/load, universe selection, world selection, and settings lookup/update.

## 6) Harden `SaveManager`
- Normalize all universes, not just current.
- Repair stale/missing `current_universe_id` deterministically.
- Validate required universe/world/map schema fields.
- Keep versioned migrations explicit and test-covered.

## 7) Finish Typed Records
- Use typed runtime records (`UniverseRecord`, `WorldRecord`, `MapRecord`, `DiscoveryRecord`, `GateLink`) internally.
- Convert to dictionary format only at save/load boundaries.
- Add and use `from_dict()` constructors consistently.

## 8) Extract `MapRuntimeController`
- Move map clear/build/load lifecycle from `Main.gd` into a dedicated controller.
- Own generated root creation, generator invocation, player spawn, factory attach, and map-discovery accounting.

## 9) Extract `EnvironmentController`
- Isolate sky/sun/fog/day-night behavior from `Main.gd`.
- Ensure clean light/environment lifecycle across map transitions.

## 10) Extract `GateTravelService`
- Own gate destination creation, persistence, and reroute rules.
- Make route-type probabilities/config centralized.
- Keep gate graph behavior deterministic and testable.

## 11) Make Gate Design Intentional
- Persist unique gate destinations unless explicitly linked.
- Expose route state (unknown/known/special/inert/return) to visuals and atlas.
- Ensure special map routing is deterministic per gate/source map.

## 12) Extract `DiscoveryService`
- Centralize discovery registration, pin management, achievements, and completion checks.
- Keep discovery logic decoupled from scene construction.

## 13) Refactor Factories Around Context
- Update major factories (`TreeFactory`, `RockFactory`, `GateFactory`, wonder flow) to consume `MapContext`.
- Return structured metadata for discovery/collision/minimap integration where needed.

## 14) Replace Broad Auto-Collision
- Phase out global loose-mesh auto-collision.
- Move collision ownership to factories and authored structures.
- Keep only intentional collision on interactive/solid assets.

## 15) Rebuild Water Maps as a Real Feature
- Keep water maps in route generation.
- Implement distinct water-map traversal/discovery loops.
- Align achievements, atlas, and audio/FX with actual water-map behavior.

## 16) Make Map Types Mechanically Distinct
- Normal: surveying and wonder routing.
- Arctic: visibility/warmth/aurora navigation pressures.
- Cave: light-limited traversal and glyph-based navigation.
- Moon: low-gravity shrine progression with lichen utility.
- Water: depth/breath/island-underwater exploration.
- Gate room/nexus: meaningful strategic hub behavior.

## 17) Upgrade Pins and Surveying
- Add pin categories and labels.
- Sync pins across minimap and atlas.
- Add active survey interaction for landmarks/gates/wonders.

## 18) Improve Progression
- Tie discoveries to practical upgrades (atlas detail, gate previews, pin capacity, breath, flashlight, traversal tools).
- Ensure progression improves navigation decision quality.

## 19) Expand Journal and Atlas Utility
- Add per-map completion, route history, gate state, and pin tracking surfaces.
- Provide clear world and universe-level completion summaries.

## 20) Lay Performance Groundwork
- Move dense scatter objects toward `MultiMeshInstance3D`.
- Reduce per-instance mesh/material churn.
- Defer generation batches over frames and add loading overlay.
- Improve collision efficiency by reducing broad fallback generation.

## 21) Update Documentation
- Refresh controls, universe/world/map model docs, map-type behavior, save schema, determinism rules, and architecture notes.

## 22) Final Validation Pass
- Run headless project import/init checks.
- Run deterministic generation checks and save migration tests.
- Perform manual smoke tests through all map types and universe switching.
