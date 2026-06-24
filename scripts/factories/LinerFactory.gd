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
const COL_TEAK := Color(0.34, 0.25, 0.15)      # teak weather deck (kept dark so the bright sun doesn't blow it out to cream/pink)
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
	_build_funnels(root, wl)
	_build_masts(root, wl)
	_build_lifeboats(root, wl)
	_build_railings(root, wl)
	_build_forecastle(root, wl)
	_build_deck_details(root, wl)
	_build_deck_structures(root, wl)
	_build_portholes(root, wl)

	# --- Four exit gates on the open Main deck (clear of the superstructure): gate 0 on the
	# forecastle by the arrival, then one further forward and two on the aft well deck. All
	# reachable on the flat via the open side decks. ---
	var gates: Array = []
	var gate_zs: Array = [SS_FWD * HULL_HALF_LEN + 18.0, SS_FWD * HULL_HALF_LEN + 38.0, SS_AFT * HULL_HALF_LEN - 22.0, SS_AFT * HULL_HALF_LEN - 44.0]
	for gi in range(4):
		var gz: float = float(gate_zs[gi])
		var lim: float = maxf(_half_beam(gz) - 3.5, 1.0)
		var gx: float = clampf(rng.randf_range(-lim, lim), -lim, lim)
		gates.append(Vector3(gx, _sheer_y(gz, wl) + 0.05, gz))
	return gates


# Deck arrival / spawn: on the open forecastle, looking forward at the pointed bow — so
# the first thing you see is the bow, not the superstructure wall (the aft spawn had you
# hunting the wrong way). Shared by Main's _find_spawn_position and the _scatter_liner teleport.
static func spawn_position(wl: float) -> Vector3:
	var z: float = SS_FWD * HULL_HALF_LEN + 7.0
	return Vector3(0.0, _sheer_y(z, wl) + 1.2, z)


# --- Hull form (longitudinal profiles, all in world space) --------------------------

# Half-beam at longitudinal position z: full amidships, a fine entry forward to a near
# point at the stem, and a rounded cruiser stern aft.
static func _half_beam(z: float) -> float:
	var t: float = z / HULL_HALF_LEN          # -1 (stern) .. +1 (bow)
	if t > 0.30:
		var f: float = (t - 0.30) / 0.70      # 0..1 over the forward run
		return maxf(HULL_HALF_BEAM * (1.0 - pow(f, 1.5)), 0.8)   # fine entry to a sharp stem
	if t < -0.40:
		var a: float = (-t - 0.40) / 0.60     # 0..1 over the aft run
		return maxf(HULL_HALF_BEAM * (1.0 - 0.82 * pow(a, 1.4)), 2.8)   # tapered cruiser stern, less boxy
	return HULL_HALF_BEAM


# World y of the hull bottom (keel) at z: flat amidships at full draught, the forefoot
# rising toward the raked stem and the run rising toward the cruiser stern.
static func _keel_y(z: float, wl: float) -> float:
	var t: float = z / HULL_HALF_LEN
	var deep: float = wl - DRAUGHT
	if t > 0.55:
		return lerpf(deep, wl - 1.5, smoothstep(0.0, 1.0, (t - 0.55) / 0.45))
	if t < -0.50:
		return lerpf(deep, wl - 0.8, smoothstep(0.0, 1.0, (-t - 0.50) / 0.50))   # cruiser stern: run sweeps up to the counter
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
	var body := StaticBody3D.new()
	body.name = "Hull"
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
		# Visual faces, each wound so its normal points OUTWARD (away from the hull axis),
		# so the hull lights correctly from outside instead of going dark where the loft
		# winding would otherwise flip (which read as the bow being "clipped").
		_quad_out(st, dL0, bL0, bL1, dL1, wl)   # port side
		_quad_out(st, dR0, bR0, bR1, dR1, wl)   # starboard side
		_quad_out(st, bL0, bR0, bR1, bL1, wl)   # flat bottom
		# Collision: one SOLID convex slice per segment. A thin trimesh shell is hollow and
		# one-sided in Godot (you can swim through the bow and fall out the bottom — see
		# ConcavePolygonShape3D docs); convex slices are reliably solid from every side, and
		# each slice's top face is the deck.
		var cvx := ConvexPolygonShape3D.new()
		cvx.points = PackedVector3Array([dL0, dR0, dL1, dR1, bL0, bR0, bL1, bR1])
		var cs := CollisionShape3D.new()
		cs.shape = cvx
		body.add_child(cs)
	_cap(st, HULL_HALF_LEN, wl)             # bow (tiny; cull-disabled handles its facing)
	_cap(st, -HULL_HALF_LEN, wl)            # stern
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.55
	mat.metallic = 0.05
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED   # fallback for the tiny end caps
	mi.material_override = mat
	body.add_child(mi)
	parent.add_child(body)


# World Y of the hull's vertical mid-line at z — used to orient faces/normals outward.
static func _hull_mid_y(z: float, wl: float) -> float:
	return (_sheer_y(z, wl) + _keel_y(z, wl)) * 0.5


# A quad whose two triangles are each wound so the normal points away from the hull centre
# axis (outward), whatever order the corners are given in.
static func _quad_out(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, wl: float) -> void:
	_tri_out(st, a, b, c, wl)
	_tri_out(st, a, c, d, wl)


static func _tri_out(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, wl: float) -> void:
	# Godot's generate_normals() treats the opposite winding as front-facing, so emit the
	# order that makes the *engine's* normal point outward (away from the hull axis).
	var centroid: Vector3 = (a + b + c) / 3.0
	var axis := Vector3(0.0, _hull_mid_y(centroid.z, wl), centroid.z)
	if (b - a).cross(c - a).dot(centroid - axis) > 0.0:
		_tri(st, a, c, b, wl)
	else:
		_tri(st, a, b, c, wl)


# The walkable teak weather deck: a flat surface across the beam at the sheer line, run
# right out to the hull edge so there's no lip to fall through into the hull. Lofted as one
# mesh with a trimesh collider so the player stands exactly on it.
static func _build_main_deck(parent: Node3D, wl: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(COL_TEAK)
	var n: int = HULL_STATIONS
	for i in range(n):
		var z0: float = lerpf(-HULL_HALF_LEN, HULL_HALF_LEN, float(i) / float(n))
		var z1: float = lerpf(-HULL_HALF_LEN, HULL_HALF_LEN, float(i + 1) / float(n))
		var b0: float = _half_beam(z0)
		var b1: float = _half_beam(z1)
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
	var mid: float = (s + k) * 0.5
	var dL := Vector3(-b, s, z)
	var dR := Vector3(b, s, z)
	var bL := Vector3(-b * 0.72, k, z)
	var bR := Vector3(b * 0.72, k, z)
	var c := Vector3(0.0, mid, z)
	var outz: float = signf(z)   # the bow cap faces +Z, the stern cap faces -Z
	_cap_tri(st, dL, dR, c, wl, outz)
	_cap_tri(st, dR, bR, c, wl, outz)
	_cap_tri(st, bR, bL, c, wl, outz)
	_cap_tri(st, bL, dL, c, wl, outz)


# A cap fan triangle wound so the engine's normal points outward along ±Z (seals the hull
# end so you can't see into the interior from dead ahead/astern).
static func _cap_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, wl: float, outz: float) -> void:
	if (b - a).cross(c - a).z * outz > 0.0:
		_tri(st, a, c, b, wl)
	else:
		_tri(st, a, b, c, wl)


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

	# Base block: Main deck -> open Boat/Sun deck, enclosing the A and Promenade decks.
	_deckhouse(root, SS_AFT * L, SS_FWD * L, SS_HALF_W, y_main, y_sun, white, glass, deck, false)
	# Three window rows down each long side: boat-deck, the big square Promenade row, A deck.
	_promenade_windows(root, SS_AFT * L, SS_FWD * L, SS_HALF_W, wl, glass)
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


# Three rows of windows down each long side of the base block: continuous dark glazing
# strips (boat-deck, the tall Promenade row, A-deck), with white mullions dividing the
# Promenade strip into individual square windows. Reads as a glazed promenade at deck scale.
static func _promenade_windows(parent: Node3D, z_aft: float, z_fwd: float, half_w: float, wl: float, glass_unused: Material) -> void:
	var cz: float = (z_aft + z_fwd) * 0.5
	var length: float = z_fwd - z_aft
	var glaze := _mat(Color(0.07, 0.09, 0.13), 0.7, 0.0)
	var white := _mat(COL_SUPER, 0.7, 0.0)
	# each row: [world-y above wl, strip height]
	for spec in [[16.2, 1.9], [18.2, 0.9], [13.7, 1.0]]:
		var y: float = wl + float(spec[0])
		var hh: float = float(spec[1])
		for sx in [-1.0, 1.0]:
			_box(parent, Vector3(sx * (half_w + 0.26), y, cz), Vector3(0.14, hh, length * 0.97), glaze, false)
	# Mullions on the Promenade strip: thin white verticals every ~3.2 m -> square windows.
	var nm: int = maxi(int(length / 3.2), 1)
	for i in range(nm + 1):
		var z: float = z_aft + float(i) * (length / float(nm))
		for sx2 in [-1.0, 1.0]:
			_box(parent, Vector3(sx2 * (half_w + 0.30), wl + 16.2, z), Vector3(0.2, 2.1, 0.2), white, false)


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
	var hw: float = 12.0
	var glaze := _mat(Color(0.07, 0.09, 0.13), 0.7, 0.0)
	_deckhouse(parent, bz - 5.0, bz + 5.0, hw, y_sun, y_top, wall, glass, deck, false)
	# Wheelhouse windows: a continuous dark strip across the front and down each side.
	var wy: float = y_top - 1.3
	_box(parent, Vector3(0.0, wy, bz + 5.12), Vector3(hw * 2.0 - 1.0, 1.5, 0.16), glaze, false)
	for sx in [-1.0, 1.0]:
		_box(parent, Vector3(sx * (hw + 0.08), wy, bz), Vector3(0.16, 1.5, 9.0), glaze, false)
	# Monkey island / compass platform on the wheelhouse roof, with side rails.
	_box(parent, Vector3(0.0, y_top + 0.55, bz), Vector3(8.0, 0.25, 6.0), deck, true)
	for sx in [-1.0, 1.0]:
		_box(parent, Vector3(sx * 4.0, y_top + 1.05, bz), Vector3(0.1, 0.9, 6.0), wall, true)
	# Bridge wings: walkable platforms cantilevered to the ship's sides, each with a wing cab
	# (the open-bridge control position), a cab window, and a forward dodger screen.
	for sx2 in [-1.0, 1.0]:
		_box(parent, Vector3(sx2 * 15.0, y_sun, bz), Vector3(7.0, 0.3, 5.0), deck, true)
		_box(parent, Vector3(sx2 * 17.4, y_sun + 1.3, bz), Vector3(2.0, 2.5, 2.6), wall, true)
		_box(parent, Vector3(sx2 * 17.4, y_sun + 1.9, bz + 1.36), Vector3(2.0, 1.0, 0.14), glaze, false)
		_box(parent, Vector3(sx2 * 15.0, y_sun + 0.55, bz - 2.45), Vector3(7.0, 0.9, 0.1), wall, true)


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


# --- Funnels & masts ----------------------------------------------------------------

# Three Cunard funnels over midships, seated on the boat-deck house (Sports deck level):
# elliptical (longer fore-and-aft than wide, ~11 x 7 m), red with black tops and two thin
# black bands, the forward funnel tallest and stepping down aft so the forward funnel tops
# out ~43 m above the waterline.
static func _build_funnels(parent: Node3D, wl: float) -> void:
	var root := Node3D.new()
	root.name = "Funnels"
	parent.add_child(root)
	var red := _mat(Color(0.80, 0.27, 0.10), 0.55, 0.0)   # Cunard red
	var black := _mat(Color(0.06, 0.06, 0.07), 0.6, 0.0)
	var base_y: float = wl + DECK_SPORTS
	_funnel(root, 35.0, base_y, 20.0, red, black)
	_funnel(root, -2.0, base_y, 19.0, red, black)
	_funnel(root, -39.0, base_y, 18.0, red, black)


static func _funnel(parent: Node3D, cz: float, base_y: float, height: float, red: Material, black: Material) -> void:
	var top_y: float = base_y + height
	var cy: float = base_y + height * 0.5
	var ax: float = 3.5    # half-width athwartships (X) — 7 m
	var az: float = 5.5    # half-length fore-and-aft (Z) — 11 m
	_ellipse_cyl(parent, Vector3(0.0, cy, cz), 1.0, height, ax, az, red, 0.92)
	var cap: float = 2.8
	_ellipse_cyl(parent, Vector3(0.0, top_y - cap * 0.5, cz), 0.96, cap, ax, az, black, 0.94)
	for bi in range(2):
		var by: float = top_y - cap - 0.9 - float(bi) * 1.1
		_ellipse_cyl(parent, Vector3(0.0, by, cz), 1.0, 0.45, ax, az, black, 1.0)
	# Invisible collider just inside the ellipse so the player walks around it on deck.
	_collider_box(parent, Vector3(0.0, cy, cz), Vector3(ax * 1.85, height, az * 1.85))


# Two raked-free masts on the centreline: a tall foremast just abaft the bridge and a
# mainmast aft, each a tapered buff pole with a signal yard near the top.
static func _build_masts(parent: Node3D, wl: float) -> void:
	var root := Node3D.new()
	root.name = "Masts"
	parent.add_child(root)
	var buff := _mat(Color(0.80, 0.68, 0.45), 0.5, 0.2)
	_mast(root, Vector3(0.0, wl + DECK_SPORTS, 50.0), 27.0, buff)
	_mast(root, Vector3(0.0, wl + DECK_SPORTS, -55.0), 23.0, buff)


static func _mast(parent: Node3D, base: Vector3, height: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = 0.55
	cm.top_radius = 0.18
	cm.height = height
	cm.radial_segments = 10
	mi.mesh = cm
	mi.material_override = mat
	mi.position = base + Vector3(0.0, height * 0.5, 0.0)
	parent.add_child(mi)
	var yard := MeshInstance3D.new()
	var ym := BoxMesh.new()
	ym.size = Vector3(11.0, 0.3, 0.3)
	yard.mesh = ym
	yard.material_override = mat
	yard.position = base + Vector3(0.0, height * 0.66, 0.0)
	parent.add_child(yard)


# A vertical cylinder stretched into an ellipse (scale x by sx, z by sz); slight taper via
# top_factor. Visual only — funnels carry a separate box collider.
static func _ellipse_cyl(parent: Node3D, center: Vector3, bottom_r: float, height: float, sx: float, sz: float, mat: Material, top_factor: float = 1.0) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = bottom_r
	cm.top_radius = bottom_r * top_factor
	cm.height = height
	cm.radial_segments = 22
	mi.mesh = cm
	mi.material_override = mat
	mi.position = center
	mi.scale = Vector3(sx, 1.0, sz)
	parent.add_child(mi)


# --- Lifeboats, davits & railings ---------------------------------------------------

# 24 lifeboats (12 a side) lined up on the boat-deck walkways, each on two davit posts.
# Both are one MultiMesh apiece (one draw call) — decorative, no collision (the boat-deck
# railing keeps the player aboard).
static func _build_lifeboats(parent: Node3D, wl: float) -> void:
	var root := Node3D.new()
	root.name = "Lifeboats"
	parent.add_child(root)
	var L: float = HULL_HALF_LEN
	var deck_y: float = wl + DECK_SUN
	var boat_mesh := BoxMesh.new()
	boat_mesh.size = Vector3(2.8, 1.8, 9.0)
	var boat_mat := _mat(Color(0.90, 0.88, 0.80), 0.7, 0.0)
	var davit_mesh := BoxMesh.new()
	davit_mesh.size = Vector3(0.18, 2.4, 0.18)
	var davit_mat := _mat(Color(0.20, 0.21, 0.23), 0.6, 0.4)
	var boats: Array = []
	var davits: Array = []
	for side in [-1.0, 1.0]:
		for k in range(12):
			var z: float = lerpf(BH_AFT * L + 6.0, BH_FWD * L - 6.0, float(k) / 11.0)
			boats.append(Transform3D(Basis(), Vector3(side * 12.0, deck_y + 1.2, z)))
			for dz in [-3.8, 3.8]:
				davits.append(Transform3D(Basis(), Vector3(side * 10.8, deck_y + 1.2, z + float(dz))))
	MultiMeshScatter.build(root, "LifeboatHulls", boat_mesh, boat_mat, boats)
	MultiMeshScatter.build(root, "DavitPosts", davit_mesh, davit_mat, davits)


# Perimeter railings that keep the player aboard (collidable): a bulwark following the
# curved Main-deck sheer all the way round, plus port/starboard rails on the Boat and
# Sports decks (their fore/aft ends are left open for the companionways and step-downs).
static func _build_railings(parent: Node3D, wl: float) -> void:
	var root := Node3D.new()
	root.name = "Railings"
	parent.add_child(root)
	var rail := _mat(Color(0.86, 0.86, 0.83), 0.6, 0.0)
	var L: float = HULL_HALF_LEN
	var h: float = 1.05
	var n: int = 26
	for i in range(n):
		var z0: float = lerpf(-L, L, float(i) / float(n))
		var z1: float = lerpf(-L, L, float(i + 1) / float(n))
		var b0: float = _half_beam(z0) * 0.96
		var b1: float = _half_beam(z1) * 0.96
		var s0: float = _sheer_y(z0, wl)
		var s1: float = _sheer_y(z1, wl)
		_rail_segment(root, -b0, s0, z0, -b1, s1, z1, h, rail)
		_rail_segment(root, b0, s0, z0, b1, s1, z1, h, rail)
	# Close the bow AND the stern transom: the converging side rails leave a gap to run off
	# at each end, so cap both with a cross-rail spanning the deck there.
	for end_z in [L - 5.0, -L + 5.0]:
		var ew: float = _half_beam(end_z) * 0.96
		_box(root, Vector3(0.0, _sheer_y(end_z, wl) + h * 0.5, end_z), Vector3(ew * 2.0 + 0.3, h, 0.12), rail, true)
	_deck_side_rails(root, SS_AFT * L, SS_FWD * L, SS_HALF_W, wl + DECK_SUN, h, rail)
	_deck_side_rails(root, BH_AFT * L, BH_FWD * L, BH_HALF_W, wl + DECK_SPORTS, h, rail)


# A railing run between two deck-edge points, standing `h` above the deck.
static func _rail_segment(parent: Node3D, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, h: float, mat: Material) -> void:
	var dx: float = x1 - x0
	var dz: float = z1 - z0
	var length: float = sqrt(dx * dx + dz * dz) + 0.1
	var cy: float = (y0 + y1) * 0.5 + h * 0.5
	_oriented_box(parent, Vector3((x0 + x1) * 0.5, cy, (z0 + z1) * 0.5), Vector3(0.12, h, length), atan2(dx, dz), mat, true)


# Port + starboard rails along a rectangular upper deck (fore/aft left open for stairs).
static func _deck_side_rails(parent: Node3D, z_aft: float, z_fwd: float, half_w: float, y_deck: float, h: float, mat: Material) -> void:
	var cz: float = (z_aft + z_fwd) * 0.5
	var length: float = z_fwd - z_aft
	var cy: float = y_deck + h * 0.5
	_box(parent, Vector3(-half_w, cy, cz), Vector3(0.12, h, length), mat, true)
	_box(parent, Vector3(half_w, cy, cz), Vector3(0.12, h, length), mat, true)


# --- Forecastle: foredeck fittings so the bow reads as a real ship, not a bare deck ---

static func _build_forecastle(parent: Node3D, wl: float) -> void:
	var root := Node3D.new()
	root.name = "Forecastle"
	parent.add_child(root)
	var white := _mat(COL_SUPER, 0.7, 0.0)
	var grey := _mat(Color(0.55, 0.56, 0.58), 0.7, 0.2)
	var dark := _mat(Color(0.30, 0.31, 0.34), 0.6, 0.3)
	var buff := _mat(Color(0.80, 0.68, 0.45), 0.5, 0.2)

	# Breakwater: a low chevron wall pointing forward, throwing spray off the foredeck.
	var bd: float = _sheer_y(92.0, wl)
	_oriented_box(root, Vector3(-4.5, bd + 0.75, 92.0), Vector3(0.3, 1.5, 11.0), 0.42, white, true)
	_oriented_box(root, Vector3(4.5, bd + 0.75, 92.0), Vector3(0.3, 1.5, 11.0), -0.42, white, true)

	# Forward kingpost (cargo mast) with a derrick yard — vertical presence at the bow.
	_mast(root, Vector3(0.0, _sheer_y(96.0, wl), 96.0), 17.0, buff)

	# Anchor windlass house + two warping drums.
	var wd: float = _sheer_y(112.0, wl)
	_box(root, Vector3(0.0, wd + 0.9, 112.0), Vector3(7.0, 1.8, 4.0), dark, true)
	for sx in [-1.9, 1.9]:
		_ellipse_cyl(root, Vector3(float(sx), wd + 2.15, 112.0), 0.7, 0.7, 1.0, 1.0, grey)

	# Mooring bollards toward the bow.
	for spec in [[-4.0, 122.0], [4.0, 122.0], [-2.8, 133.0], [2.8, 133.0]]:
		var bz: float = float(spec[1])
		_ellipse_cyl(root, Vector3(float(spec[0]), _sheer_y(bz, wl) + 0.45, bz), 0.32, 0.9, 1.0, 1.0, dark)

	# Cowl ventilators flanking the forward deck.
	for sx2 in [-7.0, 7.0]:
		var vd: float = _sheer_y(85.0, wl)
		_ellipse_cyl(root, Vector3(float(sx2), vd + 1.1, 85.0), 0.5, 2.2, 1.0, 1.0, white)
		_box(root, Vector3(float(sx2), vd + 2.3, 85.4), Vector3(1.0, 0.9, 0.9), white, false)

	# Jackstaff at the stem.
	_box(root, Vector3(0.0, _sheer_y(149.0, wl) + 3.0, 149.0), Vector3(0.16, 6.0, 0.16), buff, false)


# --- Deck details: cowl ventilators + aft mooring gear, to fill out the open decks ---

static func _build_deck_details(parent: Node3D, wl: float) -> void:
	var root := Node3D.new()
	root.name = "DeckDetails"
	parent.add_child(root)
	var white := _mat(COL_SUPER, 0.7, 0.0)
	var ventred := _mat(Color(0.68, 0.20, 0.12), 0.6, 0.0)
	var dark := _mat(Color(0.30, 0.31, 0.34), 0.6, 0.3)
	var boat_y: float = wl + DECK_SUN

	# Cowl ventilators in the open boat-deck spaces fore and aft of the funnel casing.
	var vents: Array = [
		[Vector3(-9.5, boat_y, -82.0), 1.0], [Vector3(9.5, boat_y, -82.0), 1.0],
		[Vector3(-5.5, boat_y, -75.0), -1.0], [Vector3(5.5, boat_y, -75.0), -1.0],
		[Vector3(-10.0, boat_y, -67.0), 1.0], [Vector3(10.0, boat_y, -67.0), 1.0],
		[Vector3(-9.5, boat_y, 65.0), -1.0], [Vector3(9.5, boat_y, 65.0), -1.0],
	]
	for v in vents:
		_cowl_vent(root, v[0], float(v[1]), white, ventred)

	# Aft mooring gear near the stern (clear of the aft gates): capstans + bollards.
	for spec in [[-3.5, -142.0], [3.5, -142.0]]:
		var cz: float = float(spec[1])
		_ellipse_cyl(root, Vector3(float(spec[0]), _sheer_y(cz, wl) + 0.6, cz), 0.6, 1.2, 1.0, 1.0, dark)
	for spec2 in [[-2.6, -148.0], [2.6, -148.0]]:
		var bz: float = float(spec2[1])
		_ellipse_cyl(root, Vector3(float(spec2[0]), _sheer_y(bz, wl) + 0.4, bz), 0.3, 0.8, 1.0, 1.0, dark)


# Deck houses (fan houses) between the funnels on the sports deck, and glass skylights over
# the public rooms on the boat deck — to fill the otherwise-bare upper decks.
static func _build_deck_structures(parent: Node3D, wl: float) -> void:
	var root := Node3D.new()
	root.name = "DeckStructures"
	parent.add_child(root)
	var white := _mat(COL_SUPER, 0.7, 0.0)
	var glaze := _mat(Color(0.10, 0.16, 0.22), 0.3, 0.1)
	var sports_y: float = wl + DECK_SPORTS
	for dz in [52.0, 16.0, -20.0]:
		_box(root, Vector3(0.0, sports_y + 1.0, float(dz)), Vector3(6.0, 2.0, 5.0), white, true)
		_box(root, Vector3(0.0, sports_y + 1.6, float(dz) + 2.56), Vector3(5.0, 0.8, 0.14), glaze, false)
	var boat_y: float = wl + DECK_SUN
	for sz in [-80.0, 68.0]:
		_box(root, Vector3(0.0, boat_y + 0.35, float(sz)), Vector3(6.0, 0.5, 4.0), white, true)
		_box(root, Vector3(0.0, boat_y + 0.72, float(sz)), Vector3(5.2, 0.25, 3.2), glaze, false)


# A cowl ventilator: a vertical trunk with a bell mouth bent to face fore or aft.
static func _cowl_vent(parent: Node3D, base: Vector3, face: float, body: Material, mouth: Material) -> void:
	_ellipse_cyl(parent, base + Vector3(0.0, 1.15, 0.0), 0.38, 2.3, 1.0, 1.0, body)
	var head := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.52
	cm.bottom_radius = 0.36
	cm.height = 0.95
	cm.radial_segments = 12
	head.mesh = cm
	head.material_override = mouth
	head.position = base + Vector3(0.0, 2.45, 0.3 * face)
	head.rotation = Vector3(deg_to_rad(58.0 * face), 0.0, 0.0)
	parent.add_child(head)


# Two rows of portholes down the black hull sides (A and B deck), as one MultiMesh of
# brass-rimmed discs sitting on the actual hull surface at each height.
static func _build_portholes(parent: Node3D, wl: float) -> void:
	var root := Node3D.new()
	root.name = "Portholes"
	parent.add_child(root)
	var brass := _mat(Color(0.52, 0.46, 0.30), 0.4, 0.5)
	var rim := CylinderMesh.new()
	rim.top_radius = 0.32
	rim.bottom_radius = 0.32
	rim.height = 0.14
	rim.radial_segments = 10
	var face := Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(90.0))   # disc axis -> X (faces outboard)
	var tf: Array = []
	var z: float = -HULL_HALF_LEN + 22.0
	while z < HULL_HALF_LEN - 22.0:
		var k: float = _keel_y(z, wl)
		var s: float = _sheer_y(z, wl)
		var b: float = _half_beam(z)
		for yy in [4.5, 7.4]:
			var frac: float = clampf((float(yy) - k) / (s - k), 0.0, 1.0)
			var bw: float = b * (0.72 + 0.28 * frac) + 0.06
			for side in [-1.0, 1.0]:
				tf.append(Transform3D(face, Vector3(side * bw, float(yy), z)))
		z += 3.2
	MultiMeshScatter.build(root, "PortholeRims", rim, brass, tf)


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


# An invisible box collider (StaticBody + shape, no mesh) — for funnels and other props
# whose visible mesh is a scaled/elliptical shape that shouldn't carry the collision.
static func _collider_box(parent: Node3D, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	parent.add_child(body)


# A box with a Y rotation (for railing runs that follow the curved deck edge).
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


static func _mat(color: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m
