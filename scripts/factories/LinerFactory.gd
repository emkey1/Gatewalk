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

	_build_hull(root, wl, wl + 5.04, -28.0, 28.0, 36.0, 82.0)   # carve the upper hull over the Dining Room + the pool (floor at C deck)
	_build_main_deck(root, wl, 15.0, 25.0, 4.0, 67.0, 79.0, 4.0)   # stairwell openings: Dining Room + swimming-pool descents
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
static func _build_hull(parent: Node3D, wl: float, carve_y: float = NAN, carve_z0: float = NAN, carve_z1: float = NAN, carve2_z0: float = NAN, carve2_z1: float = NAN) -> void:
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
		if not is_nan(carve_y) and ((z1 > carve_z0 and z0 < carve_z1) or (not is_nan(carve2_z0) and z1 > carve2_z0 and z0 < carve2_z1)):
			# Carve the UPPER hull hollow over the Dining Room: keep the slice solid only up to
			# carve_y (the room floor) so the player can stand in the room instead of inside solid
			# hull. The lower hull stays solid (nothing falls through to the sea); the room's own
			# floor/walls/ceiling enclose the open volume above.
			cvx.points = PackedVector3Array([Vector3(-b0, carve_y, z0), Vector3(b0, carve_y, z0), Vector3(-b1, carve_y, z1), Vector3(b1, carve_y, z1), bL0, bR0, bL1, bR1])
		else:
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
static func _build_main_deck(parent: Node3D, wl: float, hz0: float = NAN, hz1: float = NAN, hx: float = 0.0, hz0b: float = NAN, hz1b: float = NAN, hxb: float = 0.0) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(COL_TEAK)
	var n: int = HULL_STATIONS
	for i in range(n):
		var z0: float = lerpf(-HULL_HALF_LEN, HULL_HALF_LEN, float(i) / float(n))
		var z1: float = lerpf(-HULL_HALF_LEN, HULL_HALF_LEN, float(i + 1) / float(n))
		# Clip any stairwell opening to its EXACT z bounds within this ~6.5 m station. The opening used
		# to snap to whole stations, so the hole spilled several metres fore/aft of the stair that fills
		# it — you fell through the over-cut deck beside the pool stair. Lay full deck up to the hole,
		# port+starboard strips across it, then full deck again.
		var ha0: float = NAN
		var ha1: float = NAN
		var hxh: float = 0.0
		if not is_nan(hz0) and z1 > hz0 and z0 < hz1:
			ha0 = maxf(z0, hz0)
			ha1 = minf(z1, hz1)
			hxh = hx
		elif not is_nan(hz0b) and z1 > hz0b and z0 < hz1b:
			ha0 = maxf(z0, hz0b)
			ha1 = minf(z1, hz1b)
			hxh = hxb
		if hxh <= 0.0:
			_deck_seg(st, z0, z1, 0.0, wl)
		else:
			if ha0 > z0 + 0.01:
				_deck_seg(st, z0, ha0, 0.0, wl)
			_deck_seg(st, ha0, ha1, hxh, wl)
			if ha1 < z1 - 0.01:
				_deck_seg(st, ha1, z1, 0.0, wl)
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


# One main-deck floor segment za..zb: a full-width quad, or (hxh>0) port+starboard strips leaving the
# centre ±hxh open for a stairwell. Lets _build_main_deck clip stairwell openings to exact z bounds.
static func _deck_seg(st: SurfaceTool, za: float, zb: float, hxh: float, wl: float) -> void:
	var ba: float = _half_beam(za)
	var bb: float = _half_beam(zb)
	var sa: float = _sheer_y(za, wl)
	var sb: float = _sheer_y(zb, wl)
	if hxh > 0.0:
		_quad_flat(st, Vector3(-ba, sa, za), Vector3(-hxh, sa, za), Vector3(-hxh, sb, zb), Vector3(-ba, sb, zb))
		_quad_flat(st, Vector3(hxh, sa, za), Vector3(ba, sa, za), Vector3(bb, sb, zb), Vector3(hxh, sb, zb))
	else:
		_quad_flat(st, Vector3(-ba, sa, za), Vector3(ba, sa, za), Vector3(bb, sb, zb), Vector3(-ba, sb, zb))


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
	# aft door -> the Verandah Grill; a hatch cut in the roof aft-starboard for the sports-deck stair/lift trunk
	_upper_house(root, -78.0, 78.0, 13.0, 3.0, y_sun, y_sports, white, glass, deck, wl + 20.5, wl + 21.6, 1.4, 4.75, 8.25, -58.2, -53.4)
	# Navigating bridge across the forward end of the boat deck, with wing platforms.
	_build_bridge(root, wl, white, glass, deck)

	# Companionways linking the open decks: up the aft well deck to the Boat deck, on up to
	# the Sports deck, and a forward flight to the forecastle. The fore/aft weather decks rise
	# toward the ends (sheer), so each base sits at the local sheer, not the flat mid-ship deck,
	# or the stair hangs below the deck it lands on. Solid steps the capsule rounds into a ramp.
	# Kept well inboard so they land on the now-tapered (narrower) boat-deck ends, not off the edge.
	_stair_run(root, -3.0, SS_AFT * L - 13.0, SS_AFT * L - 1.5, _sheer_y(SS_AFT * L - 13.0, wl), y_sun, 4.0, deck)
	_stair_run(root, 3.0, SS_FWD * L + 13.0, SS_FWD * L + 1.5, _sheer_y(SS_FWD * L + 13.0, wl), y_sun, 4.0, deck)
	# (The old boat-deck->sports-deck companionway at cx=0 was removed — it sat on the centreline INSIDE
	# the sun-deck house, non-functional in the solid house and now barging through the Verandah Grill.)


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


# One quad panel of a (holed) tapered slab: a top + an underside spanning [xLa..xRa] at za and
# [xLb..xRb] at zb, plus optional outboard edge skirts. The hole-side edges pass skirt=false so the
# trunk coaming caps them instead (avoids a coplanar slab-skirt / coaming z-fight at the hatch edge).
static func _slab_panel(st: SurfaceTool, za: float, zb: float, xLa: float, xRa: float, xLb: float, xRb: float, yt: float, yb: float, skirtL: bool, skirtR: bool) -> void:
	_quad_flat(st, Vector3(xLa, yt, za), Vector3(xRa, yt, za), Vector3(xRb, yt, zb), Vector3(xLb, yt, zb))   # top
	_quad_flat(st, Vector3(xLa, yb, za), Vector3(xLb, yb, zb), Vector3(xRb, yb, zb), Vector3(xRa, yb, za))   # underside
	if skirtR:
		_quad_flat(st, Vector3(xRa, yt, za), Vector3(xRa, yb, za), Vector3(xRb, yb, zb), Vector3(xRb, yt, zb))
	if skirtL:
		_quad_flat(st, Vector3(xLa, yt, za), Vector3(xLb, yt, zb), Vector3(xLb, yb, zb), Vector3(xLa, yb, za))


# As _tapered_slab, but with a rectangular hole (hx0..hx1 across, hz0..hz1 fore-and-aft) cut clean
# through it — a deck hatch for the sports-deck stair/lift trunk. The hole's z-bounds are clipped
# EXACTLY within each loft station (split at hz0/hz1, never snapped to the coarse station edges —
# the inc-66 over-cut-and-fall-through lesson); over the hole's z-span the top + underside become a
# port strip (out to hx0) and a starboard strip (from hx1), leaving the rectangle open. The hatch
# coaming (built by _build_sports_access) caps the four cut faces.
static func _tapered_slab_holed(parent: Node3D, z_aft: float, z_fwd: float, y_top: float, thick: float, overhang: float, mat: Material, cap: float, side: float, hx0: float, hx1: float, hz0: float, hz1: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color(0.34, 0.25, 0.15))
	var yb: float = y_top - thick
	var n: int = 24
	for i in range(n):
		var z0: float = lerpf(z_aft, z_fwd, float(i) / float(n))
		var z1: float = lerpf(z_aft, z_fwd, float(i + 1) / float(n))
		var zs: Array = [z0, z1]
		if hz0 > z0 and hz0 < z1:
			zs.append(hz0)
		if hz1 > z0 and hz1 < z1:
			zs.append(hz1)
		zs.sort()
		for k in range(zs.size() - 1):
			var za: float = float(zs[k])
			var zb: float = float(zs[k + 1])
			var wa: float = _house_half_w(za, cap, side) + overhang
			var wb: float = _house_half_w(zb, cap, side) + overhang
			var mid: float = (za + zb) * 0.5
			if mid > hz0 and mid < hz1:
				_slab_panel(st, za, zb, -wa, hx0, -wb, hx0, y_top, yb, true, false)   # port strip
				_slab_panel(st, za, zb, hx1, wa, hx1, wb, y_top, yb, false, true)     # starboard strip
			else:
				_slab_panel(st, za, zb, -wa, wa, -wb, wb, y_top, yb, true, true)      # full width
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
static func _upper_house(parent: Node3D, z_aft: float, z_fwd: float, cap: float, side: float, y_base: float, y_top: float, wall: Material, glaze_mat: Material, deck: Material, win_y0: float, win_y1: float, aft_door_w: float = 0.0, hx0: float = NAN, hx1: float = NAN, hz0: float = NAN, hz1: float = NAN) -> void:
	var wall_top: float = y_top - 0.25
	var t: float = 0.4
	var n: int = 18
	# Sink the wall feet 0.4 m into the boat-deck slab that forms this house's floor: the wall
	# bottoms were exactly coplanar with the slab top (both at y_base), which z-fought into dashed
	# white lines running along the deck inside the Verandah Grill.
	var y_sink: float = y_base - 0.4
	for s in [-1.0, 1.0]:
		for i in range(n):
			var z0: float = lerpf(z_aft, z_fwd, float(i) / float(n))
			var z1: float = lerpf(z_aft, z_fwd, float(i + 1) / float(n))
			var x0: float = s * _house_half_w(z0, cap, side)
			var x1: float = s * _house_half_w(z1, cap, side)
			_wall_strip(parent, x0, z0, x1, z1, y_sink, win_y0, t, wall, true)            # below the windows
			_wall_strip(parent, x0, z0, x1, z1, win_y1, wall_top, t, wall, true)          # above the windows
			_wall_strip(parent, x0, z0, x1, z1, win_y0, win_y1, t * 0.6, glaze_mat, true) # cabin-window band
			_wall_strip(parent, x0, z0, x1, z1, win_y1 - 0.06, win_y1 + 0.06, t + 0.1, wall, false) # head rail
		for i in range(n + 1):
			var mz: float = lerpf(z_aft, z_fwd, float(i) / float(n))
			_box(parent, Vector3(s * _house_half_w(mz, cap, side), (win_y0 + win_y1) * 0.5, mz), Vector3(t + 0.08, win_y1 - win_y0, 0.22), wall, false)
	if aft_door_w > 0.0:
		_transverse_door_wall(parent, z_aft, _house_half_w(z_aft, cap, side), y_base, wall_top, t, 0.0, aft_door_w, 2.1, wall)   # entry door (e.g. into the Verandah Grill)
	else:
		_box(parent, Vector3(0.0, (y_sink + wall_top) * 0.5, z_aft), Vector3(_house_half_w(z_aft, cap, side) * 2.0, wall_top - y_sink, t), wall, true)
	_box(parent, Vector3(0.0, (y_sink + wall_top) * 0.5, z_fwd), Vector3(_house_half_w(z_fwd, cap, side) * 2.0, wall_top - y_sink, t), wall, true)
	# The roof slab is also the sports deck; optionally cut a hatch through it for the stair/lift trunk.
	if is_nan(hx0):
		_tapered_slab(parent, z_aft - 1.0, z_fwd + 1.0, y_top, 0.3, 0.4, deck, cap, side)
	else:
		_tapered_slab_holed(parent, z_aft - 1.0, z_fwd + 1.0, y_top, 0.3, 0.4, deck, cap, side, hx0, hx1, hz0, hz1)


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

	# Cowl ventilators on the OPEN after boat deck, abaft the sun-deck house (z < -78). The earlier
	# rows at z=-75/-67/65 sat on what was then open boat deck but is now enclosed by the sun-house
	# (Verandah Grill) — they were left standing indoors, so they're moved out here to the weather deck.
	var vents: Array = [
		[Vector3(-12.0, boat_y, -84.0), 1.0], [Vector3(12.0, boat_y, -84.0), 1.0],
		[Vector3(-12.0, boat_y, -96.0), 1.0], [Vector3(12.0, boat_y, -96.0), 1.0],
		[Vector3(-6.0, boat_y, -103.0), 1.0], [Vector3(6.0, boat_y, -103.0), 1.0],
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
	# Extend the Promenade floor forward and aft of the core as tapered slabs that follow the
	# deckhouse, so the sheltered promenade runs most of the superstructure length instead of
	# dead-ending amidships (the deckhouse glazing + boat-deck-slab ceiling already span the length).
	var floor_mat := _mat(Color(0.34, 0.26, 0.18), 0.7, 0.0)
	_tapered_slab(root, PROM_FWD, 90.0, y_prom, 0.3, 0.0, floor_mat)
	_tapered_slab(root, -115.0, PROM_AFT, y_prom, 0.3, 0.0, floor_mat)

	# Art Deco lift lobby + switchback grand staircase up from A-deck to the Promenade (replaces the
	# old straight flight + plain balustrade): two flights round a burl spine, lift bank, etched glass.
	_build_lift_lobby(root, wl, hz0, hz1, hx)

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
	_build_promenade_rooms(root, wl)
	_furnish_promenade_ends(root, wl)
	_build_dining_room(root, wl)
	_build_main_hall(root, wl)
	_build_cabins(root, wl)
	_build_pool(root, wl)
	_build_verandah_grill(root, wl)
	_build_sports_access(root, wl)


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
	# Wood dado + handrail below the windows, FLUSH against the glazed side wall. The wall sits at
	# _house_half_w(z) (~16.5 amidships, tapering in toward the ends) — about 1 m outboard of the
	# PROM_HALF_W (15.5) promenade floor edge. A straight dado at PROM_HALF_W therefore stood ~1 m
	# proud of the glass with walkable floor behind it; here the dado/handrail are lofted as short
	# strips following the wall, and a floor-edge strip fills the matching gap from the 15.5 floor
	# edge out to the wall so there's no channel to walk down between the wainscot and the windows.
	var floormat := _mat(Color(0.34, 0.26, 0.18), 0.7, 0.0)
	var nfit: int = 30
	for sgn2 in [-1.0, 1.0]:
		for i in range(nfit):
			var za: float = lerpf(z0, z1, float(i) / float(nfit))
			var zb: float = lerpf(z0, z1, float(i + 1) / float(nfit))
			var wa: float = _house_half_w(za)
			var wb: float = _house_half_w(zb)
			var aw: float = (wa + wb) * 0.5
			# Floor-edge filler from the 15.5 floor edge out to the wall (closes the fall-in gap).
			if aw > hw + 0.02:
				_box(root, Vector3(sgn2 * (hw + aw) * 0.5, y_prom - 0.15, (za + zb) * 0.5), Vector3(aw - hw, 0.3, zb - za + 0.05), floormat, true)
			# Dado panel + handrail cap, just inside the glass.
			_wall_strip(root, sgn2 * (wa - 0.12), za, sgn2 * (wb - 0.12), zb, y_prom, y_sill, 0.18, wood, false)
			_wall_strip(root, sgn2 * (wa - 0.12), za, sgn2 * (wb - 0.12), zb, y_sill, y_sill + 0.12, 0.16, wood, false)

	# Sheltered-promenade gallery walls at ±10, separating the glazed galleries from the inboard
	# public rooms, with doorways through to the rooms; benches along the windows.
	var white := _mat(COL_SUPER, 0.7, 0.0)
	var bench := _mat(Color(0.30, 0.20, 0.13), 0.7, 0.0)
	var door_zs: Array = [55.0, 43.0, 33.0, 23.0, 9.0, -7.0, -29.0, -47.0, -61.0]   # one gallery door per public room (clear of the room furniture)
	for sgn3 in [-1.0, 1.0]:
		_longitudinal_door_wall(root, sgn3 * 11.0, z0, z1, y_prom, y_ceil + 0.1, 0.3, door_zs, 3.0, 2.4, white)
		for bz in [-60.0, -36.0, -12.0, 12.0, 36.0, 56.0]:
			_box(root, Vector3(sgn3 * (_house_half_w(float(bz)) - 0.55), y_prom + 0.3, float(bz)), Vector3(0.7, 0.6, 2.4), bench, true)
	# (The inboard public rooms fore + aft of the lounge are built + lit by _build_promenade_rooms.)


# The First Class Promenade Deck public rooms, inboard of the sheltered-promenade galleries, per
# the 1936 deck plan (forward -> aft): Forward Hall (the grand-staircase landing), Library, Drawing
# Room, Shopping arcade, [Main Lounge], Ballroom, Long Gallery, Smoking Room. Transverse partitions
# with central doorways give a fore-aft enfilade down the centreline (the side galleries also run
# through); end bulkheads close the sequence at the core-floor edges so you can't walk off into the
# unfurnished tapered ends. This builds the shells + lighting; furnishings are added separately.
static func _build_promenade_rooms(parent: Node3D, wl: float) -> void:
	var root := Node3D.new()
	root.name = "PromenadeRooms"
	parent.add_child(root)
	var y_prom: float = wl + DECK_PROM
	var y_ceil: float = wl + DECK_SUN - 0.45
	var rhw: float = 11.0      # inboard room half-width (the galleries lie outboard of this)
	var white := _mat(COL_SUPER, 0.7, 0.0)
	# The core room sequence ends at z=62 (fwd) / -68 (aft): close just the inboard ROOMS there (±11,
	# with a central doorway), so the side galleries flow on into the promenade extensions instead of
	# hitting a full-width wall. The promenade itself is closed much further out by tapered end
	# bulkheads at z=90 / -115, near the deckhouse ends.
	# Wall top buried 0.1 m up into the deckhead lining (y_ceil+0.08), like the gallery walls — so the
	# partition top FACE isn't coplanar with the lining/ceiling plane (and closes the old 0.02 m gap).
	var y_wtop: float = y_ceil + 0.1
	for ez in [62.0, -68.0]:
		_transverse_door_wall(root, float(ez), rhw, y_prom, y_wtop, 0.4, 0.0, 3.0, 2.3, white)
	for ez2 in [90.0, -115.0]:
		_box(root, Vector3(0.0, (y_prom - 0.12 + y_wtop) * 0.5, float(ez2)), Vector3(_house_half_w(float(ez2)) * 2.0, y_wtop - y_prom + 0.12, 0.4), white, true)
	# Warm light in the two promenade extensions.
	for lz in [76.0, -92.0]:
		var elamp := OmniLight3D.new()
		elamp.position = Vector3(0.0, y_ceil - 0.5, float(lz))
		elamp.light_color = Color(1.0, 0.92, 0.78)
		elamp.light_energy = 2.3
		elamp.omni_range = 22.0
		elamp.shadow_enabled = false
		root.add_child(elamp)
	# Internal partitions, each with a central 3 m doorway (the Lounge's own ±18 partitions are
	# built by _build_lounge; the Forward Hall is 48..62, around the grand staircase).
	for pz in [48.0, 38.0, 28.0, -40.0, -54.0]:
		_transverse_door_wall(root, float(pz), rhw, y_prom, y_wtop, 0.4, 0.0, 3.0, 2.3, white)
	# A distinct floor rug + a warm ceiling light per room: [z0, z1, rug colour, light energy].
	var rooms: Array = [
		[38.0, 48.0, Color(0.42, 0.31, 0.22), 2.4],    # Library
		[28.0, 38.0, Color(0.40, 0.26, 0.29), 2.3],    # Drawing Room
		[18.0, 28.0, Color(0.58, 0.55, 0.50), 2.5],    # Shopping arcade (brighter)
		[-40.0, -18.0, Color(0.47, 0.34, 0.20), 2.7],  # Ballroom
		[-54.0, -40.0, Color(0.30, 0.27, 0.34), 2.2],  # Long Gallery
		[-68.0, -54.0, Color(0.27, 0.16, 0.13), 1.9],  # Smoking Room (dark, warm, dim)
	]
	for r in rooms:
		var z0: float = float(r[0])
		var z1: float = float(r[1])
		var zc: float = (z0 + z1) * 0.5
		_box(root, Vector3(0.0, y_prom + 0.04, zc), Vector3(rhw * 2.0 - 2.0, 0.08, z1 - z0 - 2.0), _mat(r[2], 0.7, 0.0), false)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(0.0, y_ceil - 0.5, zc)
		lamp.light_color = Color(1.0, 0.92, 0.78)
		lamp.light_energy = float(r[3])
		lamp.omni_range = 17.0
		lamp.shadow_enabled = false
		root.add_child(lamp)
	# Forward Hall (48..62): the grand staircase rises into it, so it just gets a light.
	var hall := OmniLight3D.new()
	hall.position = Vector3(0.0, y_ceil - 0.5, 55.0)
	hall.light_color = Color(1.0, 0.93, 0.80)
	hall.light_energy = 2.5
	hall.omni_range = 16.0
	hall.shadow_enabled = false
	root.add_child(hall)
	_furnish_promenade_rooms(root, wl)


# Signature furnishings for each Promenade public room (blocky, low-poly, kept clear of the
# centreline doorways). Reads the rooms by character: shelves + tables in the Library, sofas in
# the Drawing Room, glass-topped counters in the Shops, a parquet floor + bandstand in the
# Ballroom, settees + framed panels in the Long Gallery, and the showpiece First Class Smoking
# Room — club chairs round low tables, a bar, dark wainscot, and a fireplace with a glowing hearth.
static func _furnish_promenade_rooms(parent: Node3D, wl: float) -> void:
	var yp: float = wl + DECK_PROM
	var wood := _mat(Color(0.32, 0.20, 0.11), 0.6, 0.0)
	var darkwood := _mat(Color(0.20, 0.12, 0.07), 0.5, 0.0)
	var leather := _mat(Color(0.44, 0.17, 0.15), 0.85, 0.0)
	var green := _mat(Color(0.20, 0.32, 0.23), 0.85, 0.0)
	var brass := _mat(Color(0.66, 0.52, 0.24), 0.4, 0.5)
	var books := _mat(Color(0.46, 0.28, 0.22), 0.85, 0.0)
	var glasslt := _mat(Color(0.62, 0.76, 0.80), 0.12, 0.2)
	var parquet := _mat(Color(0.62, 0.46, 0.28), 0.4, 0.0)
	var ember := StandardMaterial3D.new()
	ember.albedo_color = Color(1.0, 0.5, 0.15)
	ember.emission_enabled = true
	ember.emission = Color(1.0, 0.45, 0.12)
	ember.emission_energy_multiplier = 1.8

	# Wall furniture is placed in flanking PAIRS so it never crosses the centre gallery doorway in
	# each side wall (the gallery door sits at each room's mid-length); centre-of-room pieces sit at
	# x~0, clear of both the gallery doors (x=±11) and the centreline partition doors.

	# Library (38..48, gallery door z=43): bookshelves flanking the door + a central reading table.
	for sx in [-1.0, 1.0]:
		for sz in [40.0, 46.0]:
			_box(parent, Vector3(sx * 10.3, yp + 1.3, float(sz)), Vector3(0.7, 2.6, 2.6), darkwood, true)
			_box(parent, Vector3(sx * 9.9, yp + 1.3, float(sz)), Vector3(0.1, 2.3, 2.3), books, false)
	_box(parent, Vector3(0.0, yp + 0.74, 43.0), Vector3(2.4, 0.16, 3.0), wood, true)
	_box(parent, Vector3(0.0, yp + 0.36, 43.0), Vector3(2.0, 0.72, 2.6), wood, false)
	for cz in [41.3, 44.7]:
		for sx2 in [-1.0, 1.0]:
			_box(parent, Vector3(sx2 * 2.1, yp + 0.42, float(cz)), Vector3(0.7, 0.85, 0.7), leather, true)

	# Drawing Room (28..38, door z=33): green sofas flanking the door + a writing desk.
	for sx in [-1.0, 1.0]:
		for sz in [30.0, 36.0]:
			_box(parent, Vector3(sx * 9.3, yp + 0.42, float(sz)), Vector3(1.4, 0.85, 2.4), green, true)
	_box(parent, Vector3(0.0, yp + 0.74, 33.0), Vector3(2.2, 0.16, 1.0), wood, true)
	_box(parent, Vector3(0.0, yp + 0.37, 33.0), Vector3(2.0, 0.72, 0.8), wood, false)

	# Shopping arcade (18..28, door z=23): glass-topped counters flanking the door + a centre kiosk.
	for sx in [-1.0, 1.0]:
		for sz in [20.0, 26.0]:
			_box(parent, Vector3(sx * 9.4, yp + 0.5, float(sz)), Vector3(1.2, 1.0, 2.6), wood, true)
			_box(parent, Vector3(sx * 9.4, yp + 1.06, float(sz)), Vector3(1.34, 0.1, 2.6), glasslt, false)
	_box(parent, Vector3(0.0, yp + 1.0, 23.0), Vector3(2.2, 2.0, 2.2), wood, true)

	# Ballroom (-40..-18, door z=-29): a raised parquet dance floor + perimeter tables. The dance floor
	# is set clearly ABOVE the room rug (they used to share a plane and z-fought into a flickering
	# floor). The old bandstand + gilded back panel were removed — they sat across the aft doorway and
	# blocked the passage to the Long Gallery; the orchestra dais lives in the Main Lounge instead.
	_box(parent, Vector3(0.0, yp + 0.13, -29.0), Vector3(9.0, 0.06, 16.0), parquet, false)
	for sx in [-1.0, 1.0]:
		for tz in [-22.0, -36.0]:
			_box(parent, Vector3(sx * 8.6, yp + 0.5, float(tz)), Vector3(1.1, 0.75, 1.1), green, true)

	# Long Gallery (-54..-40, door z=-47): central back-to-back settees + framed panels flanking the door.
	for gz in [-44.0, -50.0]:
		_box(parent, Vector3(0.0, yp + 0.4, float(gz)), Vector3(3.2, 0.75, 1.4), leather, true)
		for sx in [-1.0, 1.0]:
			_box(parent, Vector3(sx * 10.75, yp + 1.6, float(gz)), Vector3(0.08, 1.4, 1.8), brass, false)

	# Smoking Room (-68..-54, door z=-61): wainscot flanking the door, club-chair groups to port, a
	# bar aft on the starboard wall, and a fireplace with a glowing hearth on the solid aft bulkhead.
	for sx in [-1.0, 1.0]:
		for wz in [-65.0, -57.0]:
			_box(parent, Vector3(sx * 10.85, yp + 0.7, float(wz)), Vector3(0.1, 1.4, 4.5), darkwood, false)
	_box(parent, Vector3(0.0, yp + 1.1, -67.7), Vector3(3.6, 2.2, 0.5), darkwood, true)
	_box(parent, Vector3(0.0, yp + 0.42, -67.45), Vector3(1.6, 0.6, 0.25), ember, false)
	_box(parent, Vector3(0.0, yp + 1.95, -67.6), Vector3(4.0, 0.22, 0.7), wood, true)
	_box(parent, Vector3(0.0, yp + 2.7, -67.72), Vector3(2.0, 1.0, 0.08), brass, false)
	for grp in [-58.5, -64.0]:
		_box(parent, Vector3(-3.0, yp + 0.4, float(grp)), Vector3(1.3, 0.5, 1.3), wood, true)
		for off in [[-2.0, 0.0], [2.0, 0.0], [0.0, -1.7], [0.0, 1.7]]:
			_box(parent, Vector3(-3.0 + float(off[0]), yp + 0.42, float(grp) + float(off[1])), Vector3(0.9, 0.85, 0.9), leather, true)
	_box(parent, Vector3(9.3, yp + 0.6, -65.0), Vector3(1.2, 1.2, 4.0), darkwood, true)
	_box(parent, Vector3(9.3, yp + 1.26, -65.0), Vector3(1.4, 0.1, 4.0), wood, false)


# Furnish the two promenade extensions: the forward one as the Observation Lounge & Cocktail Bar (a
# bar across the forward end + lounge groups), the aft one as an open promenade lounge (settees round
# low tables). Kept clear of the z=62/-68 room doors and the z=90/-115 end bulkheads.
static func _furnish_promenade_ends(parent: Node3D, wl: float) -> void:
	var root := Node3D.new()
	root.name = "PromenadeEnds"
	parent.add_child(root)
	var yp: float = wl + DECK_PROM
	var wood := _mat(Color(0.32, 0.20, 0.11), 0.6, 0.0)
	var darkwood := _mat(Color(0.20, 0.12, 0.07), 0.5, 0.0)
	var leather := _mat(Color(0.44, 0.17, 0.15), 0.85, 0.0)
	var green := _mat(Color(0.20, 0.32, 0.23), 0.85, 0.0)
	var brass := _mat(Color(0.66, 0.52, 0.24), 0.4, 0.5)
	var rug := _mat(Color(0.34, 0.27, 0.33), 0.7, 0.0)

	# Observation Lounge & Cocktail Bar (forward extension, 62..90): a bar across the forward end
	# facing aft with a back-bar shelf, bar stools, and two tub-chair lounge groups.
	_box(root, Vector3(0.0, yp + 0.04, 76.0), Vector3(16.0, 0.08, 22.0), rug, false)
	_box(root, Vector3(0.0, yp + 0.6, 86.0), Vector3(11.0, 1.2, 1.4), darkwood, true)
	_box(root, Vector3(0.0, yp + 1.26, 86.0), Vector3(11.4, 0.1, 1.6), wood, false)
	_box(root, Vector3(0.0, yp + 1.2, 88.6), Vector3(9.0, 2.0, 0.4), darkwood, true)
	_box(root, Vector3(0.0, yp + 1.35, 88.7), Vector3(7.6, 1.2, 0.16), brass, false)
	for bx in [-4.0, -2.0, 0.0, 2.0, 4.0]:
		_cyl(root, Vector3(float(bx), yp + 0.45, 84.0), 0.32, 0.9, leather, true)
	for g in [[-6.0, 70.0], [6.0, 70.0]]:
		_box(root, Vector3(float(g[0]), yp + 0.4, float(g[1])), Vector3(1.2, 0.5, 1.2), wood, true)
		for off in [[-1.5, 0.0], [1.5, 0.0], [0.0, -1.5], [0.0, 1.5]]:
			_box(root, Vector3(float(g[0]) + float(off[0]), yp + 0.42, float(g[1]) + float(off[1])), Vector3(0.85, 0.8, 0.85), green, true)
	var bl := OmniLight3D.new()
	bl.position = Vector3(0.0, yp + 2.3, 84.0)
	bl.light_color = Color(1.0, 0.9, 0.74)
	bl.light_energy = 2.4
	bl.omni_range = 20.0
	bl.shadow_enabled = false
	root.add_child(bl)

	# Aft promenade lounge (aft extension, -115..-68): settees facing across low tables.
	_box(root, Vector3(0.0, yp + 0.04, -90.0), Vector3(18.0, 0.08, 30.0), rug, false)
	for g2 in [[-7.0, -78.0], [7.0, -78.0], [-7.0, -102.0], [7.0, -102.0]]:
		_box(root, Vector3(float(g2[0]), yp + 0.4, float(g2[1])), Vector3(1.2, 0.5, 1.2), wood, true)
		for off2 in [-1.6, 1.6]:
			_box(root, Vector3(float(g2[0]), yp + 0.42, float(g2[1]) + float(off2)), Vector3(1.8, 0.8, 0.85), leather, true)


# The First Class Dining Saloon: a grand room three decks deep in the hull (C-deck floor up to just
# under the A deck), reached by a grand staircase that drops through the stairwell opening cut in the
# A-deck above. No windows (it's inboard, deep in the hull) — lit by a luminous ceiling + a lamp grid.
# The hull collision is carved hollow above the floor (see _build_hull) so the player can stand here.
static func _build_dining_room(parent: Node3D, wl: float) -> void:
	var root := Node3D.new()
	root.name = "DiningRoom"
	parent.add_child(root)
	var fy: float = wl + 5.04           # C-deck floor (world ~3.34)
	var ay: float = wl + DECK_MAIN      # A-deck above (world ~11.86) — the stair head
	var cy: float = wl + 12.7           # ceiling (world ~11.0), ~3 decks above the floor
	var hw: float = 15.0
	var z0: float = -26.0
	var z1: float = 26.0
	var cream := _mat(Color(0.84, 0.80, 0.72), 0.6, 0.0)
	var floormat := _mat(Color(0.42, 0.31, 0.20), 0.6, 0.0)
	var rail := _mat(Color(0.72, 0.60, 0.38), 0.4, 0.1)
	# Floor (sits on the carved-solid lower hull).
	_box(root, Vector3(0.0, fy - 0.15, (z0 + z1) * 0.5), Vector3(hw * 2.0, 0.3, z1 - z0), floormat, true)
	# Luminous ceiling with the stairwell opening (z 18..26, ±4) at the forward end.
	var lum := StandardMaterial3D.new()
	lum.albedo_color = Color(0.95, 0.92, 0.82)
	lum.emission_enabled = true
	lum.emission = Color(1.0, 0.95, 0.82)
	lum.emission_energy_multiplier = 0.32
	_floor_with_hole(root, z0, z1, hw, cy, 18.0, 26.0, 4.0, 0.2, lum)
	# Side + fore/aft walls, floor to ceiling.
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(sx * hw, (fy + cy) * 0.5, (z0 + z1) * 0.5), Vector3(0.4, cy - fy, z1 - z0), cream, true)
	for ez in [z0, z1]:
		_box(root, Vector3(0.0, (fy + cy) * 0.5, float(ez)), Vector3(hw * 2.0, cy - fy, 0.4), cream, true)
	# Tall columns down the room.
	for cz in [-19.0, -9.0, 1.0, 11.0]:
		for sx2 in [-9.0, 9.0]:
			_cyl(root, Vector3(sx2, (fy + cy) * 0.5, float(cz)), 0.5, cy - fy, cream, true)
	# Grand staircase down from the A-deck (ay) to the floor (fy) at the forward end.
	_stair_run(root, 0.0, 14.0, 26.0, fy, ay, 6.0, floormat)
	# Balustrade round the stairwell well at the A-deck level (open at the head, z=26, where you step on).
	for sx3 in [-1.0, 1.0]:
		_box(root, Vector3(sx3 * 4.0, ay + 0.5, 20.0), Vector3(0.12, 1.0, 12.0), rail, true)
	_box(root, Vector3(0.0, ay + 0.5, 14.0), Vector3(8.0, 1.0, 0.12), rail, true)
	# Lighting (deep in the hull, no daylight).
	for lz in [-21.0, -13.0, -5.0, 3.0]:
		for lx in [-10.0, 0.0, 10.0]:
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(float(lx), cy - 1.5, float(lz))
			lamp.light_color = Color(1.0, 0.93, 0.80)
			lamp.light_energy = 1.7
			lamp.omni_range = 15.0
			lamp.shadow_enabled = false
			root.add_child(lamp)
	_furnish_dining_room(root, wl)


# The First Class indoor swimming pool: a tall tiled room deep in the hull (the hull is carved hollow
# over it, see _build_hull), reached by a grand staircase down from the A-deck. A raised tiled pool
# deck surrounds a recessed, water-filled basin amidships, with columns and a luminous ceiling.
static func _build_pool(parent: Node3D, wl: float) -> void:
	var root := Node3D.new()
	root.name = "SwimmingPool"
	parent.add_child(root)
	var deck_y: float = wl + 6.5          # raised pool deck (world ~4.8)
	var basin_y: float = wl + 5.04        # basin floor = carved hull top (world ~3.34)
	var water_y: float = wl + 6.2         # water surface
	var ay: float = wl + DECK_MAIN        # A-deck (stair head)
	var cy: float = wl + 12.0             # ceiling (world ~10.3)
	var z0: float = 38.0
	var z1: float = 80.0
	var hw: float = 14.0
	var bz0: float = 42.0
	var bz1: float = 62.0
	var bhw: float = 6.5
	var tile := _mat(Color(0.62, 0.40, 0.28), 0.4, 0.1)    # terracotta tile (the QM pool's colour)
	var cream := _mat(Color(0.84, 0.80, 0.72), 0.6, 0.0)
	var rail := _mat(Color(0.72, 0.60, 0.38), 0.4, 0.1)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.20, 0.55, 0.62, 0.55)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.05
	water.metallic = 0.2
	# Raised pool deck with the basin opening.
	_floor_with_hole(root, z0, z1, hw, deck_y, bz0, bz1, bhw, 0.3, tile)
	# Basin: side + end walls (deck down to the basin floor), a tiled bottom, and the water surface.
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(sx * bhw, (basin_y + deck_y) * 0.5, (bz0 + bz1) * 0.5), Vector3(0.2, deck_y - basin_y, bz1 - bz0), tile, true)
	for ez in [bz0, bz1]:
		_box(root, Vector3(0.0, (basin_y + deck_y) * 0.5, float(ez)), Vector3(bhw * 2.0, deck_y - basin_y, 0.2), tile, true)
	_box(root, Vector3(0.0, basin_y - 0.1, (bz0 + bz1) * 0.5), Vector3(bhw * 2.0, 0.2, bz1 - bz0), tile, true)
	_box(root, Vector3(0.0, water_y, (bz0 + bz1) * 0.5), Vector3(bhw * 2.0 - 0.3, 0.08, bz1 - bz0 - 0.3), water, false)
	# Room side + fore/aft walls (deck to ceiling) + a luminous ceiling with the stairwell opening.
	for sx2 in [-1.0, 1.0]:
		_box(root, Vector3(sx2 * hw, (deck_y + cy) * 0.5, (z0 + z1) * 0.5), Vector3(0.4, cy - deck_y, z1 - z0), cream, true)
	for ez2 in [z0, z1]:
		_box(root, Vector3(0.0, (deck_y + cy) * 0.5, float(ez2)), Vector3(hw * 2.0, cy - deck_y, 0.4), cream, true)
	var lum := StandardMaterial3D.new()
	lum.albedo_color = Color(0.95, 0.92, 0.82)
	lum.emission_enabled = true
	lum.emission = Color(1.0, 0.95, 0.82)
	lum.emission_energy_multiplier = 0.3
	_floor_with_hole(root, z0, z1, hw, cy, 70.0, 80.0, 4.0, 0.2, lum)
	# Columns down each side of the pool.
	for cz in [44.0, 54.0, 64.0]:
		for sx3 in [-10.0, 10.0]:
			_cyl(root, Vector3(sx3, (deck_y + cy) * 0.5, float(cz)), 0.5, cy - deck_y, cream, true)
	# Grand staircase down from the A-deck to the pool deck (forward end). _stair_run fills each tread
	# solid to the floor, so its flanks are tall solid faces — left bare they read as a stray brown
	# wall in the open room. Box the stair into a cream-walled stairwell (inner faces on the x=±4
	# deck-opening edges) so those flanks become the well sides, and carry the walls 1 m above the
	# A-deck floor as the opening's side parapets.
	# Run the top tread right out to the A-deck opening's forward edge (z=79) so you step straight off
	# the deck onto it — and so, seen from above, the flight reads as descending steps rather than a
	# tall solid riser standing back from the hole.
	# Stair fills the x=±4 opening almost edge-to-edge (3.98) so there's no fall-through gap beside it;
	# the cream well walls (inner faces on the x=±4 opening edges) cover the last 0.02 m and the sides.
	_stair_run(root, 0.0, 66.0, 79.0, deck_y, ay, 7.96, tile)
	for sx4 in [-1.0, 1.0]:
		_box(root, Vector3(sx4 * 4.2, (deck_y + ay + 1.0) * 0.5, 72.5), Vector3(0.4, (ay + 1.0) - deck_y, 14.0), cream, true)
	# Parapet closing the aft edge of the deck opening (z=67) so you can't walk off A-deck into the
	# well from astern; you descend from the forward edge where the top tread meets the deck. Rail cap.
	_box(root, Vector3(0.0, ay + 0.5, 67.0), Vector3(8.4, 1.0, 0.4), cream, true)
	_box(root, Vector3(0.0, ay + 1.05, 67.0), Vector3(8.8, 0.12, 0.5), rail, false)
	# Lighting (deep in the hull).
	for lz in [46.0, 56.0, 66.0]:
		for lx in [-8.0, 0.0, 8.0]:
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(float(lx), cy - 1.2, float(lz))
			lamp.light_color = Color(1.0, 0.94, 0.82)
			lamp.light_energy = 1.8
			lamp.omni_range = 14.0
			lamp.shadow_enabled = false
			root.add_child(lamp)


# The Verandah Grill: the QM's stylish à-la-carte restaurant + nightclub in the aft end of the sun-
# deck house, entered off the after boat deck through the sun-house's aft door. A parquet dance floor
# + a bandstand with a gilded back panel, à-la-carte tables down each side by the windows, closed off
# forward by a partition. The floor, ceiling and side windows are the sun-house's; this adds the fit-out.
static func _build_verandah_grill(parent: Node3D, wl: float) -> void:
	var root := Node3D.new()
	root.name = "VerandahGrill"
	parent.add_child(root)
	var fy: float = wl + DECK_SUN
	var cy: float = wl + DECK_SPORTS - 0.35
	var hw: float = 13.0
	var white := _mat(COL_SUPER, 0.7, 0.0)
	var wood := _mat(Color(0.34, 0.22, 0.12), 0.5, 0.0)
	var cloth := _mat(Color(0.90, 0.88, 0.83), 0.7, 0.0)
	var chair := _mat(Color(0.40, 0.26, 0.16), 0.6, 0.0)
	var parquet := _mat(Color(0.62, 0.46, 0.28), 0.4, 0.0)
	# Forward partition closing the grill off from the rest of the sun-house.
	_box(root, Vector3(0.0, (fy + cy) * 0.5, -52.0), Vector3(hw * 2.0, cy - fy, 0.3), white, true)
	# Parquet dance floor + a bandstand with a gilded back panel against the partition.
	_box(root, Vector3(0.0, fy + 0.05, -63.0), Vector3(8.0, 0.06, 9.0), parquet, false)
	_box(root, Vector3(0.0, fy + 0.3, -55.0), Vector3(6.0, 0.5, 2.2), wood, true)
	_box(root, Vector3(0.0, fy + 1.9, -52.25), Vector3(7.0, 3.0, 0.15), _mat(Color(0.72, 0.56, 0.30), 0.4, 0.35), false)
	# À-la-carte tables down each side by the windows (clear of the dance floor + the aft entry door).
	for sx in [-1.0, 1.0]:
		for tz in [-60.0, -68.0, -74.0]:
			_dining_table(root, Vector3(sx * 8.5, fy, float(tz)), cloth, chair)
	# Lighting.
	for lz in [-58.0, -68.0, -75.0]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(0.0, cy - 0.5, float(lz))
		lamp.light_color = Color(1.0, 0.92, 0.80)
		lamp.light_energy = 2.0
		lamp.omni_range = 16.0
		lamp.shadow_enabled = false
		root.add_child(lamp)


# Sports-deck access: an Art Deco stair-and-lift trunk in the forward-starboard corner of the
# Verandah Grill, climbing one deck and emerging through a hatch cut in the sun-house roof onto the
# open sports deck (the topmost deck, with no stair up since the boat-deck companionway was removed
# in inc 63). A single companion stair within burl stringer walls that carry up through the hatch as
# a coaming topped with an etched-glass balustrade + chrome rail; a decorative Deco lift faces the
# stair off the starboard wall. Reuses the lift-lobby vocabulary (burl, brushed steel, chrome,
# etched glass, checkerboard marble). The hatch in the roof is cut by _upper_house/_tapered_slab_holed
# with the SAME hx0/hx1/hz0/hz1 used here, so the opening and the trunk line up exactly.
static func _build_sports_access(parent: Node3D, wl: float) -> void:
	var root := Node3D.new()
	root.name = "SportsAccess"
	parent.add_child(root)
	var fy: float = wl + DECK_SUN          # Verandah Grill floor / trunk foot
	var yp: float = wl + DECK_SPORTS        # sports deck (sun-house roof top)
	var ru: float = yp - 0.3                # roof underside (the grill ceiling)
	var burl := _mat(Color(0.60, 0.42, 0.19), 0.35, 0.1)
	var dado := _mat(Color(0.28, 0.16, 0.09), 0.5, 0.0)
	var steel := _mat(Color(0.62, 0.64, 0.66), 0.35, 0.85)
	var chrome := _mat(Color(0.82, 0.84, 0.86), 0.18, 0.95)
	var tread := _mat(COL_TEAK, 0.7, 0.0)
	var glass := _etched_glass_mat()
	var cx: float = 6.5                     # trunk centreline (starboard, clear of the dance floor + bandstand)
	var z_fwd: float = -53.0                # stair foot, against the grill's forward partition
	var z_aft: float = -58.0                # stair top, emerging onto the sports deck
	var hz0: float = -58.2                  # hatch aft edge (the open step-off side)
	var hz1: float = -53.4                  # hatch forward edge (closed)
	var hx0: float = 4.75                   # hatch inboard edge
	var hx1: float = 8.25                   # hatch outboard edge
	var zc: float = (hz0 + hz1) * 0.5

	# A checkerboard marble threshold mat at the foot of the flight (clear of the partition at z=-52).
	_box(root, Vector3(cx, fy + 0.02, -52.6), Vector3(3.6, 0.04, 0.7), _checker_mat(3.6, 0.7, 0.5), false)
	# The single Art Deco companion stair up to the sports deck (solid steps the capsule rounds).
	_stair_run(root, cx, z_fwd, z_aft, fy, yp, 3.0, tread)
	# Burl stringer walls hiding the solid stair flanks, rising to deck level within the hatch z-span;
	# a short forward flank covers the bottom step ahead of the hatch (under the solid roof there).
	for sx in [-1.0, 1.0]:
		var xw: float = cx + sx * 1.6
		_box(root, Vector3(xw, (fy + yp) * 0.5, zc), Vector3(0.3, yp - fy, hz1 - hz0), burl, true)
		_box(root, Vector3(xw, fy + 0.55, zc), Vector3(0.34, 1.1, hz1 - hz0), dado, false)
		_box(root, Vector3(xw, (fy + ru) * 0.5, -53.15), Vector3(0.3, ru - fy, 0.6), burl, true)
	# Forward hatch fascia (caps the slab's forward cut face below the balustrade — the closed side).
	_box(root, Vector3(cx, (ru + yp) * 0.5, hz1 - 0.07), Vector3(hx1 - hx0, yp - ru, 0.16), burl, true)
	# Aft cut-edge fascia (the open step-off side) — flush teak board, just capping the 0.3 m slab edge.
	_box(root, Vector3(cx, (ru + yp) * 0.5, hz0 + 0.08), Vector3(hx1 - hx0, yp - ru, 0.12), tread, false)
	# Etched-glass balustrade + chrome handrail ringing the hatch on the sports deck (forward + both
	# outboard sides; the aft side is the open step-off onto the open deck).
	var gy: float = yp + 0.5
	var rails: Array = [
		[cx, hz1 - 0.07, hx1 - hx0, 0.12],          # forward
		[cx - 1.6, zc, 0.12, hz1 - hz0],            # port stringer top
		[cx + 1.6, zc, 0.12, hz1 - hz0],            # starboard stringer top
	]
	for r in rails:
		_box(root, Vector3(float(r[0]), gy, float(r[1])), Vector3(float(r[2]), 1.0, float(r[3])), glass, true)
		_box(root, Vector3(float(r[0]), gy + 0.55, float(r[1])), Vector3(float(r[2]) + 0.06, 0.08, float(r[3]) + 0.06), chrome, false)

	# A decorative Art Deco lift facing the stair off the grill's starboard wall (brushed-steel doors
	# in a burl surround), with burl pilasters + lintel framing it on the wall.
	_elevator(root, Vector3(12.4, fy + 1.2, -54.0), -1.0, burl, steel, chrome)
	for ez in [-55.7, -52.3]:
		_box(root, Vector3(12.7, fy + 1.4, float(ez)), Vector3(0.7, 2.8, 0.3), burl, true)
	_box(root, Vector3(12.7, fy + 2.9, -54.0), Vector3(0.7, 0.3, 3.7), burl, true)

	# Lighting: a stepped Deco ceiling fixture over the stair foot + a warm omni up in the open hatch.
	_deco_ceiling_light(root, Vector3(cx, ru - 0.25, -52.6), 1.2, 0.5, _mat(Color(0.95, 0.92, 0.82), 0.5, 0.0), chrome, 1.4)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(cx, yp + 0.4, hz0 + 1.4)
	lamp.light_color = Color(1.0, 0.95, 0.85)
	lamp.light_energy = 1.2
	lamp.omni_range = 11.0
	lamp.shadow_enabled = false
	root.add_child(lamp)


# Furnish the Dining Saloon: rows of white-clothed tables + chairs, a long captain's table down the
# centre aft, and the saloon's famous decorative Atlantic map in a gilt frame on the aft bulkhead.
static func _furnish_dining_room(parent: Node3D, wl: float) -> void:
	var fy: float = wl + 5.04
	var cloth := _mat(Color(0.90, 0.88, 0.83), 0.7, 0.0)
	var chair := _mat(Color(0.40, 0.26, 0.16), 0.6, 0.0)
	# Tables in a grid, clear of the columns (x=±9), the central aisle, and the stair (z>14).
	for tx in [-12.0, -5.0, 5.0, 12.0]:
		for tz in [-22.0, -15.0, -8.0, -1.0, 6.0]:
			_dining_table(parent, Vector3(float(tx), fy, float(tz)), cloth, chair)
	# Captain's table down the centre aft.
	_box(parent, Vector3(0.0, fy + 0.4, -21.0), Vector3(2.0, 0.8, 4.6), cloth, true)
	_box(parent, Vector3(0.0, fy + 0.81, -21.0), Vector3(2.4, 0.06, 5.0), cloth, false)
	for cz in [-23.4, -21.0, -18.6]:
		for sx in [-1.6, 1.6]:
			_box(parent, Vector3(float(sx), fy + 0.42, float(cz)), Vector3(0.5, 0.85, 0.5), chair, false)
	# The famous decorative Atlantic map on the aft bulkhead, in a gilt frame.
	var mapmat := _mat(Color(0.28, 0.40, 0.50), 0.5, 0.0)
	var gilt := _mat(Color(0.66, 0.52, 0.24), 0.4, 0.5)
	_box(parent, Vector3(0.0, fy + 4.6, -25.7), Vector3(13.0, 5.2, 0.15), mapmat, false)
	for fr in [[0.0, 2.7, 13.4, 0.25], [0.0, -2.7, 13.4, 0.25], [6.7, 0.0, 0.25, 5.6], [-6.7, 0.0, 0.25, 5.6]]:
		_box(parent, Vector3(float(fr[0]), fy + 4.6 + float(fr[1]), -25.62), Vector3(float(fr[2]), float(fr[3]), 0.3), gilt, false)


# One dining table: a solid white-clothed table with a slight top overhang and four chairs round it.
static func _dining_table(parent: Node3D, pos: Vector3, cloth: Material, chair: Material) -> void:
	_box(parent, pos + Vector3(0.0, 0.4, 0.0), Vector3(1.8, 0.8, 0.9), cloth, true)
	_box(parent, pos + Vector3(0.0, 0.81, 0.0), Vector3(2.0, 0.06, 1.1), cloth, false)
	for off in [[-1.15, 0.0], [1.15, 0.0], [0.0, -0.8], [0.0, 0.8]]:
		_box(parent, pos + Vector3(float(off[0]), 0.42, float(off[1])), Vector3(0.5, 0.85, 0.5), chair, false)


# First Class Main Hall: the tall A-deck entrance foyer you board into off the forward door (it was
# a bare volume). A reception/purser's desk with an office screen + ship's crest behind it, flanking
# sofas + side tables, decorative urns, and a glowing pendant. The forward A-deck floor rises on the
# bow sheer, so every piece is seated on the LOCAL floor (_sheer_y), not the flat amidships level.
static func _build_main_hall(parent: Node3D, wl: float) -> void:
	var root := Node3D.new()
	root.name = "MainHall"
	parent.add_child(root)
	var wood := _mat(Color(0.34, 0.22, 0.12), 0.5, 0.0)
	var darkwood := _mat(Color(0.22, 0.14, 0.09), 0.5, 0.0)
	var sofa := _mat(Color(0.30, 0.34, 0.42), 0.85, 0.0)
	var brass := _mat(Color(0.66, 0.52, 0.24), 0.4, 0.5)
	# Reception / purser's desk across the aft end, facing the entrance, with an office screen behind
	# (kept to ±4.5 so the side passages aft to the grand staircase stay open).
	var dy: float = _sheer_y(97.0, wl)
	_box(root, Vector3(0.0, dy + 0.55, 97.0), Vector3(9.0, 1.1, 1.4), darkwood, true)
	_box(root, Vector3(0.0, dy + 1.16, 97.0), Vector3(9.4, 0.12, 1.6), wood, false)
	var sy: float = _sheer_y(94.5, wl)
	_box(root, Vector3(0.0, sy + 1.4, 94.5), Vector3(9.0, 2.8, 0.3), wood, true)
	_box(root, Vector3(0.0, sy + 1.9, 94.32), Vector3(2.2, 1.3, 0.12), brass, false)   # ship's crest
	# Flanking sofas + side tables along the entrance approach, and decorative urns by the desk.
	for sx in [-1.0, 1.0]:
		var y2: float = _sheer_y(108.0, wl)
		_box(root, Vector3(sx * 7.0, y2 + 0.45, 108.0), Vector3(1.4, 0.9, 3.4), sofa, true)
		_box(root, Vector3(sx * 4.8, y2 + 0.4, 108.0), Vector3(1.2, 0.4, 1.2), wood, true)
		_cyl(root, Vector3(sx * 4.2, _sheer_y(101.0, wl) + 1.0, 101.0), 0.5, 2.0, darkwood, true)
	# A glowing pendant over the hall.
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.95, 0.82)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.93, 0.78)
	glow.emission_energy_multiplier = 0.7
	_box(root, Vector3(0.0, _sheer_y(108.0, wl) + 3.4, 108.0), Vector3(2.4, 0.5, 2.4), glow, false)
	# Warm light down the hall (seated above the rising floor).
	for lz in [98.0, 108.0, 116.0]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(0.0, _sheer_y(float(lz), wl) + 2.6, float(lz))
		lamp.light_color = Color(1.0, 0.92, 0.78)
		lamp.light_energy = 2.4
		lamp.omni_range = 20.0
		lamp.shadow_enabled = false
		root.add_child(lamp)


# One Art Deco passenger lift: brushed-steel two-leaf doors in a golden-burl surround, with chrome
# quarter-round kick strips up the jambs and a chrome call-plaque — the QM's preserved "Historical
# Elevator" look. `faces_x` = +1 if the doors face +x (sit on a port wall), -1 for a starboard wall.
static func _elevator(parent: Node3D, center: Vector3, faces_x: float, burl: Material, steel: Material, chrome: Material) -> void:
	var dw: float = 1.2     # door opening width (along z)
	var dh: float = 2.2     # door opening height
	for sz in [-1.0, 1.0]:
		_box(parent, center + Vector3(0.0, 0.0, sz * (dw * 0.5 + 0.16)), Vector3(0.34, dh + 0.4, 0.32), burl, true)   # burl jambs
		_box(parent, center + Vector3(faces_x * 0.08, -dh * 0.5 + 0.45, sz * dw * 0.5), Vector3(0.1, 0.9, 0.14), chrome, false)  # chrome kick strip
	_box(parent, center + Vector3(0.0, dh * 0.5 + 0.2, 0.0), Vector3(0.34, 0.4, dw + 0.64), burl, true)               # burl lintel
	for leaf in [-1.0, 1.0]:
		_box(parent, center + Vector3(faces_x * 0.03, 0.0, leaf * dw * 0.25), Vector3(0.06, dh, dw * 0.5 - 0.015), steel, true)   # steel door leaves
	_box(parent, center + Vector3(faces_x * 0.06, 0.35, dw * 0.5 + 0.16), Vector3(0.05, 0.32, 0.12), chrome, false)   # call plaque


# First Class lift lobby + grand SWITCHBACK staircase, in the forward stairwell (the straight flight
# was replaced). Two short flights with a green/cream checkerboard mid-landing climb A-deck -> the
# Promenade around a burl central spine; a bank of two Art Deco lifts faces the lobby off the port
# wall; etched-glass balustrades with chrome handrails ring the well on the Promenade above. The QM's
# preserved Art Deco vocabulary (burl panelling over a dark dado, brushed steel, chrome, etched
# glass, checkerboard marble) — modelled on the real first-class stair-and-lift foyers.
static func _build_lift_lobby(parent: Node3D, wl: float, hz0: float, hz1: float, hx: float) -> void:
	var root := Node3D.new()
	root.name = "LiftLobby"
	parent.add_child(root)
	var ya: float = wl + DECK_MAIN          # A-deck floor
	var yp: float = wl + DECK_PROM          # Promenade floor (lobby ceiling)
	var ym: float = (ya + yp) * 0.5         # mid-landing
	var burl := _mat(Color(0.60, 0.42, 0.19), 0.35, 0.1)
	var dado := _mat(Color(0.28, 0.16, 0.09), 0.5, 0.0)
	var steel := _mat(Color(0.62, 0.64, 0.66), 0.35, 0.85)
	var chrome := _mat(Color(0.82, 0.84, 0.86), 0.18, 0.95)
	var tread := _mat(COL_TEAK, 0.7, 0.0)
	var glass := _etched_glass_mat()
	var zc: float = (hz0 + hz1) * 0.5
	# Checkerboard marble lobby floor on the A-deck.
	_box(root, Vector3(0.0, ya + 0.02, 53.0), Vector3(14.0, 0.04, 18.0), _checker_mat(14.0, 18.0, 0.62), false)
	# Switchback: lower flight (port) -> checkerboard mid-landing -> upper flight (starboard) -> a top
	# landing onto the Promenade. Short ~3 m flights so the steps are normal depth, not a long ramp.
	var checker_land := _checker_mat(7.8, 3.4, 0.62)
	_stair_run(root, -2.0, 57.0, 54.0, ya, ym, 3.4, tread)
	_box(root, Vector3(0.0, ym - 0.1, 52.3), Vector3(7.8, 0.2, 3.4), checker_land, true)
	_stair_run(root, 2.0, 54.0, 57.0, ym, yp, 3.4, tread)
	_box(root, Vector3(2.0, yp - 0.1, 58.0), Vector3(3.4, 0.2, 2.4), tread, true)
	# Burl central spine between the flights (burl over a dark dado), and burl stringer walls on each
	# flight's outer edge — these hide _stair_run's solid flanks and read as panelled balustrades.
	_box(root, Vector3(0.0, ya + 0.55, 55.5), Vector3(0.3, 1.1, 3.6), dado, true)
	_box(root, Vector3(0.0, (ya + 1.1 + yp) * 0.5, 55.5), Vector3(0.3, yp - ya - 1.1, 3.6), burl, true)
	_box(root, Vector3(-3.9, (ya + ym + 1.0) * 0.5, 55.5), Vector3(0.28, ym + 1.0 - ya, 3.8), burl, true)
	_box(root, Vector3(3.9, (ym + yp + 1.0) * 0.5, 55.5), Vector3(0.28, yp + 1.0 - ym, 3.8), burl, true)
	# Lobby walls (two-tone: dark dado course + burl above), port + starboard + aft. Forward stays
	# open toward the entrance / Main Hall.
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(sx * 7.0, ya + 0.6, 53.0), Vector3(0.3, 1.2, 18.0), dado, true)
		_box(root, Vector3(sx * 7.0, (ya + 1.2 + yp) * 0.5, 53.0), Vector3(0.3, yp - ya - 1.2, 18.0), burl, true)
	_box(root, Vector3(0.0, ya + 0.6, 44.0), Vector3(14.0, 1.2, 0.3), dado, true)
	_box(root, Vector3(0.0, (ya + 1.2 + yp) * 0.5, 44.0), Vector3(14.0, yp - ya - 1.2, 0.3), burl, true)
	# Bank of two lifts on the port wall, facing the lobby.
	for ez in [49.5, 56.5]:
		_elevator(root, Vector3(-6.83, ya + 1.2, float(ez)), 1.0, burl, steel, chrome)
	# Etched-glass balustrade + chrome handrail ringing the well on the Promenade, except the
	# starboard step-off where the upper flight lands.
	var gy: float = yp + 0.5
	var rails: Array = [
		[-hx, zc, 0.1, hz1 - hz0],      # port side
		[hx, zc - 1.9, 0.1, hz1 - hz0 - 3.8],   # starboard side (short — leave the step-off clear)
		[0.0, hz0, hx * 2.0, 0.1],      # aft end
		[-hx * 0.5, hz1, hx, 0.1],      # forward port half
	]
	for r in rails:
		_box(root, Vector3(float(r[0]), gy, float(r[1])), Vector3(float(r[2]), 1.0, float(r[3])), glass, true)
		_box(root, Vector3(float(r[0]), gy + 0.55, float(r[1])), Vector3(float(r[2]) + 0.06, 0.08, float(r[3]) + 0.06), chrome, false)
	# Lighting: a stepped Deco ceiling fixture over each side aisle + warm omni fill. The fixtures must
	# sit on the SOLID lobby ceiling flanking the stairwell hole (x=±5.4, outside hx=±4), not over the
	# open well — at the old x=±3.5 they hung in the cut-away void above the stairs as floating panels.
	_deco_ceiling_light(root, Vector3(-5.4, yp - 0.3, 53.0), 1.3, 2.4, _mat(Color(0.95, 0.92, 0.82), 0.5, 0.0), chrome, 1.4)
	_deco_ceiling_light(root, Vector3(5.4, yp - 0.3, 53.0), 1.3, 2.4, _mat(Color(0.95, 0.92, 0.82), 0.5, 0.0), chrome, 1.4)
	for lz in [48.0, 56.0]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(0.0, yp - 0.6, float(lz))
		lamp.light_color = Color(1.0, 0.93, 0.80)
		lamp.light_energy = 1.5
		lamp.omni_range = 13.0
		lamp.shadow_enabled = false
		root.add_child(lamp)


# A wing of First Class staterooms on the aft A-deck: a near-1:1 central corridor (1.0 m wide — the
# real cabin alleyways were ~3 ft) lined with cabin doors, the cabins behind them divided by
# partitions and closed by an outboard wall (the structural columns at x=±6.5 fall in the void
# behind it). A sample of cabins is furnished (bed, pillow, wardrobe); the rest read as doors.
static func _build_cabins(parent: Node3D, wl: float) -> void:
	var root := Node3D.new()
	root.name = "Cabins"
	parent.add_child(root)
	var ya: float = wl + DECK_MAIN      # A-deck floor
	var yc: float = wl + DECK_PROM      # ceiling = Promenade floor above
	var white := _mat(COL_SUPER, 0.7, 0.0)
	var wood := _mat(Color(0.34, 0.22, 0.12), 0.5, 0.0)
	var bedmat := _mat(Color(0.50, 0.28, 0.30), 0.85, 0.0)
	var z0: float = -78.0
	var z1: float = -38.0
	# With the slimmed player (0.6 m wide; Player.gd radius 0.3) the corridor + doors come back down to
	# near true 1:1: a ~1.0 m clear alley (~3 ft) with 1.0 m cabin doors, and still walkable.
	var cw: float = 0.6                 # corridor half-width -> ~1.0 m clear alley (near 1:1)
	var cd: float = 5.3                 # cabin outboard wall (~4.7 m deep cabins)
	var doors: Array = [-75.5, -70.5, -65.5, -60.5, -55.5, -50.5, -45.5, -40.5]
	for sgn in [-1.0, 1.0]:
		_longitudinal_door_wall(root, sgn * cw, z0, z1, ya, yc, 0.2, doors, 1.0, 2.1, white)
		_box(root, Vector3(sgn * cd, (ya + yc) * 0.5, (z0 + z1) * 0.5), Vector3(0.2, yc - ya, z1 - z0), white, true)
		for pz in [-38.0, -43.0, -48.0, -53.0, -58.0, -63.0, -68.0, -73.0, -78.0]:
			_box(root, Vector3(sgn * (cw + cd) * 0.5, (ya + yc) * 0.5, float(pz)), Vector3(cd - cw, yc - ya, 0.2), white, true)
	# Furnish every cabin: bed (pillow end against the aft partition), a wardrobe, and a compact
	# ensuite bathroom — toilet, washbasin, shower — tucked in the corner by the door, the way a real
	# cruise stateroom is laid out (~25-30 sq ft modular unit). See _cabin_interior.
	var porc := _mat(Color(0.93, 0.93, 0.95), 0.2, 0.0)
	for cz in [-40.5, -45.5, -50.5, -55.5, -60.5, -65.5, -70.5, -75.5]:
		for sgn2 in [-1.0, 1.0]:
			_cabin_interior(root, float(cz), float(sgn2), ya, yc, cw, white, wood, bedmat, porc)
	# Art Deco corridor fit-out (deep-red carpet, glossy-black wainscot, burl + chrome door surrounds,
	# globe sconces) over the plain white alley walls — matching the QM's first-class cabin corridors.
	_deco_corridor(root, z0, z1, ya, yc, cw, doors, 1.0)
	# Background corridor fill (the globe sconces in _deco_corridor carry the rest).
	for lz in [-44.0, -54.0, -64.0, -74.0]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(0.0, yc - 0.4, float(lz))
		lamp.light_color = Color(1.0, 0.92, 0.78)
		lamp.light_energy = 1.1
		lamp.omni_range = 9.0
		lamp.shadow_enabled = false
		root.add_child(lamp)


# Art Deco fit-out for a 1:1 cabin alleyway (per the QM's first-class corridors): a deep-red
# patterned carpet runner; a tall glossy-black lacquer wainscot under a warm cream upper wall, split
# by a burl handrail; polished-chrome strips + golden-burl surrounds framing each cabin doorway; and
# white globe sconces high on the walls. Overlaid (facing inboard) on the plain white door-walls at
# x=±cw. The QM Art Deco vocabulary established here — burl / black lacquer / chrome / globe — is
# reused for the lift lobbies and stair foyers.
static func _deco_corridor(parent: Node3D, z0: float, z1: float, ya: float, yc: float, cw: float, doors: Array, dw: float) -> void:
	var lacquer := _mat(Color(0.05, 0.05, 0.06), 0.12, 0.45)      # glossy black lacquer wainscot
	var burl := _mat(Color(0.60, 0.42, 0.19), 0.35, 0.1)          # golden birdseye-maple burl
	var cream := _mat(Color(0.82, 0.76, 0.63), 0.85, 0.0)         # warm cream upper wall
	var chrome := _mat(Color(0.82, 0.84, 0.86), 0.18, 0.95)       # polished chrome strip
	var globe := StandardMaterial3D.new()
	globe.albedo_color = Color(1.0, 0.96, 0.86)
	globe.emission_enabled = true
	globe.emission = Color(1.0, 0.94, 0.80)
	globe.emission_energy_multiplier = 0.7
	var wains_h: float = 1.3
	var face: float = cw - 0.12                                    # facing plane, just inside the wall inner face
	# Art Deco medallion carpet runner down the alley.
	var cwid: float = (cw - 0.08) * 2.0
	var carpet := _deco_carpet_mat(cwid, z1 - z0, 0.55)
	_box(parent, Vector3(0.0, ya + 0.03, (z0 + z1) * 0.5), Vector3(cwid, 0.05, z1 - z0), carpet, false)
	# Door spans -> the wall segments between them get the wainscot/cream/rail facing.
	var d: Array = doors.duplicate()
	d.sort()
	var starts: Array = [z0]
	var ends: Array = []
	for dz in d:
		ends.append(float(dz) - dw * 0.5)
		starts.append(float(dz) + dw * 0.5)
	ends.append(z1)
	for sgn in [-1.0, 1.0]:
		var xw: float = sgn * face
		for i in range(starts.size()):
			var sa: float = float(starts[i])
			var sb: float = float(ends[i])
			if sb - sa < 0.06:
				continue
			var sc: float = (sa + sb) * 0.5
			var sl: float = sb - sa - 0.02
			_box(parent, Vector3(xw, ya + wains_h * 0.5, sc), Vector3(0.05, wains_h, sl), lacquer, false)
			_box(parent, Vector3(xw, (ya + wains_h + 0.07 + yc) * 0.5, sc), Vector3(0.05, yc - ya - wains_h - 0.07, sl), cream, false)
			_box(parent, Vector3(xw, ya + wains_h + 0.04, sc), Vector3(0.08, 0.09, sl), burl, false)
		# Burl surround + chrome strip up each side of every doorway, with a burl lintel over it.
		for dz in d:
			for jamb in [-1.0, 1.0]:
				_box(parent, Vector3(xw, ya + 1.05, float(dz) + jamb * dw * 0.5), Vector3(0.08, 2.1, 0.14), burl, false)
				_box(parent, Vector3(xw - sgn * 0.05, ya + 1.05, float(dz) + jamb * dw * 0.5), Vector3(0.03, 2.0, 0.05), chrome, false)
			_box(parent, Vector3(xw, ya + 2.16, float(dz)), Vector3(0.08, 0.14, dw + 0.12), burl, false)
	# White globe sconces high on the walls, staggered side to side down the alley.
	var gi: int = 0
	var gz: float = z0 + 3.0
	while gz < z1 - 1.0:
		var gs: float = 1.0 if (gi % 2 == 0) else -1.0
		var gm := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.13
		sm.height = 0.24
		gm.mesh = sm
		gm.material_override = globe
		gm.position = Vector3(gs * (face - 0.05), yc - 0.32, gz)
		parent.add_child(gm)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(gs * (face - 0.25), yc - 0.34, gz)
		lamp.light_color = Color(1.0, 0.93, 0.80)
		lamp.light_energy = 0.9
		lamp.omni_range = 6.0
		lamp.shadow_enabled = false
		parent.add_child(lamp)
		gz += 4.0
		gi += 1


# One stateroom's fit-out (s = +1 starboard / -1 port): the bed against the outboard wall with its
# pillow end against the aft partition; a wardrobe in the forward-outboard corner; and a compact
# ensuite bathroom (toilet, washbasin, shower stall; door in its aft wall) filling the forward-
# inboard corner by the cabin door, the way a cruise stateroom's modular bathroom sits. Bathroom door
# is 1.0 m so the 0.9 m-wide player can just get in (a true ~0.6 m bathroom door wouldn't fit).
static func _cabin_interior(parent: Node3D, cz: float, s: float, ya: float, yc: float, cw: float, white: Material, wood: Material, bedmat: Material, porc: Material) -> void:
	var hh: float = yc - ya
	var hy: float = (ya + yc) * 0.5
	_box(parent, Vector3(s * 4.45, ya + 0.3, cz - 1.45), Vector3(1.7, 0.5, 1.9), bedmat, true)            # bed
	_box(parent, Vector3(s * 4.45, ya + 0.62, cz - 2.25), Vector3(1.7, 0.16, 0.45), white, false)        # pillow (at the aft partition)
	_box(parent, Vector3(s * 4.7, hy, cz + 2.0), Vector3(0.8, hh, 0.7), wood, true)                       # wardrobe
	_box(parent, Vector3(s * 2.5, hy, cz + 1.5), Vector3(0.15, hh, 1.9), white, true)                     # bathroom cabin-side wall
	_box(parent, Vector3(s * (cw + 1.2) * 0.5, hy, cz + 0.55), Vector3(1.2 - cw, hh, 0.15), white, true)   # bathroom aft wall (corridor seg)
	_box(parent, Vector3(s * 2.35, hy, cz + 0.55), Vector3(0.3, hh, 0.15), white, true)                   # bathroom aft wall (cabin seg)
	_box(parent, Vector3(s * 1.7, ya + 2.1 + (hh - 2.1) * 0.5, cz + 0.55), Vector3(1.0, hh - 2.1, 0.15), white, true)  # door lintel
	_box(parent, Vector3(s * 1.2, ya + 0.3, cz + 2.0), Vector3(0.5, 0.6, 0.55), porc, false)              # toilet bowl
	_box(parent, Vector3(s * 1.2, ya + 0.75, cz + 2.25), Vector3(0.45, 0.45, 0.18), porc, false)          # cistern
	_box(parent, Vector3(s * 1.05, ya + 0.55, cz + 1.05), Vector3(0.4, 0.16, 0.4), porc, false)           # washbasin
	_box(parent, Vector3(s * 2.1, ya + 0.06, cz + 1.6), Vector3(0.7, 0.12, 0.9), porc, false)             # shower tray
	_box(parent, Vector3(s * 2.1, ya + 1.6, cz + 1.6), Vector3(0.12, 0.12, 0.12), porc, false)            # shower head
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(s * 3.0, yc - 0.4, cz)
	lamp.light_color = Color(1.0, 0.93, 0.80)
	lamp.light_energy = 1.2
	lamp.omni_range = 6.0
	lamp.shadow_enabled = false
	parent.add_child(lamp)


# Transverse partition wall at longitudinal z, spanning ±half_w and y0..y1, with a central
# doorway (two jambs + a lintel) at door_x.
static func _transverse_door_wall(parent: Node3D, z: float, half_w: float, y0: float, y1: float, t: float, door_x: float, dw: float, dh: float, mat: Material) -> void:
	# Sink the wall foot 0.12 m below the floor so its bottom FACE is buried inside the floor/deck
	# slab, never coplanar with the slab top — coincident same-plane faces depth-fight into flicker
	# slivers along the wall base + door threshold (the inc-27 lesson, now in the shared helper). The
	# door head stays measured from the REAL floor (y0); callers should bury the top into the ceiling
	# slab the same way (pass y1 a touch into the deckhead lining).
	var yb: float = y0 - 0.12
	var h: float = y1 - yb
	var cy: float = (yb + y1) * 0.5
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
	# Sink the wall foot below the floor (see _transverse_door_wall) so the base isn't coplanar with
	# the floor slab top and z-fight into flicker slivers.
	var yb: float = y0 - 0.12
	var h: float = y1 - yb
	var cy: float = (yb + y1) * 0.5
	# The wall-segment sweep below walks the door positions left-to-right and fills the gaps between
	# them, so the doors MUST be in ascending z — otherwise the segments overlap into one solid wall
	# and every doorway gets walled over (which sealed the galleries off the rooms). Sort defensively.
	var dzs: Array = door_zs.duplicate()
	dzs.sort()
	var edges: Array = [z0]
	for dz in dzs:
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
	for dz in dzs:
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


# A procedurally-painted Art Deco medallion carpet (the QM first-class corridor pattern): a circular
# floral medallion — green/cream/red/gold concentric rings — repeated over a dark-burgundy ground.
# Painted into one small tileable image, then UV-tiled so each medallion is ~`medallion` m across the
# given carpet width × length (keeps the medallions circular at any carpet size). Reused for the
# corridor + foyer carpets.
static func _deco_carpet_mat(width: float, length: float, medallion: float) -> StandardMaterial3D:
	var n: int = 64
	var img := Image.create(n, n, true, Image.FORMAT_RGB8)
	img.fill(Color(0.28, 0.13, 0.12))                       # dark burgundy ground
	var rings: Array = [
		[0.45, Color(0.22, 0.34, 0.22)],   # green outer
		[0.36, Color(0.82, 0.76, 0.58)],   # cream
		[0.27, Color(0.62, 0.16, 0.14)],   # red rose
		[0.15, Color(0.80, 0.46, 0.18)],   # gold
		[0.06, Color(0.40, 0.13, 0.13)],   # dark centre
	]
	for y in range(n):
		for x in range(n):
			var dx: float = (float(x) + 0.5) / float(n) - 0.5
			var dy: float = (float(y) + 0.5) / float(n) - 0.5
			var r: float = sqrt(dx * dx + dy * dy)
			for ring in rings:
				if r <= float(ring[0]):
					img.set_pixel(x, y, ring[1])
	img.generate_mipmaps()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.uv1_scale = Vector3(maxf(width / medallion, 1.0), maxf(length / medallion, 1.0), 1.0)
	mat.roughness = 0.95
	return mat


# A green-and-cream checkerboard marble floor (the QM stair-landing / lobby floor), painted as an
# 8×8-square tile and UV-tiled so each square is ~`tile` m on the given width × length.
static func _checker_mat(width: float, length: float, tile: float) -> StandardMaterial3D:
	var n: int = 64
	var sq: int = 8
	var img := Image.create(n, n, true, Image.FORMAT_RGB8)
	var cream := Color(0.80, 0.76, 0.62)
	var green := Color(0.22, 0.34, 0.24)
	for y in range(n):
		for x in range(n):
			img.set_pixel(x, y, cream if ((x / sq) + (y / sq)) % 2 == 0 else green)
	img.generate_mipmaps()
	var spi: float = float(n) / float(sq)        # squares per image axis (8)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.uv1_scale = Vector3(maxf(width / (spi * tile), 1.0), maxf(length / (spi * tile), 1.0), 1.0)
	mat.roughness = 0.35
	return mat


# Frosted, faintly self-lit etched glass (the QM stair / lift-lobby balustrade + door panels).
static func _etched_glass_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.80, 0.85, 0.84, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.35
	m.metallic = 0.0
	m.emission_enabled = true
	m.emission = Color(0.78, 0.84, 0.82)
	m.emission_energy_multiplier = 0.18
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
