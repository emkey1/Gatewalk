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


# Build the liner into `parent`. Returns an Array of 4 gate world-positions on the
# decks (gate 0 sits aft, near the arrival spawn).
static func build(parent: Node3D, world_seed: int, wl: float) -> Array:
	var root := Node3D.new()
	root.name = "QueenMary"
	parent.add_child(root)
	var rng := StableRng.new(StableRng.mix_string(world_seed, "liner", 1))

	var hull_mat := _mat(Color(0.06, 0.06, 0.07), 0.82, 0.05)   # Cunard black topsides
	var deck_mat := _mat(Color(0.55, 0.42, 0.26), 0.92, 0.0)    # teak weather deck

	# --- STUB massing (increment 1): a black box hull capped by a single walkable teak
	# deck, so the map registers and is boardable end-to-end. The faithful hull, stepped
	# superstructure, funnels, masts and lifeboats replace this in the next increments. ---
	var deck_y: float = wl + DECK_MAIN
	var hull_top: float = deck_y - 0.25
	var hull_bot: float = wl - DRAUGHT
	_box(root, Vector3(0.0, (hull_top + hull_bot) * 0.5, 0.0),
		Vector3(BEAM - 2.0, hull_top - hull_bot, LOA), hull_mat, true)
	_box(root, Vector3(0.0, deck_y - 0.25, 0.0), Vector3(BEAM, 0.5, LOA), deck_mat, true)

	# --- Four exit gates spread fore-and-aft along the deck centre, gate 0 aft. ---
	var gates: Array = []
	var gy: float = deck_y + 0.05
	var gate_zs: Array = [-HULL_HALF_LEN * 0.60, HULL_HALF_LEN * 0.58, HULL_HALF_LEN * 0.12, -HULL_HALF_LEN * 0.22]
	for gi in range(4):
		var gx: float = rng.randf_range(-HULL_HALF_BEAM * 0.45, HULL_HALF_BEAM * 0.45)
		gates.append(Vector3(gx, gy, float(gate_zs[gi])))
	return gates


# Deck arrival / spawn: aft on the main deck, a few metres ahead of gate 0, looking
# toward the bow. Shared by Main's _find_spawn_position and the _scatter_liner teleport.
static func spawn_position(wl: float) -> Vector3:
	return Vector3(0.0, wl + DECK_MAIN + 1.2, -HULL_HALF_LEN * 0.60 + 14.0)


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
