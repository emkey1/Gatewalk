extends RefCounted
class_name SkyscraperFactory

# A sealed Empire-State-scale tower, floating in space: a tall square prism with big open
# office floors, a compact central stairwell connecting every storey, structural columns on a
# grid, and a glass curtain wall on all four faces. The glass is collidable, so you can see the
# void outside but not leave it. Four gates are scattered across the floors (your way out); one
# is always low so you can leave without a marathon climb.

const StableRng = preload("res://scripts/core/StableRng.gd")
const MultiMeshScatter = preload("res://scripts/factories/MultiMeshScatter.gd")

const FOOTPRINT: float = 120.0     # square plan side (~Empire State base)
const STORIES: int = 50            # 50 storeys -> ~200 m tall: clearly a tower at 120 m wide
const STORY_H: float = 4.0         # commercial floor-to-floor; clears the switchback headroom
const TH: float = 0.3              # slab / wall thickness

const STAIR_HALF: float = 2.5      # central stairwell is 5 m x 5 m
const STAIR_LAND_D: float = 1.4    # depth of the half-landing
const STAIR_STEPS: int = 6         # steps per flight -> ~0.33 m rise, ~0.45 m run (a real stair)

const COL_SIZE: float = 0.7        # structural column side
const COL_GRID: float = 20.0       # column spacing

const DOOR_HALF: float = 2.5       # ground-floor exit doorway half-width (in the +z glass)
const DOOR_H: float = 3.2          # exit doorway height
const WORLD_R: float = 340.0       # inner grass sphere radius; centre at (0, WORLD_R, 0), bottom y=0
const GLOBE_R: float = 13.0        # globe-sun radius (sits on the roof)


# Build the tower into `parent`. Returns an Array of 4 gate world-positions (scattered across
# the floors; gate 0 is on a low storey near the arrival point).
static func build(parent: Node3D, world_seed: int) -> Array:
	var root := Node3D.new()
	root.name = "Skyscraper"
	parent.add_child(root)
	var rng := StableRng.new(StableRng.mix_string(world_seed, "skyscraper", 1))

	var half: float = FOOTPRINT * 0.5
	var top_y: float = float(STORIES) * STORY_H

	var concrete := _mat(Color(0.60, 0.60, 0.63), 0.92, 0.0)
	var floor_mat := _mat(Color(0.46, 0.47, 0.50), 0.85, 0.0)
	var core_mat := _mat(Color(0.52, 0.53, 0.56), 0.88, 0.0)
	var col_mat := _mat(Color(0.40, 0.41, 0.45), 0.8, 0.05)
	var trim := _mat(Color(0.30, 0.31, 0.34), 0.6, 0.0)   # dark mullions
	var glass := _glass_mat()

	# --- Envelope: always-drawn full-height geometry (stair shaft walls, columns, glass). It's
	# few pieces and the opaque slabs occlude all but the player's storey of it anyway. ---
	var env := Node3D.new()
	env.name = "Envelope"
	root.add_child(env)
	_stair_walls(env, top_y, core_mat)
	_columns(env, half, top_y, col_mat)
	# Glass curtain, grouped so Main can flip the whole envelope clear<->opaque. The +z face
	# carries a ground-floor doorway out to the grassland.
	var glass_group := Node3D.new()
	glass_group.name = "Glass"
	env.add_child(glass_group)
	_glass_face(glass_group, true, half, half, top_y, glass, trim, DOOR_HALF)
	_glass_face(glass_group, true, -half, half, top_y, glass, trim, 0.0)
	_glass_face(glass_group, false, half, half, top_y, glass, trim, 0.0)
	_glass_face(glass_group, false, -half, half, top_y, glass, trim, 0.0)

	# --- Per-storey groups (Floor_<n>) so Main can hide every storey except the player's: with
	# opaque windows you can never see another floor, so only one needs to draw. Floor_n carries
	# the slab at y=n*H, the stair climbing out of it, and (later) its office fit-out. ---
	var floors: Array = []
	for n in range(STORIES + 1):
		var fl := Node3D.new()
		fl.name = "Floor_" + str(n)
		root.add_child(fl)
		floors.append(fl)
	_box(floors[0], Vector3(0.0, -TH * 0.5, 0.0), Vector3(FOOTPRINT + 1.0, TH, FOOTPRINT + 1.0), concrete, true)
	# Roof goes in the always-drawn Envelope, not a per-storey group: the floors get culled when
	# you step outside, and a culled roof left the tower looking open-topped and hollow from the grass.
	# It's a walkable observation deck — hatch over the stairwell, a bulkhead, and a glass parapet.
	_build_roof_deck(env, half, top_y, concrete, core_mat)
	for f in range(1, STORIES):
		_floor_slab(floors[f], half, float(f) * STORY_H, floor_mat)
	for f in range(STORIES):
		_ustair(floors[f], float(f) * STORY_H, float(f + 1) * STORY_H, core_mat)
		_furnish_floor(floors[f], half, float(f) * STORY_H, world_seed, f)
	# Rooftop rec deck. Goes in the top-floor cull group so it only draws when you're up top.
	_build_rooftop_courts(floors[STORIES], top_y)

	# --- The world outside the glass: a domed grassland terrarium lit by a globe-sun on the
	# roof (Main runs its day/night). Always drawn; the opaque-from-outside glass lets Main hide
	# the whole interior while you're out here. ---
	_build_outside(root, world_seed, half, top_y)

	# --- Four gates scattered across the floors. Gate 0 sits low (near the arrival spot) so the
	# player can always leave without a marathon climb; the rest are spread higher. ---
	var gates: Array = []
	var floors_used: Array = []
	for gi in range(4):
		var gf: int = rng.randi_range(1, 4) if gi == 0 else rng.randi_range(5, STORIES - 2)
		var tries: int = 0
		while floors_used.has(gf) and tries < 16:
			gf = rng.randi_range(1, STORIES - 2)
			tries += 1
		floors_used.append(gf)
		var r: float = rng.randf_range(half * 0.32, half * 0.82)   # clear of the core and the glass
		var ang: float = rng.randf_range(0.0, TAU)
		gates.append(Vector3(r * cos(ang), float(gf) * STORY_H + 0.05, r * sin(ang)))
	return gates


# --- Full floor plate minus the central stairwell hole: four strips around it. ------------
static func _floor_slab(parent: Node3D, half: float, fy: float, mat: Material) -> void:
	var fcy: float = fy - TH * 0.5   # top surface at fy
	var sh: float = STAIR_HALF
	var span: float = half - sh
	# front (+z) and back (-z) full-width strips
	_box(parent, Vector3(0.0, fcy, (sh + half) * 0.5), Vector3(FOOTPRINT, TH, span), mat, true)
	_box(parent, Vector3(0.0, fcy, -(sh + half) * 0.5), Vector3(FOOTPRINT, TH, span), mat, true)
	# left (-x) and right (+x) strips spanning the stairwell's depth
	_box(parent, Vector3((sh + half) * 0.5, fcy, 0.0), Vector3(span, TH, sh * 2.0), mat, true)
	_box(parent, Vector3(-(sh + half) * 0.5, fcy, 0.0), Vector3(span, TH, sh * 2.0), mat, true)


# --- Walkable rooftop observation deck. The top flight of the central stair already climbs to
# roof level; we carve a matching hatch through the roof slab, cap it with a short stair bulkhead
# you step out of, and ring the perimeter with a tall glass parapet — see out over the grassland,
# but no falling or jumping off. ---------------------------------------------------------------
static func _build_roof_deck(parent: Node3D, half: float, top_y: float, concrete: Material, core_mat: Material) -> void:
	# Roof slab with the central stairwell hatch (same 4-strip carve as every floor slab), so the
	# top flight emerges onto the deck instead of dead-ending under a solid roof.
	_floor_slab(parent, half, top_y, concrete)

	# Parapet around the perimeter: a solid knee-high kerb (thick, so a fast run can't clip through
	# at the very edge) topped by clear glass to 3 m total — above the ~2 m jump apex, so it stops a
	# running jump as well as a walk-off. The glass has its own material (not the shared curtain
	# wall), so it stays clear when Main flips the windows opaque from outside. Main also backstops
	# any edge clip that does slip past.
	var rail := _glass_mat_clear()
	var kerb_t: float = 0.6
	var kh: float = 0.8
	var kcy: float = top_y + kh * 0.5
	var gh: float = 2.2
	var gcy: float = top_y + kh + gh * 0.5
	for side in [Vector3(0.0, 0.0, half), Vector3(0.0, 0.0, -half), Vector3(half, 0.0, 0.0), Vector3(-half, 0.0, 0.0)]:
		var along_z: bool = absf(side.x) > 0.5
		var ksize: Vector3 = Vector3(kerb_t, kh, FOOTPRINT) if along_z else Vector3(FOOTPRINT, kh, kerb_t)
		var gsize: Vector3 = Vector3(TH, gh, FOOTPRINT) if along_z else Vector3(FOOTPRINT, gh, TH)
		_box(parent, Vector3(side.x, kcy, side.z), ksize, concrete, true)
		_box(parent, Vector3(side.x, gcy, side.z), gsize, rail, true)

	# Stair bulkhead capping the hatch: back + side walls and a cap, open on +z where the stair
	# tops out, so you walk straight out of the stairwell onto the deck.
	var sh: float = STAIR_HALF
	var bh: float = 3.0
	var bcy: float = top_y + bh * 0.5
	_box(parent, Vector3(0.0, bcy, -sh - TH * 0.5), Vector3(sh * 2.0 + TH * 2.0, bh, TH), core_mat, true)
	_box(parent, Vector3(-sh - TH * 0.5, bcy, 0.0), Vector3(TH, bh, sh * 2.0), core_mat, true)
	_box(parent, Vector3(sh + TH * 0.5, bcy, 0.0), Vector3(TH, bh, sh * 2.0), core_mat, true)
	_box(parent, Vector3(0.0, top_y + bh + TH * 0.5, 0.0), Vector3(sh * 2.0 + TH * 2.0, TH, sh * 2.0 + TH * 2.0), concrete, true)


# --- Rooftop rec deck: tennis, pickleball and shuffleboard courts painted on the deck (flat colour
# panels + white lines + nets). Fixed, non-overlapping layout (deterministic): two tennis (+x), two
# pickleball (-x), two shuffleboard (far -x), all clear of the central bulkhead and the parapet. ---
static func _build_rooftop_courts(parent: Node3D, top_y: float) -> void:
	var line := _mat(Color(0.95, 0.96, 0.97), 0.5, 0.0)
	var net_mat := _mat(Color(0.10, 0.11, 0.13), 0.8, 0.0)
	var post_mat := _mat(Color(0.22, 0.23, 0.26), 0.5, 0.4)
	var tennis := _mat(Color(0.17, 0.43, 0.31), 0.92, 0.0)   # green
	var pickle := _mat(Color(0.15, 0.33, 0.60), 0.92, 0.0)   # blue
	var shuffle := _mat(Color(0.72, 0.45, 0.30), 0.93, 0.0)  # terracotta
	_racquet_court(parent, top_y, 24.0, 15.0, 23.8, 11.0, 1.07, tennis, line, net_mat, post_mat)
	_racquet_court(parent, top_y, 24.0, -15.0, 23.8, 11.0, 1.07, tennis, line, net_mat, post_mat)
	_racquet_court(parent, top_y, -22.0, 13.0, 13.4, 6.1, 0.86, pickle, line, net_mat, post_mat)
	_racquet_court(parent, top_y, -22.0, -13.0, 13.4, 6.1, 0.86, pickle, line, net_mat, post_mat)
	# Regulation scale: tennis 23.77x10.97, pickleball 13.41x6.10, shuffleboard 12.2x1.83.
	_shuffleboard_court(parent, top_y, -46.0, 14.0, 1.9, 12.2, shuffle, line)
	_shuffleboard_court(parent, top_y, -46.0, -14.0, 1.9, 12.2, shuffle, line)
	# Courtside furniture, each oriented to face the court (or pool) it serves.
	_umpire_chair(parent, top_y, 24.0, 21.8, -1.0)   # +z tennis court is to its -z
	_umpire_chair(parent, top_y, 24.0, -21.8, 1.0)   # -z tennis court is to its +z
	_court_bench(parent, top_y, 9.0, 15.0, false, 1.0)     # tennis courts at +x
	_court_bench(parent, top_y, 9.0, -15.0, false, 1.0)
	_court_bench(parent, top_y, -13.0, 13.0, false, -1.0)  # pickleball courts at -x
	_court_bench(parent, top_y, -13.0, -13.0, false, -1.0)
	# Pool, hot tub & sauna lounge on the open far -z deck (basins sit entirely above the roof).
	_pool(parent, top_y, -4.0, -38.0, 18.0, 14.0)
	_hot_tub(parent, top_y, 9.0, -38.0)
	_sauna(parent, top_y, 16.0, -38.0)
	_lounger(parent, top_y, -12.0, -28.0, -1.0)   # face -z toward the pool
	_lounger(parent, top_y, -6.0, -28.0, -1.0)
	_lounger(parent, top_y, 0.0, -28.0, -1.0)
	_lounger(parent, top_y, 6.0, -28.0, -1.0)
	_umbrella(parent, top_y, -9.0, -28.0)
	_umbrella(parent, top_y, 3.0, -28.0)


# A flat colour court surface, lifted just above the deck slab to avoid z-fighting.
static func _court_panel(parent: Node3D, cx: float, cz: float, w: float, d: float, top_y: float, surf: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, 0.04, d)
	mi.mesh = bm
	mi.position = Vector3(cx, top_y + 0.03, cz)
	mi.material_override = surf
	parent.add_child(mi)


# A thin white marking just above the surface. horizontal: spans x (length=len); else spans z.
static func _court_line(parent: Node3D, cx: float, cz: float, length: float, top_y: float, horizontal: bool, mat: Material) -> void:
	var lw: float = 0.13
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(length, 0.02, lw) if horizontal else Vector3(lw, 0.02, length)
	mi.mesh = bm
	mi.position = Vector3(cx, top_y + 0.06, cz)
	mi.material_override = mat
	parent.add_child(mi)


# Tennis/pickleball court: surface + boundary + centre line + a walk-through net between two posts.
static func _racquet_court(parent: Node3D, top_y: float, cx: float, cz: float, w: float, d: float, net_h: float, surf: Material, line: Material, net_mat: Material, post_mat: Material) -> void:
	_court_panel(parent, cx, cz, w, d, top_y, surf)
	var hw: float = w * 0.5
	var hd: float = d * 0.5
	_court_line(parent, cx, cz + hd, w, top_y, true, line)
	_court_line(parent, cx, cz - hd, w, top_y, true, line)
	_court_line(parent, cx + hw, cz, d, top_y, false, line)
	_court_line(parent, cx - hw, cz, d, top_y, false, line)
	_court_line(parent, cx, cz, w * 0.62, top_y, true, line)   # centre service line
	# Net across the width at mid-length: a thin walk-through panel between two solid posts.
	_box(parent, Vector3(cx, top_y + net_h * 0.5, cz), Vector3(0.06, net_h, d), net_mat, false)
	_box(parent, Vector3(cx, top_y + (net_h + 0.1) * 0.5, cz + hd), Vector3(0.14, net_h + 0.1, 0.14), post_mat, true)
	_box(parent, Vector3(cx, top_y + (net_h + 0.1) * 0.5, cz - hd), Vector3(0.14, net_h + 0.1, 0.14), post_mat, true)


# Shuffleboard court: long narrow surface + boundary + scoring divisions near each end (no net).
static func _shuffleboard_court(parent: Node3D, top_y: float, cx: float, cz: float, w: float, d: float, surf: Material, line: Material) -> void:
	_court_panel(parent, cx, cz, w, d, top_y, surf)
	var hw: float = w * 0.5
	var hd: float = d * 0.5
	_court_line(parent, cx, cz + hd, w, top_y, true, line)
	_court_line(parent, cx, cz - hd, w, top_y, true, line)
	_court_line(parent, cx + hw, cz, d, top_y, false, line)
	_court_line(parent, cx - hw, cz, d, top_y, false, line)
	for zz in [cz + hd - 1.8, cz + hd - 3.2, cz - hd + 1.8, cz - hd + 3.2]:
		_court_line(parent, cx, zz, w, top_y, true, line)


# A simple park bench (seat + backrest + end legs). along_x: bench runs along x; else along z.
# face: which way the sitter looks — +-z if along_x, else +-x — so it can face its court.
static func _court_bench(parent: Node3D, top_y: float, cx: float, cz: float, along_x: bool, face: float) -> void:
	var wood := _mat(Color(0.46, 0.34, 0.22), 0.9, 0.0)
	var sl: float = 1.8
	var sx: float = sl if along_x else 0.5
	var sz: float = 0.5 if along_x else sl
	_box(parent, Vector3(cx, top_y + 0.45, cz), Vector3(sx, 0.1, sz), wood, true)
	var back: Vector3 = Vector3(sl, 0.5, 0.1) if along_x else Vector3(0.1, 0.5, sl)
	var bdx: float = 0.0 if along_x else -0.2 * face
	var bdz: float = -0.2 * face if along_x else 0.0
	_box(parent, Vector3(cx + bdx, top_y + 0.75, cz + bdz), back, wood, true)
	for s in [-1.0, 1.0]:
		var lx: float = cx + (s * sl * 0.4 if along_x else 0.0)
		var lz: float = cz + (0.0 if along_x else s * sl * 0.4)
		_box(parent, Vector3(lx, top_y + 0.225, lz), Vector3(0.1, 0.45, 0.1), wood, true)


# Tall tennis umpire chair: four legs up to a seat ~1.8 m, a seat, a backrest, and climb rungs.
# face: +-z the umpire looks; the backrest and rungs go on the opposite (back) side.
static func _umpire_chair(parent: Node3D, top_y: float, cx: float, cz: float, face: float) -> void:
	var metal := _mat(Color(0.55, 0.56, 0.60), 0.5, 0.5)
	var seat := _mat(Color(0.20, 0.30, 0.55), 0.8, 0.0)
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			_box(parent, Vector3(cx + sx, top_y + 0.9, cz + sz), Vector3(0.1, 1.8, 0.1), metal, true)
	_box(parent, Vector3(cx, top_y + 1.8, cz), Vector3(1.3, 0.12, 1.0), seat, true)
	_box(parent, Vector3(cx, top_y + 2.2, cz - 0.45 * face), Vector3(1.3, 0.8, 0.12), seat, true)
	for i in range(3):
		_box(parent, Vector3(cx, top_y + 0.5 + 0.4 * float(i), cz - 0.5 * face), Vector3(1.0, 0.06, 0.06), metal, true)


# Poolside sun lounger: a padded deck on short legs with a raised head section. face: +-z the
# recliner looks (head end at the opposite side), so it can face the pool.
static func _lounger(parent: Node3D, top_y: float, cx: float, cz: float, face: float) -> void:
	var frame := _mat(Color(0.85, 0.86, 0.88), 0.6, 0.2)
	var pad := _mat(Color(0.90, 0.55, 0.30), 0.9, 0.0)
	_box(parent, Vector3(cx, top_y + 0.3, cz), Vector3(0.7, 0.08, 1.9), pad, true)
	_box(parent, Vector3(cx, top_y + 0.55, cz - 0.75 * face), Vector3(0.7, 0.08, 0.5), pad, true)
	for s in [-1.0, 1.0]:
		_box(parent, Vector3(cx + s * 0.3, top_y + 0.13, cz), Vector3(0.06, 0.26, 1.7), frame, true)


# Patio umbrella: a centre pole with a two-tier canopy for shade.
static func _umbrella(parent: Node3D, top_y: float, cx: float, cz: float) -> void:
	var pole := _mat(Color(0.5, 0.5, 0.52), 0.5, 0.4)
	var canopy := _mat(Color(0.90, 0.40, 0.30), 0.9, 0.0)
	_box(parent, Vector3(cx, top_y + 1.2, cz), Vector3(0.12, 2.4, 0.12), pole, true)
	_box(parent, Vector3(cx, top_y + 2.45, cz), Vector3(3.2, 0.1, 3.2), canopy, false)
	_box(parent, Vector3(cx, top_y + 2.55, cz), Vector3(1.8, 0.1, 1.8), canopy, false)


# Above-ground swimming pool: a walled basin standing ON the roof — every part sits at or above
# top_y, so nothing dips into the storey below. Walls + tiled floor + contained water + coping rim
# + entry steps.
static func _pool(parent: Node3D, top_y: float, cx: float, cz: float, w: float, d: float) -> void:
	var wall := _mat(Color(0.86, 0.88, 0.90), 0.6, 0.05)
	var tile := _mat(Color(0.34, 0.66, 0.80), 0.4, 0.1)
	var coping := _mat(Color(0.80, 0.81, 0.84), 0.6, 0.0)
	var water := _pool_water_mat(false)
	var wh: float = 0.95
	var t: float = 0.25
	var hw: float = w * 0.5
	var hd: float = d * 0.5
	_box(parent, Vector3(cx, top_y + wh * 0.5, cz + hd), Vector3(w + t * 2.0, wh, t), wall, true)
	_box(parent, Vector3(cx, top_y + wh * 0.5, cz - hd), Vector3(w + t * 2.0, wh, t), wall, true)
	_box(parent, Vector3(cx + hw, top_y + wh * 0.5, cz), Vector3(t, wh, d), wall, true)
	_box(parent, Vector3(cx - hw, top_y + wh * 0.5, cz), Vector3(t, wh, d), wall, true)
	# Tiled floor + contained water, both above the roof (water bottom at top_y+0.1).
	_box(parent, Vector3(cx, top_y + 0.06, cz), Vector3(w, 0.08, d), tile, false)
	var wm := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w - 0.06, wh - 0.25, d - 0.06)
	wm.mesh = bm
	wm.position = Vector3(cx, top_y + 0.1 + (wh - 0.25) * 0.5, cz)
	wm.material_override = water
	parent.add_child(wm)
	# Coping rim around the top of the walls.
	_box(parent, Vector3(cx, top_y + wh + 0.04, cz + hd), Vector3(w + t * 2.4, 0.08, t * 1.8), coping, false)
	_box(parent, Vector3(cx, top_y + wh + 0.04, cz - hd), Vector3(w + t * 2.4, 0.08, t * 1.8), coping, false)
	_box(parent, Vector3(cx + hw, top_y + wh + 0.04, cz), Vector3(t * 1.8, 0.08, d + t * 2.4), coping, false)
	_box(parent, Vector3(cx - hw, top_y + wh + 0.04, cz), Vector3(t * 1.8, 0.08, d + t * 2.4), coping, false)
	# Entry steps up the outside of the +z wall.
	for i in range(3):
		_box(parent, Vector3(cx, top_y + 0.18 + 0.18 * float(i), cz + hd + 0.6 - 0.35 * float(i)), Vector3(1.6, 0.18, 0.45), coping, true)


# Rooftop sauna cabin: a small wood hut with a door facing the pool deck, a roof, an interior bench,
# a glowing window and a stovepipe.
static func _sauna(parent: Node3D, top_y: float, cx: float, cz: float) -> void:
	var wood := _mat(Color(0.44, 0.31, 0.20), 0.9, 0.0)
	var roof_mat := _mat(Color(0.33, 0.23, 0.15), 0.9, 0.0)
	var w: float = 5.5
	var d: float = 5.0
	var h: float = 2.4
	_room(parent, cx, cz, w, d, top_y, h, 0, wood, 1.3)
	_box(parent, Vector3(cx, top_y + h + 0.12, cz), Vector3(w + 0.5, 0.24, d + 0.5), roof_mat, true)
	_box(parent, Vector3(cx, top_y + 0.45, cz - d * 0.5 + 0.6), Vector3(w - 1.2, 0.12, 0.9), wood, true)
	_box(parent, Vector3(cx + w * 0.5 - 0.7, top_y + h + 0.8, cz - 1.0), Vector3(0.3, 1.4, 0.3), _mat(Color(0.22, 0.22, 0.24), 0.5, 0.5), true)
	var glow := _emissive_mat(Color(1.0, 0.62, 0.28))
	var win := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, 0.9, 0.06)
	win.mesh = bm
	win.position = Vector3(cx + 1.5, top_y + 1.3, cz + d * 0.5)
	win.material_override = glow
	parent.add_child(win)


# Translucent, glossy water — see the basin floor through it and a sheen on the surface, so it
# reads as water rather than a solid block. warm: a hot-tub tint with a faint heated glow.
static func _pool_water_mat(warm: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.30, 0.60, 0.64, 0.42) if warm else Color(0.22, 0.55, 0.76, 0.36)
	m.roughness = 0.03
	m.metallic = 0.0
	if warm:
		m.emission_enabled = true
		m.emission = Color(0.45, 0.32, 0.18)
		m.emission_energy_multiplier = 0.5
	return m


# A cylinder mesh (+ optional cylinder collision), for round props like the hot tub.
static func _cyl(parent: Node3D, center: Vector3, radius: float, height: float, mat: Material, collide: bool) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = mat
	if collide:
		var body := StaticBody3D.new()
		body.position = center
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = radius
		sh.height = height
		cs.shape = sh
		body.add_child(cs)
		parent.add_child(body)
	else:
		mi.position = center
		parent.add_child(mi)


# A circle of box segments — a hollow round wall (so you can see down into a basin, unlike a solid
# cylinder which would cap it). cy is the segment centre height; each box is tangent to the circle.
static func _ring_segments(parent: Node3D, cx: float, cz: float, cy: float, radius: float, height: float, depth: float, mat: Material, collide: bool) -> void:
	var seg: int = 16
	var seg_w: float = radius * TAU / float(seg) * 1.25   # slight overlap so the ring is closed
	for i in range(seg):
		var a: float = TAU * float(i) / float(seg)
		var pos := Vector3(cx + cos(a) * radius, cy, cz + sin(a) * radius)
		_oriented_box(parent, pos, Vector3(seg_w, height, depth), PI * 0.5 - a, mat, collide)


# A box with a Y rotation (the plain _box is axis-aligned). Used for ring-wall segments.
static func _oriented_box(parent: Node3D, center: Vector3, size: Vector3, yaw: float, mat: Material, collide: bool) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	if collide:
		var body := StaticBody3D.new()
		body.position = center
		body.rotation.y = yaw
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		body.add_child(cs)
		parent.add_child(body)
	else:
		mi.position = center
		mi.rotation.y = yaw
		parent.add_child(mi)


# Round above-ground hot tub: a HOLLOW basin (ring-wall sides + tiled floor + contained warm water
# below a wood lip) so you see the water rather than a solid cap, plus a warm glow and mist puffs.
static func _hot_tub(parent: Node3D, top_y: float, cx: float, cz: float) -> void:
	var cedar := _mat(Color(0.45, 0.30, 0.20), 0.85, 0.0)
	var lip_mat := _mat(Color(0.54, 0.42, 0.30), 0.7, 0.0)
	var tile := _mat(Color(0.32, 0.56, 0.62), 0.4, 0.1)
	var water := _pool_water_mat(true)
	var r: float = 1.7
	var wall_h: float = 0.9
	_ring_segments(parent, cx, cz, top_y + wall_h * 0.5, r, wall_h, 0.2, cedar, true)        # tub wall (collidable)
	_ring_segments(parent, cx, cz, top_y + wall_h - 0.05, r, 0.14, 0.36, lip_mat, false)     # wood lip on top
	_cyl(parent, Vector3(cx, top_y + 0.07, cz), r - 0.1, 0.14, tile, false)                  # interior floor
	_cyl(parent, Vector3(cx, top_y + 0.42, cz), r - 0.16, 0.6, water, false)                 # contained water (0.12-0.72)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(cx, top_y + 0.9, cz)
	lamp.light_color = Color(1.0, 0.7, 0.45)
	lamp.light_energy = 1.4
	lamp.omni_range = 7.0
	lamp.shadow_enabled = false
	parent.add_child(lamp)
	var mist := _mat(Color(0.92, 0.94, 0.96), 1.0, 0.0)
	mist.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist.albedo_color = Color(0.92, 0.94, 0.96, 0.10)
	for spec in [[0.3, 1.4, -0.2, 1.4], [-0.4, 1.9, 0.3, 1.0], [0.1, 2.3, 0.1, 0.8]]:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = float(spec[3])
		sm.height = float(spec[3]) * 1.2
		mi.mesh = sm
		mi.position = Vector3(cx + float(spec[0]), top_y + float(spec[1]), cz + float(spec[2]))
		mi.material_override = mist
		parent.add_child(mi)


# --- Stairwell shaft walls: back (-z) and the two sides (+-x), full height. Front (+z) is the
# open entry; you approach the stair from the office floor on that side. ------------------
static func _stair_walls(parent: Node3D, top_y: float, mat: Material) -> void:
	var sh: float = STAIR_HALF
	_box(parent, Vector3(0.0, top_y * 0.5, -sh), Vector3(sh * 2.0, top_y, TH), mat, true)
	_box(parent, Vector3(-sh, top_y * 0.5, 0.0), Vector3(TH, top_y, sh * 2.0), mat, true)
	_box(parent, Vector3(sh, top_y * 0.5, 0.0), Vector3(TH, top_y, sh * 2.0), mat, true)


# --- Structural column grid (full height), skipping the central stairwell. ---------------
static func _columns(parent: Node3D, half: float, top_y: float, mat: Material) -> void:
	var reach: float = floorf((half - COL_GRID) / COL_GRID) * COL_GRID
	var c: float = -reach
	# Stop the columns just shy of the roof: a full-height column's top face sat exactly on the
	# walkable deck surface (top_y) and z-fought it. col_h buries the top inside the roof slab.
	var col_h: float = top_y - 0.2
	while c <= reach + 0.01:
		var d: float = -reach
		while d <= reach + 0.01:
			if absf(c) > STAIR_HALF + 1.0 or absf(d) > STAIR_HALF + 1.0:
				_box(parent, Vector3(c, col_h * 0.5, d), Vector3(COL_SIZE, col_h, COL_SIZE), mat, true)
			d += COL_GRID
		c += COL_GRID


# --- Compact switchback for one storey in the central stairwell (real-proportioned solid
# steps the capsule rounds into a slope, like the city building stairs). ------------------
static func _ustair(parent: Node3D, y0: float, y1: float, mat: Material) -> void:
	var sh: float = STAIR_HALF
	var mid_y: float = (y0 + y1) * 0.5
	var land_z1: float = -sh + STAIR_LAND_D
	# mid landing across the back
	_box(parent, Vector3(0.0, mid_y - 0.1, (-sh + land_z1) * 0.5), Vector3(sh * 2.0, 0.2, land_z1 + sh), mat, true)
	_flight(parent, -sh, 0.0, land_z1, sh, y0, mid_y, false, mat)   # left: enter at +z, climb to back landing
	_flight(parent, 0.0, sh, land_z1, sh, mid_y, y1, true, mat)     # right: back landing up to +z exit


static func _flight(parent: Node3D, x0: float, x1: float, z_lo: float, z_hi: float, y0: float, y1: float, ascend_hi: bool, mat: Material) -> void:
	var n: int = STAIR_STEPS
	var rise: float = (y1 - y0) / float(n)
	var depth: float = (z_hi - z_lo) / float(n)
	var cx: float = (x0 + x1) * 0.5
	var sw: float = x1 - x0
	for j in range(n):
		var z: float = (z_lo + (float(j) + 0.5) * depth) if ascend_hi else (z_hi - (float(j) + 0.5) * depth)
		var fill_h: float = float(j + 1) * rise
		_box(parent, Vector3(cx, y0 + fill_h * 0.5, z), Vector3(sw - 0.25, fill_h, depth + 0.05), mat, true)


# --- One glass face + its mullion grid. wall_is_z: face lies on z=fixed (spans x); else on
# x=fixed (spans z). ----------------------------------------------------------------------
static func _glass_face(parent: Node3D, wall_is_z: bool, fixed: float, half: float, top_y: float, glass: Material, trim: Material, door_half: float = 0.0) -> void:
	var gth: float = 0.08
	if door_half > 0.0 and wall_is_z:
		# ground-floor doorway out to the grassland: left + right panes + a header above
		var seg: float = half - door_half
		_box(parent, Vector3(-(half + door_half) * 0.5, top_y * 0.5, fixed), Vector3(seg, top_y, gth), glass, true)
		_box(parent, Vector3((half + door_half) * 0.5, top_y * 0.5, fixed), Vector3(seg, top_y, gth), glass, true)
		_box(parent, Vector3(0.0, (DOOR_H + top_y) * 0.5, fixed), Vector3(door_half * 2.0, top_y - DOOR_H, gth), glass, true)
	elif wall_is_z:
		_box(parent, Vector3(0.0, top_y * 0.5, fixed), Vector3(FOOTPRINT, top_y, gth), glass, true)
	else:
		_box(parent, Vector3(fixed, top_y * 0.5, 0.0), Vector3(gth, top_y, FOOTPRINT), glass, true)
	# Vertical mullions every ~5 m, proud of the glass (decorative, no collision).
	var mw: float = 0.14
	var proud: float = 0.06
	var n: int = int(round(FOOTPRINT / 5.0))
	for i in range(n + 1):
		var t: float = -half + float(i) * (FOOTPRINT / float(n))
		if wall_is_z:
			_box(parent, Vector3(t, top_y * 0.5, fixed), Vector3(mw, top_y, gth + proud), trim, false)
		else:
			_box(parent, Vector3(fixed, top_y * 0.5, t), Vector3(gth + proud, top_y, mw), trim, false)
	# Horizontal spandrel band at each floor line.
	for f in range(STORIES + 1):
		var fy: float = float(f) * STORY_H
		if wall_is_z:
			_box(parent, Vector3(0.0, fy, fixed), Vector3(FOOTPRINT, 0.24, gth + proud), trim, false)
		else:
			_box(parent, Vector3(fixed, fy, 0.0), Vector3(gth + proud, 0.24, FOOTPRINT), trim, false)


# --- Office fit-out for one storey ---------------------------------------------------------
# All the loose furniture (desks, chairs, partitions, plants, elevator doors) renders as ONE
# per-floor MultiMesh of coloured unit cubes (scaled per instance) -> one draw call per floor,
# and Main only ever shows the player's floor. Rooms that you walk into (restrooms, conference
# rooms) and the elevator block are solid collidable boxes.
const CORE_HALF: float = 13.0      # central service-zone (stair + elevators + restrooms)
const FIT_H: float = 2.7           # interior partition / room-wall height


static func _furnish_floor(group: Node3D, half: float, fy: float, world_seed: int, f: int) -> void:
	var rng := StableRng.new(StableRng.mix_string(world_seed, "skyfloor", f))
	var wall := _mat(Color(0.80, 0.80, 0.82), 0.9, 0.0)
	var glass := _glass_mat_clear()
	var xf: Array = []   # visual furniture instance transforms
	var cf: Array = []   # visual furniture instance colours
	var sx: Array = []   # solid-furniture colliders: [center, size, yaw]
	_fit_core(group, fy, wall, xf, cf, sx)
	var zones: Array = _fit_conference(group, half, fy, rng, glass, xf, cf, sx)
	_fit_cubicles(half, fy, rng, zones, xf, cf, sx)
	_fit_plants(half, fy, rng, xf, cf, sx)
	_ceiling_lights(group, half, fy, xf, cf)
	_floor_sign(group, fy, f + 1)
	if xf.size() > 0:
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		MultiMeshScatter.build(group, "Furniture", mesh, MultiMeshScatter.instance_color_material(0.8), xf, cf)
	_build_furn_collision(group, sx)


# One coloured unit-cube furniture instance: size + yaw + position.
static func _furn(xf: Array, cf: Array, center: Vector3, size: Vector3, color: Color, yaw: float = 0.0) -> void:
	xf.append(Transform3D(Basis(Vector3.UP, yaw).scaled(size), center))
	cf.append(color)


# Furniture that also blocks the player: the visual instance plus a box collider (built later
# into one per-floor StaticBody, so it's culled and cheap with the rest of the storey).
static func _furn_solid(xf: Array, cf: Array, sx: Array, center: Vector3, size: Vector3, color: Color, yaw: float = 0.0) -> void:
	_furn(xf, cf, center, size, color, yaw)
	sx.append([center, size, yaw])


# An office chair facing `yaw` (the way the sitter looks). Wheel base + gas cylinder + seat +
# a backrest set at the BACK edge of the seat (behind the sitter, away from the desk/table).
static func _chair(xf: Array, cf: Array, base: Vector3, yaw: float) -> void:
	var c := Color(0.13, 0.14, 0.18)
	var behind: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw)) * -0.21   # toward the chair's back
	_furn(xf, cf, base + Vector3(0.0, 0.05, 0.0), Vector3(0.52, 0.07, 0.52), c, yaw)          # wheel base
	_furn(xf, cf, base + Vector3(0.0, 0.28, 0.0), Vector3(0.1, 0.42, 0.1), c, yaw)            # gas cylinder
	_furn(xf, cf, base + Vector3(0.0, 0.47, 0.0), Vector3(0.5, 0.1, 0.5), c, yaw)             # seat
	_furn(xf, cf, base + Vector3(0.0, 0.76, 0.0) + behind, Vector3(0.48, 0.52, 0.08), c, yaw)  # backrest


static func _workstation(xf: Array, cf: Array, sx: Array, base: Vector3, yaw: float) -> void:
	var fwd: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw))
	var side: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
	_furn_solid(xf, cf, sx, base + Vector3(0.0, 0.37, 0.0), Vector3(1.4, 0.74, 0.62), Color(0.60, 0.56, 0.50), yaw)  # desk
	_chair(xf, cf, base - fwd * 0.55, yaw)                                                                           # chair faces the desk
	_furn_solid(xf, cf, sx, base + fwd * 0.40 + Vector3(0.0, 0.62, 0.0), Vector3(1.5, 1.24, 0.05), Color(0.44, 0.48, 0.54), yaw)  # spine partition
	_furn_solid(xf, cf, sx, base + side * 0.74 + Vector3(0.0, 0.55, 0.0), Vector3(0.05, 1.1, 1.4), Color(0.44, 0.48, 0.54), yaw)  # side partition


# Elevator car (3 solid walls + open +z front: you ride from inside it, at (0,-9)) flanked by
# visual bank doors, plus two restrooms with stall dividers. The car position is shared with
# Main (_skyscraper_elevator_xz) for the ride interaction.
static func _fit_core(group: Node3D, fy: float, wall: Material, xf: Array, cf: Array, sx: Array) -> void:
	var h: float = FIT_H
	_box(group, Vector3(0.0, fy + h * 0.5, -10.6), Vector3(5.0, h, 0.2), wall, true)    # car back wall
	_box(group, Vector3(-2.4, fy + h * 0.5, -9.3), Vector3(0.2, h, 2.8), wall, true)    # car left wall
	_box(group, Vector3(2.4, fy + h * 0.5, -9.3), Vector3(0.2, h, 2.8), wall, true)     # car right wall
	_furn(xf, cf, Vector3(0.0, fy + 0.04, -9.3), Vector3(4.6, 0.06, 2.6), Color(0.27, 0.29, 0.33))   # car floor pad
	_furn(xf, cf, Vector3(0.0, fy + h - 0.1, -9.3), Vector3(4.6, 0.12, 2.6), Color(0.30, 0.32, 0.36))  # car ceiling
	# Make the elevator a findable beacon in the dim office: a lit sign over the open front, a
	# glowing call panel beside it, and a cyan light filling the car.
	var sign := _emissive_mat(Color(0.35, 0.85, 1.0))
	_box(group, Vector3(0.0, fy + h - 0.12, -7.9), Vector3(4.6, 0.28, 0.12), sign, false)   # header sign over the door
	_box(group, Vector3(2.9, fy + 1.2, -8.0), Vector3(0.22, 0.5, 0.1), sign, false)         # call panel
	var car_lamp := OmniLight3D.new()
	car_lamp.position = Vector3(0.0, fy + h - 0.4, -9.3)
	car_lamp.light_color = Color(0.6, 0.85, 1.0)
	car_lamp.light_energy = 2.4
	car_lamp.omni_range = 9.0
	car_lamp.shadow_enabled = false
	group.add_child(car_lamp)
	# flanking visual bank doors (other shafts)
	for sgn in [-1.0, 1.0]:
		_furn_solid(xf, cf, sx, Vector3(sgn * 5.0, fy + 1.2, -7.8), Vector3(2.4, 2.4, 0.18), Color(0.50, 0.53, 0.58))
		_furn(xf, cf, Vector3(sgn * 5.0, fy + 1.2, -7.68), Vector3(0.05, 2.4, 0.12), Color(0.16, 0.18, 0.22))
	# restrooms left/right, doors facing the core lobby
	_room(group, 11.0, -9.0, 5.0, 5.0, fy, h, 3, wall)
	_room(group, -11.0, -9.0, 5.0, 5.0, fy, h, 2, wall)
	for rx in [11.0, -11.0]:
		for s in range(3):
			_furn_solid(xf, cf, sx, Vector3(rx - 1.6 + float(s) * 1.6, fy + 0.6, -10.6), Vector3(0.05, 1.2, 1.3), Color(0.72, 0.73, 0.75))


# A few glass-walled conference rooms along the perimeter. Returns keep-out rects for cubicles.
static func _fit_conference(group: Node3D, half: float, fy: float, rng: StableRng, glass: Material, xf: Array, cf: Array, sx: Array) -> Array:
	var zones: Array = []
	var n: int = rng.randi_range(2, 3)
	for i in range(n):
		var side: int = rng.randi_range(0, 3)
		var w: float = rng.randf_range(7.0, 10.0)
		var d: float = rng.randf_range(6.0, 8.0)
		var span: float = half - 1.0 - maxf(w, d)
		var cx: float = 0.0
		var cz: float = 0.0
		var door: int = 0
		match side:
			0: cz = half - 0.6 - d * 0.5; cx = rng.randf_range(-span, span); door = 1
			1: cz = -(half - 0.6 - d * 0.5); cx = rng.randf_range(-span, span); door = 0
			2: cx = half - 0.6 - w * 0.5; cz = rng.randf_range(-span, span); door = 3
			_: cx = -(half - 0.6 - w * 0.5); cz = rng.randf_range(-span, span); door = 2
		if absf(cx) < CORE_HALF + 4.0 and absf(cz) < CORE_HALF + 4.0:
			continue
		_room(group, cx, cz, w, d, fy, 2.6, door, glass, 1.4)
		_conf_table(xf, cf, sx, Vector3(cx, fy, cz), w, d)
		zones.append(Rect2(cx - w * 0.5 - 1.5, cz - d * 0.5 - 1.5, w + 3.0, d + 3.0))
	return zones


static func _conf_table(xf: Array, cf: Array, sx: Array, base: Vector3, w: float, d: float) -> void:
	var tw: float = w * 0.45
	var td: float = d * 0.4
	_furn_solid(xf, cf, sx, base + Vector3(0.0, 0.73, 0.0), Vector3(tw, 0.09, td), Color(0.30, 0.24, 0.18))   # tabletop
	_furn_solid(xf, cf, sx, base + Vector3(0.0, 0.36, 0.0), Vector3(tw * 0.5, 0.72, td * 0.5), Color(0.26, 0.21, 0.16))
	var nx: int = maxi(2, int(tw / 1.1))
	for i in range(nx):
		var x: float = base.x - tw * 0.5 + (float(i) + 0.5) * tw / float(nx)
		_chair(xf, cf, Vector3(x, base.y, base.z + td * 0.5 + 0.45), PI)
		_chair(xf, cf, Vector3(x, base.y, base.z - td * 0.5 - 0.45), 0.0)


# Cubicle neighbourhoods: a few dense grids of workstations in the open office.
static func _fit_cubicles(half: float, fy: float, rng: StableRng, zones: Array, xf: Array, cf: Array, sx: Array) -> void:
	var blocks: int = rng.randi_range(3, 4)
	for b in range(blocks):
		var w: float = rng.randf_range(9.0, 14.0)
		var d: float = rng.randf_range(9.0, 14.0)
		var lim_x: float = half - 6.0 - w * 0.5
		var lim_z: float = half - 6.0 - d * 0.5
		var cx: float = rng.randf_range(-lim_x, lim_x)
		var cz: float = rng.randf_range(-lim_z, lim_z)
		if absf(cx) < CORE_HALF + w * 0.5 + 1.0 and absf(cz) < CORE_HALF + d * 0.5 + 1.0:
			continue
		if _rect_in_zones(cx, cz, w, d, zones):
			continue
		var yaw: float = (PI * 0.5) * float(rng.randi_range(0, 3))
		var px: float = cx - w * 0.5 + 1.3
		while px <= cx + w * 0.5 - 1.0:
			var pz: float = cz - d * 0.5 + 1.3
			while pz <= cz + d * 0.5 - 1.0:
				if not _near_col(px, pz):
					_workstation(xf, cf, sx, Vector3(px, fy, pz), yaw)
				pz += 2.6
			px += 2.6


static func _fit_plants(half: float, fy: float, rng: StableRng, xf: Array, cf: Array, sx: Array) -> void:
	for i in range(8):
		var x: float = rng.randf_range(-(half - 4.0), half - 4.0)
		var z: float = rng.randf_range(-(half - 4.0), half - 4.0)
		if absf(x) < CORE_HALF and absf(z) < CORE_HALF:
			continue
		if _near_col(x, z):
			continue
		_furn_solid(xf, cf, sx, Vector3(x, fy + 0.3, z), Vector3(0.4, 0.6, 0.4), Color(0.30, 0.24, 0.18))   # pot
		_furn(xf, cf, Vector3(x, fy + 1.1, z), Vector3(0.9, 1.1, 0.9), Color(0.18, 0.42, 0.20))             # foliage


# One per-floor StaticBody holding every solid furniture piece as a box collider (no meshes;
# the visuals come from the MultiMesh). Hidden with the floor, so it costs nothing off-storey.
static func _build_furn_collision(group: Node3D, sx: Array) -> void:
	if sx.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = "FurnitureColliders"
	for s in sx:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = s[1]
		cs.shape = shape
		cs.transform = Transform3D(Basis(Vector3.UP, s[2]), s[0])
		body.add_child(cs)
	group.add_child(body)


# A grid of shadowless ceiling lights + flush fixtures. They live in the floor group, so the
# culling that hides off-storey floors also switches their lights off — only the player's
# storey is ever lit, keeping a fully-lit office cheap.
static func _ceiling_lights(group: Node3D, half: float, fy: float, xf: Array, cf: Array) -> void:
	var ly: float = fy + STORY_H - 0.3
	for gx in [-42.0, -14.0, 14.0, 42.0]:
		for gz in [-42.0, -14.0, 14.0, 42.0]:
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(gx, ly, gz)
			lamp.light_color = Color(1.0, 0.96, 0.88)
			lamp.light_energy = 1.4
			lamp.omni_range = 30.0
			lamp.shadow_enabled = false
			group.add_child(lamp)
			_furn(xf, cf, Vector3(gx, ly + 0.16, gz), Vector3(1.4, 0.12, 1.4), Color(0.96, 0.96, 0.9))   # fixture


# Big glowing storey number on the stair shaft: one on the back wall (-z, faces the elevator
# car so you read it looking out) and one on the open front (+z, faces the office). Per-floor,
# so culling shows exactly the storey you're standing on.
static func _floor_sign(group: Node3D, fy: float, number: int) -> void:
	var txt: String = str(number)
	# [x, y_offset, z, yaw]: back wall outward face on the solid -z wall (faces the elevator), and
	# the front. The front sits in the open doorway, shifted toward the +x jamb (off the open stair)
	# and at mid-doorway height so the whole number reads on the wall rather than riding up near the
	# stairwell-wall top.
	for spec in [[0.0, 2.3, -2.7, PI], [1.3, 2.8, 2.6, 0.0]]:
		var lbl := Label3D.new()
		lbl.text = txt
		lbl.font_size = 200
		lbl.pixel_size = 0.006
		lbl.modulate = Color(0.72, 0.92, 1.0)
		lbl.outline_size = 18
		lbl.outline_modulate = Color(0.02, 0.05, 0.09)
		lbl.position = Vector3(float(spec[0]), fy + float(spec[1]), float(spec[2]))
		lbl.rotation.y = float(spec[3])
		group.add_child(lbl)


# Four walls around [cx+-w/2, cz+-d/2] with a door gap on `door_side` (0:+z 1:-z 2:+x 3:-x).
static func _room(parent: Node3D, cx: float, cz: float, w: float, d: float, fy: float, h: float, door_side: int, mat: Material, door_w: float = 1.2) -> void:
	var t: float = 0.12
	var hw: float = w * 0.5
	var hd: float = d * 0.5
	var cy: float = fy + h * 0.5
	_door_wall(parent, Vector3(cx, cy, cz + hd), Vector3(w, h, t), door_side == 0, door_w, mat, true)
	_door_wall(parent, Vector3(cx, cy, cz - hd), Vector3(w, h, t), door_side == 1, door_w, mat, true)
	_door_wall(parent, Vector3(cx + hw, cy, cz), Vector3(t, h, d), door_side == 2, door_w, mat, false)
	_door_wall(parent, Vector3(cx - hw, cy, cz), Vector3(t, h, d), door_side == 3, door_w, mat, false)


static func _door_wall(parent: Node3D, center: Vector3, size: Vector3, has_door: bool, door_w: float, mat: Material, span_x: bool) -> void:
	if not has_door:
		_box(parent, center, size, mat, true)
		return
	var span: float = size.x if span_x else size.z
	var seg: float = (span - door_w) * 0.5
	if seg <= 0.15:
		_box(parent, center, size, mat, true)
		return
	if span_x:
		_box(parent, center + Vector3(-(door_w + seg) * 0.5, 0.0, 0.0), Vector3(seg, size.y, size.z), mat, true)
		_box(parent, center + Vector3((door_w + seg) * 0.5, 0.0, 0.0), Vector3(seg, size.y, size.z), mat, true)
	else:
		_box(parent, center + Vector3(0.0, 0.0, -(door_w + seg) * 0.5), Vector3(size.x, size.y, seg), mat, true)
		_box(parent, center + Vector3(0.0, 0.0, (door_w + seg) * 0.5), Vector3(size.x, size.y, seg), mat, true)


static func _near_col(x: float, z: float) -> bool:
	var nx: float = round(x / COL_GRID) * COL_GRID
	var nz: float = round(z / COL_GRID) * COL_GRID
	return Vector2(x - nx, z - nz).length() < 1.3


static func _rect_in_zones(cx: float, cz: float, w: float, d: float, zones: Array) -> bool:
	var r := Rect2(cx - w * 0.5, cz - d * 0.5, w, d)
	for z in zones:
		if (z as Rect2).intersects(r):
			return true
	return false


# --- Primitives --------------------------------------------------------------------------
static func _box(parent: Node3D, center: Vector3, size: Vector3, mat: Material, collide: bool) -> void:
	if collide:
		var body := StaticBody3D.new()
		body.position = center
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = size
		mi.mesh = bm
		mi.material_override = mat
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new(); sh.size = size
		cs.shape = sh
		body.add_child(cs)
		parent.add_child(body)
	else:
		var mi2 := MeshInstance3D.new()
		var bm2 := BoxMesh.new(); bm2.size = size
		mi2.mesh = bm2
		mi2.material_override = mat
		mi2.position = center
		parent.add_child(mi2)


static func _mat(color: Color, rough: float, metallic: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	return m


static func _emissive_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 4.0
	return m


static func _glass_mat() -> StandardMaterial3D:
	# One-way curtain wall. Default = CLEAR: you spawn inside looking out at the grassland. Main
	# flips this same shared material to opaque mirror glass whenever you step outside, so the
	# whole interior can stop rendering (see Main._update_skyscraper_inside_outside).
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.58, 0.72, 0.82, 0.13)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	m.metallic = 0.05   # low reflectivity so the globe doesn't ghost in the panes
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# Clear interior glass for conference-room partitions.
static func _glass_mat_clear() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.72, 0.80, 0.20)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.08
	m.metallic = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _pond_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.34, 0.50, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.04
	m.metallic = 0.6
	return m


# --- The inner grass sphere (hollow-planet) world -------------------------------------------
# One grass sphere whose entire inner surface you walk via spherical gravity (see Player), with
# the tower a spike at the bottom. Trees + ponds on the surface, a globe-sun on the roof.
static func _build_outside(root: Node3D, world_seed: int, half: float, top_y: float) -> void:
	var rng := StableRng.new(StableRng.mix_string(world_seed, "skyoutside", 1))
	var out := Node3D.new()
	out.name = "Outside"
	root.add_child(out)

	# One noise field drives both the rolling hills and the biome colours (seeded for determinism).
	var terrain := FastNoiseLite.new()
	terrain.seed = world_seed
	terrain.frequency = 0.006
	terrain.fractal_octaves = 3
	var grass := _mat(Color.WHITE, 0.95, 0.0)   # white base; biome vertex colours supply the hue
	grass.vertex_color_use_as_albedo = true
	grass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bark := _mat(Color(0.34, 0.24, 0.16), 0.9, 0.0)
	var leaf := _mat(Color(0.19, 0.42, 0.18), 0.85, 0.0)
	var water := _pond_mat()
	# Centre the sphere so its lower surface meets ground level (y=0) right at the tower edge
	# (r~62): under the tower it's below the base slab (hidden); outside it rises away smoothly.
	var center := _world_center()

	_build_world_sphere(out, grass, center, WORLD_R, terrain)

	# Globe-sun floating at the sphere's centre. A single point source there lights every wall
	# evenly — all walls are equidistant from the centre — instead of a distant directional sun that
	# brightened the tower base and read as an inverted shadow.
	var globe := MeshInstance3D.new()
	globe.name = "GlobeSun"
	var gm := SphereMesh.new()
	gm.radius = GLOBE_R
	gm.height = GLOBE_R * 2.0
	globe.mesh = gm
	globe.position = center
	globe.material_override = _emissive_mat(Color(1.0, 0.93, 0.66))
	out.add_child(globe)
	var sun := OmniLight3D.new()
	sun.name = "GlobeLight"
	sun.position = center
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 8.0   # Main's day/night drives this; gentle falloff reaches the far walls
	sun.omni_range = WORLD_R + 80.0
	sun.omni_attenuation = 0.4
	sun.shadow_enabled = false
	out.add_child(sun)

	# Trees all over the inner surface, pointing inward (toward the centre = local "up"), sitting on
	# the displaced hill surface. Three leaf tints for variety. Skip the very bottom (the tower).
	var leaves: Array = [leaf, _mat(Color(0.26, 0.50, 0.22), 0.85, 0.0), _mat(Color(0.42, 0.50, 0.20), 0.85, 0.0)]
	for i in range(120):
		var dir := _rand_sphere_dir(rng)
		if dir.y < -0.84:
			continue
		var tpos: Vector3 = center + dir * (WORLD_R - _terrain_height(terrain, dir) - 0.3)
		_place_tree(out, tpos, -dir, rng.randf_range(3.5, 6.5), rng.randf_range(2.2, 3.8), bark, leaves[rng.randi_range(0, 2)], true)

	# Ponds on the lower surface (flush with the curve).
	for i in range(8):
		var pdir := _rand_sphere_dir(rng)
		pdir.y = -absf(pdir.y) * rng.randf_range(0.4, 0.9)
		pdir = pdir.normalized()
		if pdir.y < -0.82:
			continue
		var pond := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var rad: float = rng.randf_range(6.0, 12.0)
		cm.top_radius = rad
		cm.bottom_radius = rad
		cm.height = 0.3
		pond.mesh = cm
		pond.transform = Transform3D(_basis_from_up(-pdir), center + pdir * (WORLD_R - _terrain_height(terrain, pdir) - 0.1))
		pond.material_override = water
		out.add_child(pond)

	# Re-entry portals low on the surface (reachable on the gentle lower slopes).
	var portal := _emissive_mat(Color(0.45, 1.0, 0.62))
	var post_mat := _mat(Color(0.30, 0.32, 0.36), 0.6, 0.4)
	for i in range(3):
		var gdir := _rand_sphere_dir(rng)
		gdir.y = -rng.randf_range(0.55, 0.8)
		gdir = gdir.normalized()
		var g := Node3D.new()
		g.name = "ReturnGate_" + str(i)
		g.transform = Transform3D(_basis_from_up(-gdir), center + gdir * (WORLD_R - _terrain_height(terrain, gdir) - 0.1))
		out.add_child(g)
		_box(g, Vector3(-1.7, 2.1, 0.0), Vector3(0.4, 4.2, 0.4), post_mat, true)
		_box(g, Vector3(1.7, 2.1, 0.0), Vector3(0.4, 4.2, 0.4), post_mat, true)
		_box(g, Vector3(0.0, 4.4, 0.0), Vector3(3.8, 0.4, 0.4), post_mat, true)
		var pane := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(2.9, 3.9, 0.15)
		pane.mesh = pm
		pane.position = Vector3(0.0, 2.1, 0.0)
		pane.material_override = portal
		g.add_child(pane)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(0.0, 2.3, 0.0)
		lamp.light_color = Color(0.5, 1.0, 0.66)
		lamp.light_energy = 2.2
		lamp.omni_range = 16.0
		lamp.shadow_enabled = false
		g.add_child(lamp)

	# Low-poly density (rocks + bushes) and a couple of landmarks for interest and orientation.
	_scatter_props(out, rng, center, terrain)
	var lc := _rand_sphere_dir(rng)
	lc.y = -0.2
	lc = lc.normalized()
	_stone_circle(out, center + lc * (WORLD_R - _terrain_height(terrain, lc)), -lc)
	var lo := _rand_sphere_dir(rng)
	lo.y = 0.18
	lo = lo.normalized()
	_obelisk(out, center + lo * (WORLD_R - _terrain_height(terrain, lo)), -lo)


# Low-poly scatter (half-buried rocks, then bushes) across the inner surface as two MultiMeshes —
# one draw call each — for density without a polygon blow-up.
static func _scatter_props(out: Node3D, rng: StableRng, center: Vector3, noise: FastNoiseLite) -> void:
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 1.0
	rock_mesh.height = 1.6
	rock_mesh.radial_segments = 8
	rock_mesh.rings = 4
	var rock_tf: Array = []
	var rock_col: Array = []
	for i in range(150):
		var dir := _rand_sphere_dir(rng)
		if dir.y < -0.82:
			continue
		var up := -dir
		var pos := center + dir * (WORLD_R - _terrain_height(noise, dir))
		var s := rng.randf_range(0.6, 1.9)
		var b := _basis_from_up(up).rotated(up, rng.randf_range(0.0, TAU)).scaled(Vector3(s * rng.randf_range(0.8, 1.3), s * rng.randf_range(0.5, 0.8), s * rng.randf_range(0.8, 1.3)))
		rock_tf.append(Transform3D(b, pos))
		rock_col.append(Color(0.50, 0.50, 0.52).lerp(Color(0.38, 0.40, 0.40), rng.randf()))
	MultiMeshScatter.build(out, "Rocks", rock_mesh, MultiMeshScatter.instance_color_material(0.95), rock_tf, rock_col)

	var bush_mesh := SphereMesh.new()
	bush_mesh.radius = 1.0
	bush_mesh.height = 1.8
	bush_mesh.radial_segments = 10
	bush_mesh.rings = 5
	var bush_tf: Array = []
	var bush_col: Array = []
	for i in range(130):
		var dir2 := _rand_sphere_dir(rng)
		if dir2.y < -0.8:
			continue
		var up2 := -dir2
		var s2 := rng.randf_range(0.7, 1.5)
		var pos2 := center + dir2 * (WORLD_R - _terrain_height(noise, dir2) - s2 * 0.5)
		var b2 := _basis_from_up(up2).rotated(up2, rng.randf_range(0.0, TAU)).scaled(Vector3(s2 * rng.randf_range(0.9, 1.3), s2, s2 * rng.randf_range(0.9, 1.3)))
		bush_tf.append(Transform3D(b2, pos2))
		bush_col.append(Color(0.20, 0.42, 0.18).lerp(Color(0.34, 0.50, 0.22), rng.randf()))
	MultiMeshScatter.build(out, "Bushes", bush_mesh, MultiMeshScatter.instance_color_material(0.9), bush_tf, bush_col)


# A ring of standing stones with a central altar, oriented so local +Y = up (inward toward centre).
static func _stone_circle(parent: Node3D, pos: Vector3, up: Vector3) -> void:
	var stone := _mat(Color(0.52, 0.52, 0.54), 0.95, 0.0)
	var node := Node3D.new()
	node.transform = Transform3D(_basis_from_up(up), pos)
	parent.add_child(node)
	for i in range(9):
		var a: float = TAU * float(i) / 9.0
		_box(node, Vector3(cos(a) * 7.0, 2.4, sin(a) * 7.0), Vector3(1.4, 4.8, 1.0), stone, true)
	_box(node, Vector3(0.0, 0.4, 0.0), Vector3(3.0, 0.8, 2.0), stone, true)


# A tall stepped/tapered obelisk on a plinth — a far-visible landmark. Local +Y = up (inward).
static func _obelisk(parent: Node3D, pos: Vector3, up: Vector3) -> void:
	var stone := _mat(Color(0.58, 0.53, 0.44), 0.85, 0.1)
	var node := Node3D.new()
	node.transform = Transform3D(_basis_from_up(up), pos)
	parent.add_child(node)
	_box(node, Vector3(0.0, 0.7, 0.0), Vector3(4.5, 1.4, 4.5), stone, true)
	_box(node, Vector3(0.0, 1.7, 0.0), Vector3(3.0, 0.6, 3.0), stone, true)
	for i in range(6):
		var w: float = lerpf(2.4, 0.7, float(i) / 6.0)
		_box(node, Vector3(0.0, 2.6 + float(i) * 2.0, 0.0), Vector3(w, 2.0, w), stone, true)
	_box(node, Vector3(0.0, 15.0, 0.0), Vector3(0.7, 1.0, 0.7), stone, true)


# A UV sphere displaced into gentle rolling hills (inward, flattened near the tower) with biome
# vertex colours and finite-difference inward normals (so hills self-shade under the central sun),
# plus trimesh collision matching the displaced surface. Hills only push inward (toward centre), so
# the player never gets farther from centre than the base radius and containment stays simple.
static func _build_world_sphere(parent: Node3D, grass_mat: Material, center: Vector3, radius: float, noise: FastNoiseLite) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lat_n: int = 40
	var lon_n: int = 64
	for i in range(lat_n):
		var t0: float = PI * float(i) / float(lat_n)
		var t1: float = PI * float(i + 1) / float(lat_n)
		for j in range(lon_n):
			var p0: float = TAU * float(j) / float(lon_n)
			var p1: float = TAU * float(j + 1) / float(lon_n)
			_emit_sphere_vert(st, center, radius, noise, t0, p0)
			_emit_sphere_vert(st, center, radius, noise, t1, p1)
			_emit_sphere_vert(st, center, radius, noise, t1, p0)
			_emit_sphere_vert(st, center, radius, noise, t0, p0)
			_emit_sphere_vert(st, center, radius, noise, t0, p1)
			_emit_sphere_vert(st, center, radius, noise, t1, p1)
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "WorldSphere"
	mi.mesh = mesh
	mi.material_override = grass_mat
	parent.add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	parent.add_child(body)


# Inward hill height at a surface direction: 0..12 m toward the centre, faded to 0 near the bottom
# so the tower's ground seam stays flat.
static func _terrain_height(noise: FastNoiseLite, dir: Vector3) -> float:
	var atten: float = smoothstep(-0.85, -0.5, dir.y)
	var p: Vector3 = dir * WORLD_R
	return (noise.get_noise_3d(p.x, p.y, p.z) * 0.5 + 0.5) * 12.0 * atten


# Grass tint with sandy clearings from an independent noise channel (read as per-vertex albedo).
static func _biome_color(noise: FastNoiseLite, dir: Vector3) -> Color:
	var p: Vector3 = dir * WORLD_R
	var t: float = noise.get_noise_3d(p.x + 1500.0, p.y - 800.0, p.z + 1500.0)
	var col: Color = Color(0.23, 0.43, 0.19).lerp(Color(0.43, 0.57, 0.28), clampf(t * 0.6 + 0.5, 0.0, 1.0))
	if t > 0.5:
		col = col.lerp(Color(0.70, 0.63, 0.43), clampf((t - 0.5) / 0.5, 0.0, 0.7))
	return col


# One displaced sphere vertex with its biome colour and a finite-difference inward normal.
static func _emit_sphere_vert(st: SurfaceTool, center: Vector3, radius: float, noise: FastNoiseLite, theta: float, phi: float) -> void:
	var dir: Vector3 = _sph_dir(theta, phi)
	var pos: Vector3 = center + dir * (radius - _terrain_height(noise, dir))
	var eps: float = 0.012
	var da: Vector3 = _sph_dir(theta + eps, phi)
	var db: Vector3 = _sph_dir(theta, phi + eps)
	var pa: Vector3 = center + da * (radius - _terrain_height(noise, da))
	var pb: Vector3 = center + db * (radius - _terrain_height(noise, db))
	var n: Vector3 = (pa - pos).cross(pb - pos)
	if n.length() < 0.0001:
		n = -dir
	else:
		n = n.normalized()
		if n.dot(center - pos) < 0.0:
			n = -n
	st.set_color(_biome_color(noise, dir))
	st.set_normal(n)
	st.add_vertex(pos)


# Sphere centre: its lower surface passes through ground level (y=0) at r~62 (just outside the
# tower footprint), so the tower sits flush in the bottom and the grass curves away from there.
static func _world_center() -> Vector3:
	return Vector3(0.0, sqrt(WORLD_R * WORLD_R - 62.0 * 62.0), 0.0)


static func _sph_dir(theta: float, phi: float) -> Vector3:
	return Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))


static func _sphere_vert(st: SurfaceTool, center: Vector3, radius: float, dir: Vector3) -> void:
	st.set_normal(-dir)
	st.add_vertex(center + dir * radius)


static func _rand_sphere_dir(rng: StableRng) -> Vector3:
	var u: float = rng.randf_range(-1.0, 1.0)
	var ph: float = rng.randf_range(0.0, TAU)
	var s: float = sqrt(maxf(0.0, 1.0 - u * u))
	return Vector3(s * cos(ph), u, s * sin(ph))


# Trunk + foliage oriented so local +Y = up_dir (up for ground trees, inward for the dome).
static func _place_tree(parent: Node3D, pos: Vector3, up_dir: Vector3, th: float, fr: float, bark: Material, leaf: Material, collide: bool) -> void:
	var t := Node3D.new()
	t.transform = Transform3D(_basis_from_up(up_dir), pos)
	parent.add_child(t)
	_box(t, Vector3(0.0, th * 0.5, 0.0), Vector3(0.7, th, 0.7), bark, collide)
	var foliage := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = fr
	fm.height = fr * 2.0
	fm.radial_segments = 10   # low-poly canopy: ~120 tris, not the 4k default
	fm.rings = 5
	foliage.mesh = fm
	foliage.position = Vector3(0.0, th + fr * 0.4, 0.0)
	foliage.material_override = leaf
	t.add_child(foliage)


static func _basis_from_up(up: Vector3) -> Basis:
	var u := up.normalized()
	var ref := Vector3(1.0, 0.0, 0.0) if absf(u.x) < 0.9 else Vector3(0.0, 0.0, 1.0)
	var right := ref.cross(u).normalized()
	var fwd := right.cross(u).normalized()
	return Basis(right, u, fwd)


static func _rand_up_dir(rng: StableRng) -> Vector3:
	var ang: float = rng.randf_range(0.0, TAU)
	var yy: float = rng.randf_range(0.15, 0.95)
	var rr: float = sqrt(maxf(0.0, 1.0 - yy * yy))
	return Vector3(cos(ang) * rr, yy, sin(ang) * rr)


# A random ground point with radius in [inner, outer], kept out of the tower's square footprint.
static func _ring_point(rng: StableRng, inner: float, outer: float) -> Vector2:
	var keep: float = FOOTPRINT * 0.5 + 6.0
	for _i in range(10):
		var ang: float = rng.randf_range(0.0, TAU)
		var r: float = rng.randf_range(inner, outer)
		var p := Vector2(cos(ang) * r, sin(ang) * r)
		if absf(p.x) > keep or absf(p.y) > keep:
			return p
	return Vector2(inner, 0.0)
