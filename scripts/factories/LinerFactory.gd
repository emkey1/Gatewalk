extends RefCounted
class_name LinerFactory

# A 1:1 replica of the RMS Queen Mary as built (maiden voyage, 1936) — Cunard's
# 310.7 m, 80,774-GRT Atlantic liner — floating on an open ocean map. Built in WORLD
# space with the waterline at `wl` (the map's WATER_LEVEL): the black hull sits in the
# sea, the white superstructure steps up through the Promenade, Sun and Sports decks,
# three red-and-black funnels and two masts rise over midships. Bow toward +Z; port and
# starboard along X. Four exit gates are scattered across the open decks (gate 0 sits
# aft, by the arrival spawn, so you can always leave without crossing the whole ship).
#
# Reference dimensions (as built): LOA 1,019.4 ft (310.7 m), beam 118 ft (36.0 m),
# draught 38 ft 9 in (11.8 m), height keel-to-forward-funnel-top 181 ft (55.2 m), so
# the forward funnel tops out ~43 m above the waterline. 12 decks, 3 funnels, 2 masts,
# 24 lifeboats, 4 shafts. (Sources: sterling.rmplc.co.uk deck plans + Wikipedia.)

const StableRng = preload("res://scripts/core/StableRng.gd")
const MultiMeshScatter = preload("res://scripts/factories/MultiMeshScatter.gd")

const LOA: float = 310.7           # length overall
const BEAM: float = 36.0           # max breadth
const DRAUGHT: float = 11.8        # keel below the waterline

# Open-deck heights ABOVE the waterline (world y = wl + these). The four walkable decks
# the player roams in this build, stepping up the way the real superstructure does.
const DECK_MAIN: float = 12.0      # main weather deck: open forecastle + aft deck
const DECK_PROM: float = 15.5      # promenade deck (the long enclosed promenade)
const DECK_SUN: float = 19.5       # boat / sun deck: lifeboats + funnel casings
const DECK_SPORTS: float = 23.5    # sports deck (topmost open deck)

const HULL_HALF_LEN: float = LOA * 0.5
const HULL_HALF_BEAM: float = BEAM * 0.5
const HULL_STATIONS: int = 48      # longitudinal segments the hull/deck are lofted over

# Cunard livery.
const COL_TOPSIDE := Color(0.07, 0.07, 0.08)   # black topsides
const COL_BOOT := Color(0.62, 0.16, 0.14)      # red boot-topping at the waterline
const COL_ANTIFOUL := Color(0.40, 0.12, 0.12)  # red anti-fouling below
const COL_TEAK := Color(0.55, 0.42, 0.26)      # scrubbed teak weather deck
const COL_SUPER := Color(0.88, 0.88, 0.85)     # white superstructure
const COL_WINDOW := Color(0.10, 0.13, 0.17)    # dark glazing

# Superstructure massing (fractions of HULL_HALF_LEN). The base white block encloses the
# Main, A and Promenade decks and rises to the open Boat/Sun deck; a centreline boat-deck
# house then carries the funnels up to the Sports deck. Leaving SS_HALF_W < the hull beam
# keeps a walkable side deck along the Main deck, so fore and aft connect on the flat.
const SS_AFT: float = -0.56
const SS_FWD: float = 0.46
const SS_HALF_W: float = 13.5
const BH_AFT: float = -0.40
const BH_FWD: float = 0.40
const BH_HALF_W: float = 8.0


# Build the liner into `parent`. Returns an Array of 4 gate world-positions on the
# decks (gate 0 sits aft, near the arrival spawn).
static func build(parent: Node3D, world_seed: int, wl: float) -> Array:
	var root := Node3D.new()
	root.name = "QueenMary"
	parent.add_child(root)
	var rng := StableRng.new(StableRng.mix_string(world_seed, "liner", 1))

	_build_hull(root, wl)
	_build_main_deck(root, wl)
	_build_superstructure(root, wl)

	# --- Four exit gates on the open Main deck (clear of the superstructure): two on the
	# aft well deck by the arrival, two up on the forecastle. All reachable on the flat
	# via the open side decks. (A later pass scatters some onto the upper decks.) ---
	var gates: Array = []
	var gate_zs: Array = [SS_AFT * HULL_HALF_LEN - 22.0, SS_AFT * HULL_HALF_LEN - 44.0, SS_FWD * HULL_HALF_LEN + 14.0, SS_FWD * HULL_HALF_LEN + 34.0]
	for gi in range(4):
		var gz: float = float(gate_zs[gi])
		var lim: float = maxf(_half_beam(gz) - 3.5, 1.0)
		var gx: float = clampf(rng.randf_range(-lim, lim), -lim, lim)
		gates.append(Vector3(gx, _sheer_y(gz, wl) + 0.05, gz))
	return gates


# Deck arrival / spawn: on the open aft well deck behind the superstructure, looking
# toward the bow. Shared by Main's _find_spawn_position and the _scatter_liner teleport.
static func spawn_position(wl: float) -> Vector3:
	var z: float = SS_AFT * HULL_HALF_LEN - 17.0
	return Vector3(0.0, _sheer_y(z, wl) + 1.2, z)


# --- Hull form (longitudinal profiles, all in world space) --------------------------

# Half-beam at longitudinal position z: full amidships, a fine entry forward to a near
# point at the stem, and a rounded cruiser stern aft.
static func _half_beam(z: float) -> float:
	var t: float = z / HULL_HALF_LEN          # -1 (stern) .. +1 (bow)
	if t > 0.30:
		var f: float = (t - 0.30) / 0.70      # 0..1 over the forward run
		return maxf(HULL_HALF_BEAM * (1.0 - pow(f, 1.7)), 0.35)
	if t < -0.40:
		var a: float = (-t - 0.40) / 0.60     # 0..1 over the aft run
		return maxf(HULL_HALF_BEAM * (1.0 - 0.72 * pow(a, 1.5)), 4.5)
	return HULL_HALF_BEAM


# World y of the hull bottom (keel) at z: flat amidships at full draught, the forefoot
# rising toward the raked stem and the run rising toward the cruiser stern.
static func _keel_y(z: float, wl: float) -> float:
	var t: float = z / HULL_HALF_LEN
	var deep: float = wl - DRAUGHT
	if t > 0.55:
		return lerpf(deep, wl - 1.5, smoothstep(0.0, 1.0, (t - 0.55) / 0.45))
	if t < -0.60:
		return lerpf(deep, wl - 3.0, smoothstep(0.0, 1.0, (-t - 0.60) / 0.40))
	return deep


# World y of the hull top edge (the sheer / main-deck line) at z: near-flat amidships
# with a rise toward the bow (forecastle) and a slight lift aft.
static func _sheer_y(z: float, wl: float) -> float:
	var deck: float = wl + DECK_MAIN
	var t: float = z / HULL_HALF_LEN
	if t > 0.5:
		return deck + smoothstep(0.0, 1.0, (t - 0.5) / 0.5) * 2.2
	if t < -0.7:
		return deck + smoothstep(0.0, 1.0, (-t - 0.7) / 0.3) * 1.0
	return deck


static func _hull_color(y: float, wl: float) -> Color:
	if y >= wl + 0.7:
		return COL_TOPSIDE
	if y >= wl - 0.5:
		return COL_BOOT
	return COL_ANTIFOUL


# Loft the hull as a single vertex-coloured mesh: a slightly tumblehome side (deck edge
# out over a narrower keel) plus a flat bottom, swept over the station profiles, with
# end caps fanned at bow and stern.
static func _build_hull(parent: Node3D, wl: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = HULL_STATIONS
	for i in range(n):
		var z0: float = lerpf(-HULL_HALF_LEN, HULL_HALF_LEN, float(i) / float(n))
		var z1: float = lerpf(-HULL_HALF_LEN, HULL_HALF_LEN, float(i + 1) / float(n))
		var b0: float = _half_beam(z0)
		var b1: float = _half_beam(z1)
		var k0: float = _keel_y(z0, wl)
		var k1: float = _keel_y(z1, wl)
		var s0: float = _sheer_y(z0, wl)
		var s1: float = _sheer_y(z1, wl)
		var dL0 := Vector3(-b0, s0, z0)
		var dL1 := Vector3(-b1, s1, z1)
		var bL0 := Vector3(-b0 * 0.72, k0, z0)
		var bL1 := Vector3(-b1 * 0.72, k1, z1)
		var dR0 := Vector3(b0, s0, z0)
		var dR1 := Vector3(b1, s1, z1)
		var bR0 := Vector3(b0 * 0.72, k0, z0)
		var bR1 := Vector3(b1 * 0.72, k1, z1)
		_quad(st, dL0, bL0, bL1, dL1, wl)   # port side
		_quad(st, dR0, dR1, bR1, bR0, wl)   # starboard side
		_quad(st, bL0, bL1, bR1, bR0, wl)   # flat bottom
	_cap(st, HULL_HALF_LEN, wl)             # bow
	_cap(st, -HULL_HALF_LEN, wl)            # stern
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Hull"
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.55
	mat.metallic = 0.05
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED   # closed hull; dodge any inverted winding
	mi.material_override = mat
	parent.add_child(mi)


# The walkable teak weather deck: a flat surface across the beam at the sheer line,
# inset just inside the hull edge so a thin black covering board shows. Lofted as one
# mesh with a trimesh collider so the player stands exactly on it.
static func _build_main_deck(parent: Node3D, wl: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(COL_TEAK)
	var n: int = HULL_STATIONS
	for i in range(n):
		var z0: float = lerpf(-HULL_HALF_LEN, HULL_HALF_LEN, float(i) / float(n))
		var z1: float = lerpf(-HULL_HALF_LEN, HULL_HALF_LEN, float(i + 1) / float(n))
		var b0: float = _half_beam(z0) * 0.96
		var b1: float = _half_beam(z1) * 0.96
		var s0: float = _sheer_y(z0, wl)
		var s1: float = _sheer_y(z1, wl)
		var l0 := Vector3(-b0, s0, z0)
		var r0 := Vector3(b0, s0, z0)
		var l1 := Vector3(-b1, s1, z1)
		var r1 := Vector3(b1, s1, z1)
		_quad_flat(st, l0, r0, r1, l1)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var body := StaticBody3D.new()
	body.name = "MainDeck"
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	body.add_child(mi)
	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	body.add_child(col)
	parent.add_child(body)


# Two triangles with per-vertex hull colours (a,b,c,d wound as a quad).
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, wl: float) -> void:
	_tri(st, a, b, c, wl)
	_tri(st, a, c, d, wl)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, wl: float) -> void:
	st.set_color(_hull_color(a.y, wl)); st.add_vertex(a)
	st.set_color(_hull_color(b.y, wl)); st.add_vertex(b)
	st.set_color(_hull_color(c.y, wl)); st.add_vertex(c)


# Quad with the colour already set on the SurfaceTool (flat-coloured surfaces like the deck).
static func _quad_flat(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
	st.add_vertex(a); st.add_vertex(c); st.add_vertex(d)


# Close a hull end (bow/stern) with a fan from the cross-section centre.
static func _cap(st: SurfaceTool, z: float, wl: float) -> void:
	var b: float = _half_beam(z)
	var k: float = _keel_y(z, wl)
	var s: float = _sheer_y(z, wl)
	var dL := Vector3(-b, s, z)
	var dR := Vector3(b, s, z)
	var bL := Vector3(-b * 0.72, k, z)
	var bR := Vector3(b * 0.72, k, z)
	var c := Vector3(0.0, (s + k) * 0.5, z)
	_tri(st, dL, dR, c, wl)
	_tri(st, dR, bR, c, wl)
	_tri(st, bR, bL, c, wl)
	_tri(st, bL, dL, c, wl)


# --- Superstructure: the stepped white decks + companionway stairs ------------------

static func _build_superstructure(parent: Node3D, wl: float) -> void:
	var root := Node3D.new()
	root.name = "Superstructure"
	parent.add_child(root)
	var white := _mat(COL_SUPER, 0.7, 0.0)
	var glass := _mat(COL_WINDOW, 0.25, 0.3)
	var deck := _mat(COL_TEAK, 0.9, 0.0)
	var L: float = HULL_HALF_LEN
	var y_main: float = wl + DECK_MAIN
	var y_sun: float = wl + DECK_SUN
	var y_sports: float = wl + DECK_SPORTS

	# Base block: Main deck -> open Boat/Sun deck, enclosing the A and Promenade decks. The
	# long sides carry the Promenade window row plus a lower deck-window band.
	_deckhouse(root, SS_AFT * L, SS_FWD * L, SS_HALF_W, y_main, y_sun, white, glass, deck, true)
	# Centreline boat-deck house: Boat/Sun -> Sports deck, the funnel casing base. Narrow,
	# so the boat-deck walkways (for the lifeboats) stay open along each side.
	_deckhouse(root, BH_AFT * L, BH_FWD * L, BH_HALF_W, y_sun, y_sports, white, glass, deck, false)
	# Navigating bridge across the forward end of the boat deck, with wing platforms.
	_build_bridge(root, wl, white, glass, deck)

	# Companionways linking the open decks: up the aft well deck to the Boat deck, on up to
	# the Sports deck, and a forward flight down to the forecastle. Solid steps the capsule
	# rounds into a ramp (same approach as the tower/city stairs).
	_stair_run(root, -6.0, SS_AFT * L - 13.0, SS_AFT * L - 1.5, y_main, y_sun, 4.0, deck)
	_stair_run(root, 0.0, BH_AFT * L - 9.0, BH_AFT * L - 1.5, y_sun, y_sports, 3.6, deck)
	_stair_run(root, 6.0, SS_FWD * L + 13.0, SS_FWD * L + 1.5, y_main, y_sun, 4.0, deck)


# A white deckhouse box: four walls + a walkable top-deck slab (overhanging slightly to
# meet stairs and deck edges), with dark window bands on the long sides.
static func _deckhouse(parent: Node3D, z_aft: float, z_fwd: float, half_w: float, y_base: float, y_top: float, wall: Material, glass: Material, deck: Material, prom_windows: bool) -> void:
	var cz: float = (z_aft + z_fwd) * 0.5
	var length: float = z_fwd - z_aft
	var h: float = y_top - y_base
	var cy: float = (y_base + y_top) * 0.5
	var t: float = 0.4
	_box(parent, Vector3(-half_w, cy, cz), Vector3(t, h, length), wall, true)
	_box(parent, Vector3(half_w, cy, cz), Vector3(t, h, length), wall, true)
	_box(parent, Vector3(0.0, cy, z_aft), Vector3(half_w * 2.0, h, t), wall, true)
	_box(parent, Vector3(0.0, cy, z_fwd), Vector3(half_w * 2.0, h, t), wall, true)
	_box(parent, Vector3(0.0, y_top - 0.15, cz), Vector3(half_w * 2.0 + 0.6, 0.3, length + 3.0), deck, true)
	var bands: Array = [y_top - 1.4]
	if prom_windows:
		bands = [y_top - 1.4, y_base + 1.7]
	for by in bands:
		_box(parent, Vector3(-half_w - 0.06, float(by), cz), Vector3(0.18, 1.3, length * 0.95), glass, false)
		_box(parent, Vector3(half_w + 0.06, float(by), cz), Vector3(0.18, 1.3, length * 0.95), glass, false)


# Navigating bridge: a wheelhouse box at the forward end of the boat deck with a forward
# window row, flanked by two cantilevered wing platforms reaching out to the ship's sides.
static func _build_bridge(parent: Node3D, wl: float, wall: Material, glass: Material, deck: Material) -> void:
	var L: float = HULL_HALF_LEN
	var y_sun: float = wl + DECK_SUN
	var y_top: float = wl + DECK_SPORTS + 1.2
	var bz: float = SS_FWD * L - 7.0
	_deckhouse(parent, bz - 5.0, bz + 5.0, 12.0, y_sun, y_top, wall, glass, deck, false)
	# Forward-facing wheelhouse windows.
	_box(parent, Vector3(0.0, y_top - 1.3, bz + 5.06), Vector3(22.0, 1.4, 0.18), glass, false)
	# Bridge wings: thin walkable platforms cantilevered to port and starboard.
	for sx in [-1.0, 1.0]:
		_box(parent, Vector3(sx * 15.0, y_sun + 0.0, bz), Vector3(7.0, 0.3, 5.0), deck, true)


# A straight stair run of solid steps climbing from (z_base, y_base) to (z_top, y_top);
# each step is filled to the deck below so the capsule rounds them into a walkable ramp.
static func _stair_run(parent: Node3D, cx: float, z_base: float, z_top: float, y_base: float, y_top: float, width: float, mat: Material) -> void:
	var n: int = 16
	var dz: float = (z_top - z_base) / float(n)
	var dy: float = (y_top - y_base) / float(n)
	for j in range(n):
		var z: float = z_base + (float(j) + 0.5) * dz
		var fill_h: float = float(j + 1) * dy
		_box(parent, Vector3(cx, y_base + fill_h * 0.5, z), Vector3(width, fill_h, absf(dz) + 0.05), mat, true)


# --- Primitives (shared with every later increment) ---------------------------------

# An axis-aligned box mesh, optionally wrapped in a StaticBody box collider so the
# player can stand on / be stopped by it.
static func _box(parent: Node3D, center: Vector3, size: Vector3, mat: Material, collide: bool) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	if collide:
		var body := StaticBody3D.new()
		body.position = center
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		body.add_child(cs)
		parent.add_child(body)
	else:
		mi.position = center
		parent.add_child(mi)


static func _mat(color: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m
