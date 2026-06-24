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

# Deck heights ABOVE the waterline (world y = wl + these), to documented 1:1 figures:
# keel->Promenade Deck = 92.5 ft (28.2 m) less the 11.8 m draught puts the Promenade at 16.4 m;
# keel->C Deck = 55.25 ft fixes the lower-deck spacing at ~2.84 m (9.3 ft). The public-room decks
# (Promenade and up) stand taller than the cabin decks the way the real ship's did — the Promenade
# gets a ~3.3 m deckhead so a 1.8 m player isn't brushing the deck beams (the Sun/Sports decks ride
# up with it; the lower Main/A decks keep the 2.84 m cabin spacing).
const DECK_MAIN: float = 13.56     # Main deck: open forecastle + aft deck, base of the deckhouse
const DECK_PROM: float = 16.40     # Promenade deck (the long enclosed promenade)
const DECK_SUN: float = 19.74      # boat / sun deck: lifeboats + funnel casings (lifted for a taller Promenade below)
const DECK_SPORTS: float = 22.58   # sports deck (topmost open deck)

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
# house then carries the funnels up to the Sports deck. SS_HALF_W runs the deckhouse out
# close to the shell (~92% of the 18 m half-beam) the way the real enclosed Promenade Deck
# does — only a ~1.5 m open side deck remains along the Main deck for the fore-aft walk.
# SS_AFT/SS_FWD run the deckhouse out to ~81% of the LOA (the way the real Promenade Deck does),
# leaving a ~34 m open forecastle forward and a ~23 m open deck aft. All the fore/aft fittings are
# positioned relative to these so they ride with the deckhouse ends.
const SS_AFT: float = -0.85
const SS_FWD: float = 0.78
const SS_HALF_W: float = 16.5
const SS_SIDE_DECK: float = 1.2    # open side-deck margin kept between the deckhouse wall and the hull edge
const BH_AFT: float = -0.40
const BH_FWD: float = 0.40
const BH_HALF_W: float = 8.0
# Amidships full-width core of the Promenade interior (fit-out + floor) — the band where the
# tapering deckhouse is still near full beam, so the furniture/floor never poke through the walls.
const PROM_AFT: float = -68.0
const PROM_FWD: float = 62.0
const PROM_HALF_W: float = 15.5


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
	_build_flags(root, wl)
	_build_anchors(root, wl)
	_build_interior(root, wl)

	# --- Four exit gates on the open weather decks, within the deck width and clear of deck gear:
	# one by the arrival on the narrow forecastle, three on the wider after deck (starboard, clear
	# of the port companionway + mooring). A small per-seed jitter keeps them in the clear zones. ---
	var gates: Array = []
	var gate_specs: Array = [
		[0.0, SS_FWD * HULL_HALF_LEN + 3.0],     # forecastle centreline, between the door and the cowl vents
		[-3.0, SS_AFT * HULL_HALF_LEN - 4.0],    # after deck, port, clear of the capstans
		[3.0, SS_AFT * HULL_HALF_LEN - 4.0],     # after deck, starboard
		[0.0, SS_AFT * HULL_HALF_LEN - 9.0],     # after deck centreline, between capstans and bollards
	]
	for spec in gate_specs:
		var gz: float = float(spec[1]) + rng.randf_range(-0.5, 0.5)
		var gx: float = float(spec[0]) + rng.randf_range(-0.4, 0.4)
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
		return maxf(HULL_HALF_BEAM * (1.0 - pow(f, 1.5)), 0.2)   # fine entry running right out to a sharp stem
	if t < -0.40:
		var a: float = (-t - 0.40) / 0.60     # 0..1 over the aft run
		# Rounded cruiser stern: carry the beam well aft, then sweep the quarters in to a small rounded
		# counter. sqrt(1 - a^n) has a near-vertical tangent at the end — a ROUND transom, not a flat cut.
		return maxf(HULL_HALF_BEAM * sqrt(maxf(1.0 - pow(a, 2.6), 0.0)), 0.5)
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
	# Tinted, see-through glazing for the enclosed Promenade windows (look out at the sea).
	var seaglass := StandardMaterial3D.new()
	seaglass.albedo_color = Color(0.18, 0.28, 0.36, 0.42)
	seaglass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	seaglass.roughness = 0.08
	seaglass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var L: float = HULL_HALF_LEN
	var y_main: float = wl + DECK_MAIN
	var y_sun: float = wl + DECK_SUN
	var y_sports: float = wl + DECK_SPORTS

	# Base block: Main deck -> open Boat/Sun deck, enclosing the A and Promenade decks. A door
	# in the forward wall lets you walk in off the forecastle; the long sides carry the big
	# Promenade windows as a real see-through glazed band over a waist-high dado (sill 17.4 ->
	# head 18.8, i.e. 1 m of dado above the 16.4 m Promenade floor), matching the enclosed promenade.
	_deckhouse_tapered(root, SS_AFT * L, SS_FWD * L, y_main, y_sun, white, deck, seaglass, -4.0, wl + 17.4, wl + 18.8)
	# Centreline boat-deck house: Boat/Sun -> Sports deck, the funnel casing base. Narrow,
	# so the boat-deck walkways (for the lifeboats) stay open along each side.
	# Sun/boat-deck house above the Promenade: a wide tapered deckhouse with a cabin-window band —
	# the wedding-cake second tier the funnels rise from — set inboard so the lifeboat walkways stay
	# open outboard. (Was a narrow ±8 funnel casing, which read as a thin slab.)
	_upper_house(root, -78.0, 78.0, 13.0, 3.0, y_sun, y_sports, white, glass, deck, wl + 20.5, wl + 21.6)
	# Navigating bridge across the forward end of the boat deck, with wing platforms.
	_build_bridge(root, wl, white, glass, deck)

	# Companionways linking the open decks: up the aft well deck to the Boat deck, on up to
	# the Sports deck, and a forward flight to the forecastle. The fore/aft weather decks rise
	# toward the ends (sheer), so each base sits at the local sheer, not the flat mid-ship deck,
	# or the stair hangs below the deck it lands on. Solid steps the capsule rounds into a ramp.
	# Kept well inboard so they land on the now-tapered (narrower) boat-deck ends, not off the edge.
	_stair_run(root, -3.0, SS_AFT * L - 13.0, SS_AFT * L - 1.5, _sheer_y(SS_AFT * L - 13.0, wl), y_sun, 4.0, deck)
	_stair_run(root, 0.0, BH_AFT * L - 9.0, BH_AFT * L - 1.5, y_sun, y_sports, 3.6, deck)
	_stair_run(root, 3.0, SS_FWD * L + 13.0, SS_FWD * L + 1.5, _sheer_y(SS_FWD * L + 13.0, wl), y_sun, 4.0, deck)


# Three rows of windows down each long side of the base block: continuous dark glazing
# strips (boat-deck, the tall Promenade row, A-deck), with white mullions dividing the
# Promenade strip into individual square windows. Reads as a glazed promenade at deck scale.
static func _promenade_windows(parent: Node3D, z_aft: float, z_fwd: float, half_w: float, wl: float, glass_unused: Material) -> void:
	var cz: float = (z_aft + z_fwd) * 0.5
	var length: float = z_fwd - z_aft
	var glaze := _mat(Color(0.07, 0.09, 0.13), 0.7, 0.0)
	# A-deck window strip below the Promenade glazing (exterior decoration on the solid sill
	# course). The big Promenade row and the row above it are now the real see-through glazed
	# band built into the side walls by _deckhouse, so they're no longer drawn here.
	for sx in [-1.0, 1.0]:
		_box(parent, Vector3(sx * (half_w + 0.26), wl + 13.7, cz), Vector3(0.14, 1.0, length * 0.97), glaze, false)


# A white deckhouse box: four walls + a walkable top-deck slab (overhanging slightly to
# meet stairs and deck edges), with dark window bands on the long sides.
static func _deckhouse(parent: Node3D, z_aft: float, z_fwd: float, half_w: float, y_base: float, y_top: float, wall: Material, glass: Material, deck: Material, prom_windows: bool, fwd_door_x: float = NAN, glaze_y0: float = NAN, glaze_y1: float = NAN, glaze_mat: Material = null) -> void:
	var cz: float = (z_aft + z_fwd) * 0.5
	var length: float = z_fwd - z_aft
	# Walls stop 0.3 m below the deck and the teak slab oversails them (its underside buried in
	# the wall tops), so the white wall tops are never coplanar with the teak deck surface —
	# that exact coincidence z-fought as a dashed white line running along the deck.
	var wall_top: float = y_top - 0.3
	var h: float = wall_top - y_base
	var cy: float = (y_base + wall_top) * 0.5
	var t: float = 0.4
	for sgn in [-1.0, 1.0]:
		var xw: float = sgn * half_w
		if is_nan(glaze_y0):
			_box(parent, Vector3(xw, cy, cz), Vector3(t, h, length), wall, true)
		else:
			# Solid sill course below + a solid spandrel above, with a see-through glazed band
			# between — the enclosed Promenade as a wall of sea-view glass.
			_box(parent, Vector3(xw, (y_base + glaze_y0) * 0.5, cz), Vector3(t, glaze_y0 - y_base, length), wall, true)
			_box(parent, Vector3(xw, (glaze_y1 + wall_top) * 0.5, cz), Vector3(t, wall_top - glaze_y1, length), wall, true)
			# Tinted glazing filling the band, collidable so you can look out but not fall out.
			_box(parent, Vector3(xw, (glaze_y0 + glaze_y1) * 0.5, cz), Vector3(t * 0.5, glaze_y1 - glaze_y0, length * 0.99), glaze_mat, true)
			# Sill + head rails and vertical mullions framing the glass.
			_box(parent, Vector3(xw, glaze_y0, cz), Vector3(t + 0.12, 0.14, length), wall, false)
			_box(parent, Vector3(xw, glaze_y1, cz), Vector3(t + 0.12, 0.14, length), wall, false)
			var nmul: int = maxi(int(length / 3.4), 1)
			for i in range(nmul + 1):
				var mz: float = z_aft + length * float(i) / float(nmul)
				_box(parent, Vector3(xw, (glaze_y0 + glaze_y1) * 0.5, mz), Vector3(t + 0.1, glaze_y1 - glaze_y0, 0.24), wall, false)
	_box(parent, Vector3(0.0, cy, z_aft), Vector3(half_w * 2.0, h, t), wall, true)
	if is_nan(fwd_door_x):
		_box(parent, Vector3(0.0, cy, z_fwd), Vector3(half_w * 2.0, h, t), wall, true)
	else:
		# Entry doorway in the forward wall (onto the forecastle): two jambs + a lintel over it.
		var dw: float = 3.2
		var dh: float = 2.4
		var da: float = fwd_door_x - dw * 0.5
		var db: float = fwd_door_x + dw * 0.5
		_box(parent, Vector3((-half_w + da) * 0.5, cy, z_fwd), Vector3(da + half_w, h, t), wall, true)
		_box(parent, Vector3((db + half_w) * 0.5, cy, z_fwd), Vector3(half_w - db, h, t), wall, true)
		var ly: float = y_base + dh
		_box(parent, Vector3(fwd_door_x, (ly + wall_top) * 0.5, z_fwd), Vector3(dw, wall_top - ly, t), wall, true)
	_box(parent, Vector3(0.0, y_top - 0.175, cz), Vector3(half_w * 2.0 + 0.6, 0.35, length + 3.0), deck, true)
	var bands: Array = [y_top - 1.4]
	if prom_windows:
		bands = [y_top - 1.4, y_base + 1.7]
	for by in bands:
		_box(parent, Vector3(-half_w - 0.06, float(by), cz), Vector3(0.18, 1.3, length * 0.95), glass, false)
		_box(parent, Vector3(half_w + 0.06, float(by), cz), Vector3(0.18, 1.3, length * 0.95), glass, false)


# Deckhouse half-width at z: the amidships cap (SS_HALF_W) but never wider than the hull at
# that station less a side-deck margin, so the white block follows the fining hull toward the
# ends instead of overhanging it (which had the superstructure jutting over the water).
static func _house_half_w(z: float, cap: float = SS_HALF_W, side: float = SS_SIDE_DECK) -> float:
	return minf(cap, _half_beam(z) - side)


# One wall strip: an oriented box between two deck-plan points (xa,za)->(xb,zb), spanning
# y_lo..y_hi, yawed to follow the taper. Reused for the sill course, glazed band and spandrel.
static func _wall_strip(parent: Node3D, xa: float, za: float, xb: float, zb: float, y_lo: float, y_hi: float, t: float, mat: Material, collide: bool) -> void:
	var dx: float = xb - xa
	var dz: float = zb - za
	var length: float = sqrt(dx * dx + dz * dz) + 0.02
	_oriented_box(parent, Vector3((xa + xb) * 0.5, (y_lo + y_hi) * 0.5, (za + zb) * 0.5), Vector3(t, y_hi - y_lo, length), atan2(dx, dz), mat, collide)


# A flat walkable slab at constant y_top, lofted to follow the deckhouse taper out to
# half-width+overhang at each station (top + underside + edge skirts), with a trimesh collider —
# the boat/sun deck slab on the tapered base block.
static func _tapered_slab(parent: Node3D, z_aft: float, z_fwd: float, y_top: float, thick: float, overhang: float, mat: Material, cap: float = SS_HALF_W, side: float = SS_SIDE_DECK) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color(0.34, 0.25, 0.15))
	var yb: float = y_top - thick
	var n: int = 24
	for i in range(n):
		var z0: float = lerpf(z_aft, z_fwd, float(i) / float(n))
		var z1: float = lerpf(z_aft, z_fwd, float(i + 1) / float(n))
		var w0: float = _house_half_w(z0, cap, side) + overhang
		var w1: float = _house_half_w(z1, cap, side) + overhang
		_quad_flat(st, Vector3(-w0, y_top, z0), Vector3(w0, y_top, z0), Vector3(w1, y_top, z1), Vector3(-w1, y_top, z1))
		_quad_flat(st, Vector3(-w0, yb, z0), Vector3(-w1, yb, z1), Vector3(w1, yb, z1), Vector3(w0, yb, z0))
		_quad_flat(st, Vector3(w0, y_top, z0), Vector3(w0, yb, z0), Vector3(w1, yb, z1), Vector3(w1, y_top, z1))
		_quad_flat(st, Vector3(-w0, y_top, z0), Vector3(-w1, y_top, z1), Vector3(-w1, yb, z1), Vector3(-w0, yb, z0))
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var body := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var dm := StandardMaterial3D.new()
	dm.albedo_color = COL_TEAK
	dm.roughness = 0.9
	dm.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = dm
	body.add_child(mi)
	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	body.add_child(col)
	parent.add_child(body)


# The long base-block deckhouse, tapered to follow the hull: port + starboard walls lofted as
# yawed strips (solid sill course, a see-through glazed Promenade band, solid spandrel) over N
# stations, vertical mullions at each station, solid aft cap, a forward cap with the entry door,
# and a tapered oversailing boat-deck slab.
static func _deckhouse_tapered(parent: Node3D, z_aft: float, z_fwd: float, y_base: float, y_top: float, wall: Material, deck: Material, glaze_mat: Material, fwd_door_x: float, glaze_y0: float, glaze_y1: float) -> void:
	var wall_top: float = y_top - 0.3
	var t: float = 0.4
	var n: int = 22
	for s in [-1.0, 1.0]:
		for i in range(n):
			var z0: float = lerpf(z_aft, z_fwd, float(i) / float(n))
			var z1: float = lerpf(z_aft, z_fwd, float(i + 1) / float(n))
			var x0: float = s * _house_half_w(z0)
			var x1: float = s * _house_half_w(z1)
			_wall_strip(parent, x0, z0, x1, z1, y_base, glaze_y0, t, wall, true)            # sill course
			_wall_strip(parent, x0, z0, x1, z1, glaze_y1, wall_top, t, wall, true)          # spandrel
			_wall_strip(parent, x0, z0, x1, z1, glaze_y0, glaze_y1, t * 0.5, glaze_mat, true) # glazed band (collidable)
			_wall_strip(parent, x0, z0, x1, z1, glaze_y0 - 0.07, glaze_y0 + 0.07, t + 0.12, wall, false) # sill rail
			_wall_strip(parent, x0, z0, x1, z1, glaze_y1 - 0.07, glaze_y1 + 0.07, t + 0.12, wall, false) # head rail
		for i in range(n + 1):
			var mz: float = lerpf(z_aft, z_fwd, float(i) / float(n))
			_box(parent, Vector3(s * _house_half_w(mz), (glaze_y0 + glaze_y1) * 0.5, mz), Vector3(t + 0.1, glaze_y1 - glaze_y0, 0.24), wall, false)
	var hwa: float = _house_half_w(z_aft)
	_box(parent, Vector3(0.0, (y_base + wall_top) * 0.5, z_aft), Vector3(hwa * 2.0, wall_top - y_base, t), wall, true)
	# The forward (entry) wall stands where the weather deck has risen on the bow sheer, ~1.3 m above
	# the flat amidships y_base — so size the door to clear ~2.1 m above the LOCAL deck, else the
	# lintel lands at chest height (the short doorway the player hit right at the spawn).
	var wl_local: float = y_base - DECK_MAIN
	var door_h: float = (_sheer_y(z_fwd, wl_local) - y_base) + 2.1
	_transverse_door_wall(parent, z_fwd, _house_half_w(z_fwd), y_base, wall_top, t, fwd_door_x, 3.2, door_h, wall)
	_tapered_slab(parent, z_aft - 1.5, z_fwd + 1.5, y_top, 0.35, 0.5, deck)


# A tapered upper-works deckhouse (the sun-deck house the funnels rise from, or a sports-deck
# penthouse): walls following min(cap, half_beam - side) with a cabin-window band, solid end caps
# and a walkable tapered roof slab. No entry door / sea glazing — this is the wedding-cake bulk
# above the Promenade, set well inboard so the boat-deck walkway (lifeboats) stays open outboard.
static func _upper_house(parent: Node3D, z_aft: float, z_fwd: float, cap: float, side: float, y_base: float, y_top: float, wall: Material, glaze_mat: Material, deck: Material, win_y0: float, win_y1: float) -> void:
	var wall_top: float = y_top - 0.25
	var t: float = 0.4
	var n: int = 18
	for s in [-1.0, 1.0]:
		for i in range(n):
			var z0: float = lerpf(z_aft, z_fwd, float(i) / float(n))
			var z1: float = lerpf(z_aft, z_fwd, float(i + 1) / float(n))
			var x0: float = s * _house_half_w(z0, cap, side)
			var x1: float = s * _house_half_w(z1, cap, side)
			_wall_strip(parent, x0, z0, x1, z1, y_base, win_y0, t, wall, true)            # below the windows
			_wall_strip(parent, x0, z0, x1, z1, win_y1, wall_top, t, wall, true)          # above the windows
			_wall_strip(parent, x0, z0, x1, z1, win_y0, win_y1, t * 0.6, glaze_mat, true) # cabin-window band
			_wall_strip(parent, x0, z0, x1, z1, win_y1 - 0.06, win_y1 + 0.06, t + 0.1, wall, false) # head rail
		for i in range(n + 1):
			var mz: float = lerpf(z_aft, z_fwd, float(i) / float(n))
			_box(parent, Vector3(s * _house_half_w(mz, cap, side), (win_y0 + win_y1) * 0.5, mz), Vector3(t + 0.08, win_y1 - win_y0, 0.22), wall, false)
	_box(parent, Vector3(0.0, (y_base + wall_top) * 0.5, z_aft), Vector3(_house_half_w(z_aft, cap, side) * 2.0, wall_top - y_base, t), wall, true)
	_box(parent, Vector3(0.0, (y_base + wall_top) * 0.5, z_fwd), Vector3(_house_half_w(z_fwd, cap, side) * 2.0, wall_top - y_base, t), wall, true)
	_tapered_slab(parent, z_aft - 1.0, z_fwd + 1.0, y_top, 0.3, 0.4, deck, cap, side)


# Navigating bridge: a wheelhouse box at the forward end of the boat deck with a forward
# window row, flanked by two cantilevered wing platforms reaching out to the ship's sides.
static func _build_bridge(parent: Node3D, wl: float, wall: Material, glass: Material, deck: Material) -> void:
	var L: float = HULL_HALF_LEN
	var y_sun: float = wl + DECK_SUN
	var y_top: float = wl + DECK_SPORTS + 1.2
	var bz: float = SS_FWD * L - 7.0
	var hw: float = _house_half_w(bz) - 0.3   # follow the narrowed forward hull instead of overhanging it
	var edge: float = _half_beam(bz)          # the hull side at the bridge — the wings reach out to here
	var glaze := _mat(Color(0.07, 0.09, 0.13), 0.7, 0.0)
	_deckhouse(parent, bz - 5.0, bz + 5.0, hw, y_sun, y_top, wall, glass, deck, false)
	# Wheelhouse windows: a continuous dark strip across the front and down each side. Held
	# proud of the 0.4 m walls (front face was coplanar with the wall front, the sides buried
	# inside it) so the dark glazing doesn't z-fight the white wall.
	var wy: float = y_top - 1.3
	_box(parent, Vector3(0.0, wy, bz + 5.26), Vector3(hw * 2.0 - 1.0, 1.5, 0.16), glaze, false)
	for sx in [-1.0, 1.0]:
		_box(parent, Vector3(sx * (hw + 0.20), wy, bz), Vector3(0.16, 1.5, 9.0), glaze, false)
	# Monkey island / compass platform on the wheelhouse roof, with side rails.
	_box(parent, Vector3(0.0, y_top + 0.55, bz), Vector3(8.0, 0.25, 6.0), deck, true)
	for sx in [-1.0, 1.0]:
		_box(parent, Vector3(sx * 4.0, y_top + 1.05, bz), Vector3(0.1, 0.9, 6.0), wall, true)
	# Bridge wings: walkable platforms cantilevered to the ship's sides, each with a wing cab
	# (the open-bridge control position), a cab window, and a forward dodger screen.
	for sx2 in [-1.0, 1.0]:
		var wctr: float = sx2 * (hw + edge) * 0.5    # platform from the wheelhouse side out to the hull edge
		var ww: float = edge - hw + 1.0
		_box(parent, Vector3(wctr, y_sun, bz), Vector3(ww, 0.3, 5.0), deck, true)
		_box(parent, Vector3(sx2 * (edge - 1.0), y_sun + 1.3, bz), Vector3(2.0, 2.5, 2.6), wall, true)
		_box(parent, Vector3(sx2 * (edge - 1.0), y_sun + 1.9, bz + 1.36), Vector3(2.0, 1.0, 0.14), glaze, false)
		_box(parent, Vector3(wctr, y_sun + 0.55, bz - 2.45), Vector3(ww, 0.9, 0.1), wall, true)


# A straight stair run of solid steps climbing from (z_base, y_base) to (z_top, y_top);
# each step is filled to the deck below so the capsule rounds them into a walkable ramp.
static func _stair_run(parent: Node3D, cx: float, z_base: float, z_top: float, y_base: float, y_top: float, width: float, mat: Material) -> void:
	# Size the step count to the rise so each step is ~0.24 m — low enough that the player
	# capsule walks up it instead of having to jump each one (the 16-step flights gave 0.47 m
	# steps on the 7.5 m companionways).
	var n: int = maxi(int(ceil(absf(y_top - y_base) / 0.24)), 6)
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
	# Heights re-anchored so the forward funnel still tops out ~43 m above the water now that the
	# sports deck sits at 22.08 m (43.5 - 22.08 ≈ 21.4).
	var base_y: float = wl + DECK_SPORTS
	_funnel(root, 40.0, base_y, 21.0, red, black)
	_funnel(root, 0.0, base_y, 20.0, red, black)
	_funnel(root, -40.0, base_y, 19.0, red, black)


static func _funnel(parent: Node3D, cz: float, base_y: float, height: float, red: Material, black: Material) -> void:
	var top_y: float = base_y + height
	var cy: float = base_y + height * 0.5
	var ax: float = 4.5    # half-width athwartships (X) — 9 m (the QM funnels were ~30 ft across)
	var az: float = 6.4    # half-length fore-and-aft (Z) — 12.8 m, elliptical (longer than wide)
	var cap: float = 2.8
	# Red body, its top stopped half-way up inside the black cap. The body's top disc and the cap's
	# top disc both used to sit at top_y (coplanar) and z-fought into a spinning pinwheel on the funnel
	# tops; burying the body top inside the slightly wider cap removes the coincident face.
	var red_h: float = height - cap * 0.5
	_ellipse_cyl(parent, Vector3(0.0, base_y + red_h * 0.5, cz), 1.0, red_h, ax, az, red, 0.92)
	# Black cap, a touch wider (1.04) so it cleanly swallows the red top and reads as the funnel lip.
	_ellipse_cyl(parent, Vector3(0.0, top_y - cap * 0.5, cz), 1.04, cap, ax, az, black, 0.95)
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
	_mast(root, Vector3(0.0, wl + DECK_SPORTS, 50.0), 30.0, buff)
	_mast(root, Vector3(0.0, wl + DECK_SPORTS, -55.0), 26.0, buff)


static func _mast(parent: Node3D, base: Vector3, height: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = 0.7
	cm.top_radius = 0.22
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
	boat_mesh.size = Vector3(3.2, 2.0, 10.0)
	var boat_mat := _mat(Color(0.90, 0.88, 0.80), 0.7, 0.0)
	var davit_mesh := BoxMesh.new()
	davit_mesh.size = Vector3(0.22, 2.6, 0.22)
	var davit_mat := _mat(Color(0.20, 0.21, 0.23), 0.6, 0.4)
	var boats: Array = []
	var davits: Array = []
	for side in [-1.0, 1.0]:
		for k in range(14):
			var z: float = lerpf(SS_AFT * L + 28.0, SS_FWD * L - 28.0, float(k) / 13.0)
			var edge: float = _house_half_w(z)   # ride the tapered boat-deck edge, not a fixed ±15
			boats.append(Transform3D(Basis(), Vector3(side * (edge - 0.4), deck_y + 1.2, z)))
			for dz in [-3.8, 3.8]:
				davits.append(Transform3D(Basis(), Vector3(side * (edge - 1.6), deck_y + 1.2, z + float(dz))))
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
	_tapered_side_rails(root, SS_AFT * L, SS_FWD * L, wl + DECK_SUN, h, rail)
	_tapered_side_rails(root, -78.0, 78.0, wl + DECK_SPORTS, h, rail, 13.0, 3.0)


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


# Port + starboard rails following the tapered boat-deck edge (just outboard of _house_half_w),
# lofted as short segments so they curve inboard toward the ends with the deck.
static func _tapered_side_rails(parent: Node3D, z_aft: float, z_fwd: float, y_deck: float, h: float, mat: Material, cap: float = SS_HALF_W, side: float = SS_SIDE_DECK) -> void:
	var n: int = 22
	for i in range(n):
		var z0: float = lerpf(z_aft, z_fwd, float(i) / float(n))
		var z1: float = lerpf(z_aft, z_fwd, float(i + 1) / float(n))
		var w0: float = _house_half_w(z0, cap, side) + 0.35
		var w1: float = _house_half_w(z1, cap, side) + 0.35
		_rail_segment(parent, -w0, y_deck, z0, -w1, y_deck, z1, h, mat)
		_rail_segment(parent, w0, y_deck, z0, w1, y_deck, z1, h, mat)


# --- Forecastle: foredeck fittings so the bow reads as a real ship, not a bare deck ---

static func _build_forecastle(parent: Node3D, wl: float) -> void:
	var root := Node3D.new()
	root.name = "Forecastle"
	parent.add_child(root)
	var white := _mat(COL_SUPER, 0.7, 0.0)
	var grey := _mat(Color(0.55, 0.56, 0.58), 0.7, 0.2)
	var dark := _mat(Color(0.30, 0.31, 0.34), 0.6, 0.3)
	var buff := _mat(Color(0.80, 0.68, 0.45), 0.5, 0.2)
	var fc: float = SS_FWD * HULL_HALF_LEN   # forecastle runs from here forward to the stem

	# The bow deck narrows fast toward the stem (half-beam ~7 m at the break to ~1 m near the
	# stem), so everything sits well inboard and clear of the starboard companionway (x 4..8).
	# Cowl ventilators.
	for sx2 in [-3.5, 3.5]:
		var vz: float = fc + 4.0
		var vd: float = _sheer_y(vz, wl)
		_ellipse_cyl(root, Vector3(float(sx2), vd + 1.1, vz), 0.5, 2.2, 1.0, 1.0, white)
		_box(root, Vector3(float(sx2), vd + 2.3, vz + 0.4), Vector3(1.0, 0.9, 0.9), white, false)

	# Forward kingpost (cargo mast) with a derrick yard, on the centreline clear of the stair.
	var kz: float = fc + 9.0
	_mast(root, Vector3(0.0, _sheer_y(kz, wl), kz), 17.0, buff)

	# Breakwater: a low chevron wall pointing forward, forward of the companionway.
	var brz: float = fc + 16.0
	var bd: float = _sheer_y(brz, wl)
	_oriented_box(root, Vector3(-2.8, bd + 0.75, brz), Vector3(0.3, 1.5, 4.5), 0.42, white, true)
	_oriented_box(root, Vector3(2.8, bd + 0.75, brz), Vector3(0.3, 1.5, 4.5), -0.42, white, true)

	# Anchor windlass house + two warping drums.
	var wz: float = fc + 19.0
	var wd: float = _sheer_y(wz, wl)
	_box(root, Vector3(0.0, wd + 0.9, wz), Vector3(4.5, 1.8, 3.0), dark, true)
	for sx in [-1.5, 1.5]:
		_ellipse_cyl(root, Vector3(float(sx), wd + 2.15, wz), 0.7, 0.7, 1.0, 1.0, grey)

	# Mooring bollards toward the bow.
	for spec in [[-2.3, fc + 22.0], [2.3, fc + 22.0], [-1.8, fc + 24.0], [1.8, fc + 24.0]]:
		var bz: float = float(spec[1])
		_ellipse_cyl(root, Vector3(float(spec[0]), _sheer_y(bz, wl) + 0.45, bz), 0.32, 0.9, 1.0, 1.0, dark)

	# Jackstaff at the stem.
	var jz: float = fc + 30.0
	_box(root, Vector3(0.0, _sheer_y(jz, wl) + 3.0, jz), Vector3(0.16, 6.0, 0.16), buff, false)


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
		[Vector3(-12.0, boat_y, -82.0), 1.0], [Vector3(12.0, boat_y, -82.0), 1.0],
		[Vector3(-5.5, boat_y, -75.0), -1.0], [Vector3(5.5, boat_y, -75.0), -1.0],
		[Vector3(-12.0, boat_y, -67.0), 1.0], [Vector3(12.0, boat_y, -67.0), 1.0],
		[Vector3(-12.0, boat_y, 65.0), -1.0], [Vector3(12.0, boat_y, 65.0), -1.0],
	]
	for v in vents:
		_cowl_vent(root, v[0], float(v[1]), white, ventred)

	# Aft mooring gear on the open after deck (clear of the aft gates): capstans + bollards.
	var aft: float = SS_AFT * HULL_HALF_LEN
	for spec in [[-3.5, aft - 6.0], [3.5, aft - 6.0]]:
		var cz: float = float(spec[1])
		_ellipse_cyl(root, Vector3(float(spec[0]), _sheer_y(cz, wl) + 0.6, cz), 0.6, 1.2, 1.0, 1.0, dark)
	for spec2 in [[-2.6, aft - 11.0], [2.6, aft - 11.0]]:
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
		# Window face kept below the roofline so its top edge isn't coplanar with the roof.
		_box(root, Vector3(0.0, sports_y + 1.35, float(dz) + 2.56), Vector3(5.0, 0.8, 0.14), glaze, false)
	var boat_y: float = wl + DECK_SUN
	for sz in [-90.0, 86.0]:
		# Coaming seated on the deck (bottom at boat_y), with the glazing penetrating its top.
		_box(root, Vector3(0.0, boat_y + 0.25, float(sz)), Vector3(6.0, 0.5, 4.0), white, true)
		_box(root, Vector3(0.0, boat_y + 0.62, float(sz)), Vector3(5.2, 0.25, 3.2), glaze, false)


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


# Flags: the red ensign on a staff at the stern, a jack on the bow jackstaff, and the
# Cunard houseflag at the foremast head.
static func _build_flags(parent: Node3D, wl: float) -> void:
	var root := Node3D.new()
	root.name = "Flags"
	parent.add_child(root)
	var buff := _mat(Color(0.80, 0.68, 0.45), 0.5, 0.2)
	var red := _mat(Color(0.74, 0.14, 0.12), 0.7, 0.0)
	var blue := _mat(Color(0.12, 0.20, 0.55), 0.7, 0.0)
	# Stern ensign: staff + red ensign with a blue union canton at the hoist.
	var sz: float = -HULL_HALF_LEN + 3.0
	var sy: float = _sheer_y(sz, wl)
	_box(root, Vector3(0.0, sy + 2.1, sz), Vector3(0.14, 4.2, 0.14), buff, false)
	_box(root, Vector3(1.7, sy + 3.5, sz), Vector3(3.0, 1.6, 0.07), red, false)
	_box(root, Vector3(0.95, sy + 3.9, sz - 0.01), Vector3(1.3, 0.8, 0.08), blue, false)
	# Jack on the bow jackstaff (which already stands at z~149).
	var jy: float = _sheer_y(149.0, wl)
	_box(root, Vector3(1.5, jy + 4.8, 149.0), Vector3(2.6, 1.4, 0.07), blue, false)
	# Cunard houseflag at the foremast head (foremast base z=50 on the sports deck).
	_box(root, Vector3(1.5, wl + DECK_SPORTS + 23.5, 50.0), Vector3(2.8, 1.5, 0.07), red, false)


# Recessed stockless bower anchors flush on each bow side (shank + flukes), the way a liner
# carries them in the hawse.
static func _build_anchors(parent: Node3D, wl: float) -> void:
	var root := Node3D.new()
	root.name = "Anchors"
	parent.add_child(root)
	var dark := _mat(Color(0.16, 0.17, 0.20), 0.6, 0.3)
	for side in [-1.0, 1.0]:
		var z: float = SS_FWD * HULL_HALF_LEN + 20.0
		var k: float = _keel_y(z, wl)
		var s: float = _sheer_y(z, wl)
		var b: float = _half_beam(z)
		var frac: float = clampf((5.5 - k) / (s - k), 0.0, 1.0)
		var bw: float = b * (0.72 + 0.28 * frac)
		_box(root, Vector3(side * (bw + 0.05), 5.9, z), Vector3(0.12, 2.6, 1.3), dark, false)
		_box(root, Vector3(side * (bw + 0.08), 4.6, z), Vector3(0.16, 0.7, 2.3), dark, false)


# --- Interior (increment 1: walk inside the superstructure) --------------------------
# The base block is already a sealed, teak-floored volume: the main-deck mesh runs full-beam
# through it at Main level (the floor), and the side walls + boat-deck slab enclose it. So the
# first interior pass just makes it read and behave as a room — warm deckhead lighting and two
# rows of panelled columns. The forward-wall door (see the base-block _deckhouse call) is the
# way in off the forecastle. Later passes lay the Promenade floor at 15.5, a grand staircase,
# and the public rooms.
static func _build_interior(parent: Node3D, wl: float) -> void:
	var root := Node3D.new()
	root.name = "Interior"
	parent.add_child(root)
	var L: float = HULL_HALF_LEN
	var y_main: float = wl + DECK_MAIN
	var y_prom: float = wl + DECK_PROM
	var y_sun: float = wl + DECK_SUN

	# Promenade Deck floor at 15.5 over the entrance/A-deck level, with a stairwell opening just
	# aft of the door for the grand staircase. The A-deck floor is the main-deck mesh below it.
	var hz0: float = 50.0
	var hz1: float = 59.0
	var hx: float = 4.0
	_floor_with_hole(root, PROM_AFT, PROM_FWD, PROM_HALF_W, y_prom, hz0, hz1, hx, 0.3, _mat(Color(0.34, 0.26, 0.18), 0.7, 0.0))

	# Grand staircase up from the entrance (A deck, 12) to the Promenade (15.5), rising aft.
	_stair_run(root, 0.0, 58.0, 50.0, y_main, y_prom, 6.0, _mat(COL_TEAK, 0.7, 0.0))
	# Balustrade around the three closed sides of the stairwell so you don't step into it.
	var railmat := _mat(Color(0.72, 0.60, 0.38), 0.4, 0.1)
	_box(root, Vector3(-hx, y_prom + 0.5, (hz0 + hz1) * 0.5), Vector3(0.12, 1.0, hz1 - hz0), railmat, true)
	_box(root, Vector3(hx, y_prom + 0.5, (hz0 + hz1) * 0.5), Vector3(0.12, 1.0, hz1 - hz0), railmat, true)
	_box(root, Vector3(0.0, y_prom + 0.5, hz1), Vector3(hx * 2.0, 1.0, 0.12), railmat, true)

	# Warm deckhead lamps on the A-deck/entrance level (the Promenade is lit by the globe
	# pendants in _build_promenade_fit), no shadows — cheap fill.
	for ly in [y_main + 2.0]:
		for lz in [-78.0, -54.0, -30.0, -6.0, 18.0, 42.0, 64.0]:
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(0.0, float(ly), float(lz))
			lamp.light_color = Color(1.0, 0.92, 0.76)
			lamp.light_energy = 2.6
			lamp.omni_range = 24.0
			lamp.shadow_enabled = false
			root.add_child(lamp)

	# Two rows of period columns: cream shafts with green rings near the top over burl-wood bases
	# on each deck, like the QM lounge.
	var col_cream := _mat(Color(0.90, 0.88, 0.83), 0.35, 0.0)
	var col_wood := _mat(Color(0.33, 0.19, 0.10), 0.4, 0.1)
	var col_green := _mat(Color(0.15, 0.33, 0.23), 0.5, 0.2)
	for cz in [-66.0, -44.0, -22.0, 0.0, 22.0, 44.0, 62.0]:
		for sx in [-6.5, 6.5]:
			_deco_column(root, wl, sx, cz, col_cream, col_wood, col_green)

	# A teak threshold strip just inside the forward door, so the doorway reads as an entrance.
	_box(root, Vector3(-4.0, _sheer_y(SS_FWD * L - 1.2, wl) + 0.06, SS_FWD * L - 1.2), Vector3(3.4, 0.12, 2.0), _mat(COL_TEAK, 0.7, 0.0), false)

	# Promenade fit-out (white beamed deckhead, pipe runs, globe pendants, wood dado + handrail)
	# and the first public room off it: the First Class Main Lounge, amidships.
	_build_promenade_fit(root, wl)
	_build_lounge(root, wl)


# Promenade Deck fit-out matching the real enclosed promenade: a bright white deckhead with
# transverse deck beams and longitudinal pipe/conduit runs, hanging globe pendant lights, and a
# wood dado + handrail below the windows down each side.
static func _build_promenade_fit(parent: Node3D, wl: float) -> void:
	var root := Node3D.new()
	root.name = "PromenadeFit"
	parent.add_child(root)
	# Clamped to the amidships full-width core so the deckhead/dado/galleries never poke through
	# the tapered side walls toward the ends.
	var z0: float = PROM_AFT
	var z1: float = PROM_FWD
	var zc: float = (z0 + z1) * 0.5
	var zl: float = z1 - z0
	var hw: float = PROM_HALF_W
	var y_prom: float = wl + DECK_PROM
	var y_sill: float = wl + 17.4
	var y_ceil: float = wl + DECK_SUN - 0.45
	var lining := _mat(Color(0.78, 0.74, 0.65), 0.9, 0.0)
	var beam := _mat(Color(0.70, 0.65, 0.55), 0.8, 0.0)
	var cream := _mat(Color(0.64, 0.58, 0.47), 0.6, 0.1)
	var wood := _mat(COL_TEAK, 0.7, 0.0)
	# Warm cream deckhead lining over the Promenade.
	_box(root, Vector3(0.0, y_ceil + 0.08, zc), Vector3(hw * 2.0 - 0.4, 0.12, zl), lining, false)
	# Transverse deck beams every ~4 m, a shade darker than the lining so they read; kept shallow
	# so they don't eat headroom on the real ~2.84 m deck.
	var nb: int = int(zl / 4.0)
	for i in range(nb + 1):
		var bz: float = z0 + zl * float(i) / float(nb)
		_box(root, Vector3(0.0, y_ceil - 0.12, bz), Vector3(hw * 2.0 - 0.4, 0.22, 0.28), beam, false)
	# Longitudinal pipe/conduit runs (near each window line + two inboard), tucked up to the deckhead.
	for px in [-hw + 1.6, -2.2, 2.2, hw - 1.6]:
		_box(root, Vector3(px, y_ceil - 0.28, zc), Vector3(0.14, 0.14, zl), cream, false)
	# Globe pendant lights down the centreline.
	var globemat := StandardMaterial3D.new()
	globemat.albedo_color = Color(1.0, 0.96, 0.84)
	globemat.emission_enabled = true
	globemat.emission = Color(1.0, 0.93, 0.76)
	globemat.emission_energy_multiplier = 0.7
	# Flush deckhead dome lights down each sheltered-promenade gallery. The deck is a real ~2.84 m
	# height, too low to hang globes on stems, so they sit tight up under the deckhead.
	for sgn in [-1.0, 1.0]:
		var gx: float = sgn * 13.75
		for gz in [-64.0, -48.0, -24.0, 0.0, 24.0, 48.0, 58.0]:
			var globe := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.18
			sm.height = 0.26
			globe.mesh = sm
			globe.material_override = globemat
			globe.position = Vector3(gx, y_ceil - 0.06, float(gz))
			root.add_child(globe)
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(gx, y_ceil - 0.4, float(gz))
			lamp.light_color = Color(1.0, 0.93, 0.78)
			lamp.light_energy = 1.6
			lamp.omni_range = 15.0
			lamp.shadow_enabled = false
			root.add_child(lamp)
	# Wood dado + handrail below the windows, down each side.
	for sgn2 in [-1.0, 1.0]:
		var xw: float = sgn2 * (hw - 0.22)
		_box(root, Vector3(xw, (y_prom + y_sill) * 0.5, zc), Vector3(0.18, y_sill - y_prom, zl), wood, false)
		_box(root, Vector3(xw, y_sill + 0.06, zc), Vector3(0.16, 0.12, zl), wood, false)

	# Sheltered-promenade gallery walls at ±10, separating the glazed galleries from the inboard
	# public rooms, with doorways through to the rooms; benches along the windows.
	var white := _mat(COL_SUPER, 0.7, 0.0)
	var bench := _mat(Color(0.30, 0.20, 0.13), 0.7, 0.0)
	var door_zs: Array = [-64.0, -48.0, -24.0, -9.0, 9.0, 30.0, 48.0, 58.0]
	for sgn3 in [-1.0, 1.0]:
		_longitudinal_door_wall(root, sgn3 * 11.0, z0, z1, y_prom, y_ceil + 0.1, 0.3, door_zs, 3.0, 2.4, white)
		for bz in [-60.0, -36.0, -12.0, 12.0, 36.0, 56.0]:
			_box(root, Vector3(sgn3 * (hw - 1.1), y_prom + 0.3, float(bz)), Vector3(0.7, 0.6, 2.4), bench, true)
	# Temporary fill for the inboard areas not yet built into rooms (fore + aft of the lounge).
	for fz in [-66.0, -42.0, 36.0, 56.0]:
		var fill := OmniLight3D.new()
		fill.position = Vector3(0.0, y_prom + 2.4, float(fz))
		fill.light_color = Color(1.0, 0.92, 0.78)
		fill.light_energy = 2.0
		fill.omni_range = 20.0
		fill.shadow_enabled = false
		root.add_child(fill)


# Transverse partition wall at longitudinal z, spanning ±half_w and y0..y1, with a central
# doorway (two jambs + a lintel) at door_x.
static func _transverse_door_wall(parent: Node3D, z: float, half_w: float, y0: float, y1: float, t: float, door_x: float, dw: float, dh: float, mat: Material) -> void:
	var h: float = y1 - y0
	var cy: float = (y0 + y1) * 0.5
	var da: float = door_x - dw * 0.5
	var db: float = door_x + dw * 0.5
	_box(parent, Vector3((-half_w + da) * 0.5, cy, z), Vector3(da + half_w, h, t), mat, true)
	_box(parent, Vector3((db + half_w) * 0.5, cy, z), Vector3(half_w - db, h, t), mat, true)
	var ly: float = y0 + dh
	_box(parent, Vector3(door_x, (ly + y1) * 0.5, z), Vector3(dw, y1 - ly, t), mat, true)


# Longitudinal wall at x, spanning z0..z1 and y0..y1, with doorways (jambs + a lintel) at each z
# in door_zs. Used for the sheltered-promenade gallery walls separating the galleries from the
# inboard public rooms.
static func _longitudinal_door_wall(parent: Node3D, x: float, z0: float, z1: float, y0: float, y1: float, t: float, door_zs: Array, dw: float, dh: float, mat: Material) -> void:
	var h: float = y1 - y0
	var cy: float = (y0 + y1) * 0.5
	var edges: Array = [z0]
	for dz in door_zs:
		edges.append(float(dz) - dw * 0.5)
		edges.append(float(dz) + dw * 0.5)
	edges.append(z1)
	var i: int = 0
	while i + 1 < edges.size():
		var sa: float = float(edges[i])
		var sb: float = float(edges[i + 1])
		if sb > sa + 0.01:
			_box(parent, Vector3(x, cy, (sa + sb) * 0.5), Vector3(t, h, sb - sa), mat, true)
		i += 2
	var ly: float = y0 + dh
	for dz in door_zs:
		_box(parent, Vector3(x, (ly + y1) * 0.5, float(dz)), Vector3(t, y1 - ly, dw), mat, true)


# The First Class Main Lounge: a grand room amidships on the Promenade Deck, walled off the
# galleries fore and aft, with a parquet dance floor, an orchestra dais and back-panel, perimeter
# banquettes, and a pendant light over the floor.
static func _build_lounge(parent: Node3D, wl: float) -> void:
	var root := Node3D.new()
	root.name = "MainLounge"
	parent.add_child(root)
	var y_prom: float = wl + DECK_PROM
	var y_top: float = wl + DECK_SUN - 0.35
	# The lounge is an inboard room: its side walls are the sheltered-promenade gallery walls at
	# ±11 (built in _build_promenade_fit); the fore/aft partitions span that inboard width.
	var room_hw: float = 11.0
	var white := _mat(COL_SUPER, 0.7, 0.0)
	# Partition walls fore (z=+18) and aft (z=-18) with central doorways to the inboard areas.
	_transverse_door_wall(root, 18.0, room_hw, y_prom, y_top, 0.4, 0.0, 3.2, 2.4, white)
	_transverse_door_wall(root, -18.0, room_hw, y_prom, y_top, 0.4, 0.0, 3.2, 2.4, white)
	# Parquet dance floor, centre.
	_box(root, Vector3(0.0, y_prom + 0.06, 0.0), Vector3(12.0, 0.12, 16.0), _mat(Color(0.56, 0.42, 0.25), 0.45, 0.0), false)
	# Orchestra dais at the aft end, raised, with a tall Deco back-panel on the partition.
	_box(root, Vector3(0.0, y_prom + 0.2, -15.5), Vector3(10.0, 0.4, 4.0), _mat(Color(0.30, 0.22, 0.15), 0.6, 0.0), true)
	_box(root, Vector3(0.0, y_prom + 2.3, -17.75), Vector3(8.0, 3.4, 0.16), _mat(Color(0.82, 0.67, 0.36), 0.4, 0.35), false)
	# Perimeter banquettes along the lounge's port and starboard walls.
	var sofa := _mat(Color(0.46, 0.20, 0.22), 0.85, 0.0)
	for sx in [-1.0, 1.0]:
		for sz in [-11.0, -3.0, 5.0, 13.0]:
			_box(root, Vector3(sx * (room_hw - 1.0), y_prom + 0.45, float(sz)), Vector3(1.5, 0.9, 3.2), sofa, true)
	# Art Deco ceiling light fixtures (frosted panels in dark bronze grilles) over the lounge —
	# a big one over the dance floor and two smaller ones forward, like the QM lounge.
	var frosted := StandardMaterial3D.new()
	frosted.albedo_color = Color(0.95, 0.90, 0.78)
	frosted.emission_enabled = true
	frosted.emission = Color(1.0, 0.92, 0.74)
	frosted.emission_energy_multiplier = 1.1
	var frame := _mat(Color(0.22, 0.17, 0.10), 0.4, 0.4)
	var y_fix: float = wl + DECK_SUN - 0.62
	_deco_ceiling_light(root, Vector3(0.0, y_fix, 0.0), 1.7, 0.8, frosted, frame, 2.8)
	for fz in [-12.0, 12.0]:
		_deco_ceiling_light(root, Vector3(0.0, y_fix, float(fz)), 1.1, 0.6, frosted, frame, 2.2)


# A vertical cylinder (column shaft, ring, stem).
static func _cyl(parent: Node3D, center: Vector3, radius: float, height: float, mat: Material, collide: bool) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 16
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


# A period lounge column: a cream cylindrical shaft through both decks, a burl-wood base on each
# deck, and two green rings near the top of the Promenade shaft.
static func _deco_column(parent: Node3D, wl: float, x: float, z: float, cream: Material, wood: Material, green: Material) -> void:
	var y0: float = wl + DECK_MAIN
	var y_mid: float = wl + DECK_PROM
	var y1: float = wl + DECK_SUN
	_cyl(parent, Vector3(x, (y0 + y1) * 0.5, z), 0.42, y1 - y0, cream, true)
	_cyl(parent, Vector3(x, y0 + 0.55, z), 0.46, 1.1, wood, false)
	_cyl(parent, Vector3(x, y_mid + 0.55, z), 0.46, 1.1, wood, false)
	for ry in [y1 - 1.55, y1 - 1.3]:
		_cyl(parent, Vector3(x, float(ry), z), 0.45, 0.06, green, false)


# An Art Deco ceiling light fixture: a frosted glowing panel in a dark grille frame with a few
# cross-bars, plus an omni light below it.
static func _deco_ceiling_light(parent: Node3D, center: Vector3, half_w: float, half_d: float, frosted: Material, frame: Material, energy: float) -> void:
	_box(parent, center, Vector3(half_w * 2.0, 0.1, half_d * 2.0), frosted, false)
	_box(parent, center + Vector3(0.0, 0.03, half_d), Vector3(half_w * 2.0 + 0.2, 0.18, 0.12), frame, false)
	_box(parent, center + Vector3(0.0, 0.03, -half_d), Vector3(half_w * 2.0 + 0.2, 0.18, 0.12), frame, false)
	_box(parent, center + Vector3(half_w, 0.03, 0.0), Vector3(0.12, 0.18, half_d * 2.0), frame, false)
	_box(parent, center + Vector3(-half_w, 0.03, 0.0), Vector3(0.12, 0.18, half_d * 2.0), frame, false)
	for fx in [-half_w * 0.5, 0.0, half_w * 0.5]:
		_box(parent, center + Vector3(float(fx), 0.02, 0.0), Vector3(0.07, 0.14, half_d * 2.0), frame, false)
	var lamp := OmniLight3D.new()
	lamp.position = center + Vector3(0.0, -0.6, 0.0)
	lamp.light_color = Color(1.0, 0.93, 0.78)
	lamp.light_energy = energy
	lamp.omni_range = 18.0
	lamp.shadow_enabled = false
	parent.add_child(lamp)


# A horizontal floor slab (top at `y`) spanning z0..z1 × ±x_half, with a rectangular opening
# hz0..hz1 × ±hx — built as up to four boxes around the hole (for stairwells/light wells).
static func _floor_with_hole(parent: Node3D, z0: float, z1: float, x_half: float, y: float, hz0: float, hz1: float, hx: float, thick: float, mat: Material) -> void:
	var cy: float = y - thick * 0.5
	if hz0 > z0:
		_box(parent, Vector3(0.0, cy, (z0 + hz0) * 0.5), Vector3(x_half * 2.0, thick, hz0 - z0), mat, true)
	if z1 > hz1:
		_box(parent, Vector3(0.0, cy, (hz1 + z1) * 0.5), Vector3(x_half * 2.0, thick, z1 - hz1), mat, true)
	_box(parent, Vector3(-(x_half + hx) * 0.5, cy, (hz0 + hz1) * 0.5), Vector3(x_half - hx, thick, hz1 - hz0), mat, true)
	_box(parent, Vector3((x_half + hx) * 0.5, cy, (hz0 + hz1) * 0.5), Vector3(x_half - hx, thick, hz1 - hz0), mat, true)


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
