extends RefCounted
class_name CityFactory

const MapContext = preload("res://scripts/core/MapContext.gd")
const MultiMeshScatter = preload("res://scripts/factories/MultiMeshScatter.gd")
const CITY_SHADER := preload("res://scripts/factories/city_surface.gdshader")

# A ruined, overgrown city: a grid of streets between blocks of multistory buildings
# (hollow shells you can walk into through a doorway, with window facades), parks
# gone wild with vegetation, and rubble lots. Returns the world positions where the
# objective "data cores" should be hidden (inside buildings).

const CELL: float = 34.0     # block-to-block pitch (block + street)
const BLOCK: float = 25.0    # block footprint
const STREET_W: float = 8.0
const STORY_H: float = 4.5   # tall floor-to-floor so the half-landing keeps head height
const TARGET_CORES: int = 6


static func scatter_city(parent: Node3D, world_seed: int, density_level: int, context: MapContext) -> Array:
	var height_fn := Callable(context, "height_at_world")
	var extent: float = minf(context.world_half_size() * 0.7, 145.0)
	var n: int = int(extent / CELL)

	var root := Node3D.new()
	root.name = "City"
	parent.add_child(root)

	var building_positions: Array = []

	var street_mat := _street_material()
	var streets := Node3D.new()
	streets.name = "Streets"
	root.add_child(streets)
	var span: float = (float(n) + 1.0) * CELL * 2.0
	for i in range(-n, n + 1):
		var line: float = (float(i) + 0.5) * CELL
		_street_slab(streets, Vector3(line, 0.0, 0.0), Vector3(STREET_W, 0.12, span), street_mat, height_fn)
		_street_slab(streets, Vector3(0.0, 0.0, line), Vector3(span, 0.12, STREET_W), street_mat, height_fn)

	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			var bx: float = float(i) * CELL
			var bz: float = float(j) * CELL
			if Vector2(bx, bz).length() > extent:
				continue
			if absi(i) <= 1 and absi(j) <= 1:
				continue  # open plaza at the centre so the player spawns in the clear
			var cell_rng := StableRng.new(StableRng.mix_string(world_seed, "city_cell", i * 1000 + j))
			var gy: float = float(height_fn.call(bx, bz))
			if context.city_cell_has_basement(i, j):
				# A building over a carved terrain hole: fixed footprint, centred in the cell
				# so the hole lines up under its walls, with a reachable basement below.
				var bsz: float = MapContext.CITY_BASEMENT_HALF * 2.0
				var bpos: Vector3 = Vector3(bx, gy + 0.12, bz)
				var bst: int = cell_rng.randi_range(1, 4)
				_build_building(root, bpos, bsz, bsz, bst, cell_rng, Vector3(0.0, 0.0, 1.0), true, _roll_roof(world_seed, bx, bz, bst))
				building_positions.append(bpos)
				continue
			var roll: float = cell_rng.randf()
			if roll < 0.34:
				_build_park(root, Vector3(bx, gy, bz), cell_rng, height_fn)
			elif roll < 0.66:
				_build_block(root, Vector3(bx, gy, bz), cell_rng, height_fn, building_positions, world_seed)
			else:
				_build_rubble(root, Vector3(bx, gy, bz), cell_rng)

	# Spread the objective cores across the city's buildings.
	var cores: Array = []
	if not building_positions.is_empty():
		var step: int = maxi(1, building_positions.size() / TARGET_CORES)
		var idx: int = 0
		while idx < building_positions.size() and cores.size() < TARGET_CORES:
			cores.append((building_positions[idx] as Vector3) + Vector3(0.0, 1.1, 0.0))
			idx += step
	return cores


# --- Buildings ---------------------------------------------------------------

# A city block subdivided into lots (research: blocks -> lots -> one building per lot,
# Parish & Müller / "Procedural Generation For Dummies"). Big blocks split into two
# parcels along their longer axis, each set back from the lot edge, so a block reads as
# a row of buildings with an alley between rather than one monolith.
static func _build_block(parent: Node3D, center: Vector3, rng: StableRng, height_fn: Callable, out_positions: Array, world_seed: int) -> void:
	var bw: float = BLOCK - rng.randf_range(2.0, 5.0)
	var bd: float = BLOCK - rng.randf_range(2.0, 5.0)
	var split_long: bool = bw >= bd
	var span: float = bw if split_long else bd
	var lots: int = 2 if (span > 18.0 and rng.randf() < 0.4) else 1   # ~40% of big blocks split into two lots
	var lot_span: float = span / float(lots)
	for k in range(lots):
		var off: float = (float(k) + 0.5) * lot_span - span * 0.5
		var setback: float = rng.randf_range(0.8, 2.0)
		var lw: float = (lot_span - setback) if split_long else (bw - setback)
		var ld: float = (bd - setback) if split_long else (lot_span - setback)
		if lw < 7.0 or ld < 7.0:
			continue
		var lc: Vector3 = center + (Vector3(off, 0.0, 0.0) if split_long else Vector3(0.0, 0.0, off))
		var gy_max: float = -1.0e9   # highest terrain under the footprint
		for sx in [-lw * 0.5, -lw * 0.25, 0.0, lw * 0.25, lw * 0.5]:
			for sz in [-ld * 0.5, -ld * 0.25, 0.0, ld * 0.25, ld * 0.5]:
				gy_max = maxf(gy_max, float(height_fn.call(lc.x + sx, lc.z + sz)))
		# Lift the floor a small plinth clear of the (near-flat) terrain so it never pokes
		# through / z-fights with the ground; small enough to step into through the door.
		lc.y = gy_max + 0.12
		# Door faces a street: for a split lot that's the OUTER side (away from the alley
		# between the two lots); an unsplit block fronts a street on every side.
		var door_normal: Vector3 = Vector3(0.0, 0.0, 1.0)
		if lots > 1:
			door_normal = Vector3(signf(off), 0.0, 0.0) if split_long else Vector3(0.0, 0.0, signf(off))
		var st: int = rng.randi_range(1, 4)
		_build_building(parent, lc, lw, ld, st, rng, door_normal, false, _roll_roof(world_seed, lc.x, lc.z, st))
		out_positions.append(lc)


# Deterministic per-building rooftop-access roll on its OWN rng stream (keyed by world +
# position), so toggling it never disturbs that building's window/material/divider draws.
# Only multi-storey buildings qualify; ~35% of those get a roof you can climb to.
static func _roll_roof(world_seed: int, bx: float, bz: float, stories: int) -> bool:
	if stories < 2:
		return false
	var r := StableRng.new(StableRng.mix_string(world_seed, "city_roof", roundi(bx) * 100003 + roundi(bz)))
	return r.randf() < 0.35


# A walkable multistory building: solid floor slabs per storey, a switchback ramp
# stairwell in the back corner, and room dividers with doorways. door_normal selects
# which (street-facing) wall carries the entrance.
static func _build_building(parent: Node3D, pos: Vector3, w: float, d: float, stories: int, rng: StableRng, door_normal: Vector3 = Vector3(0.0, 0.0, 1.0), has_basement: bool = false, roof_access: bool = false) -> void:
	var b := Node3D.new()
	b.position = pos
	parent.add_child(b)
	var mat := _exterior_material(rng)            # outer cladding + stairs
	# One interior paint shared by the room dividers AND the inward face of the outer
	# walls, so the inside of the building reads as a single consistent finish.
	var inner_col := Color.from_hsv(rng.randf_range(0.0, 1.0), rng.randf_range(0.10, 0.30), rng.randf_range(0.60, 0.82))
	var inner_stripe: float = 1.0 if rng.randf() < 0.4 else 0.0
	var div_mat := _surface_mat(4, inner_col, inner_col, Vector2(1.0, 1.0), 0.0, 0.65, inner_stripe)
	var wall_mat: ShaderMaterial = mat.duplicate()   # cladding outside, interior paint inside
	wall_mat.set_shader_parameter("inner_enable", 1.0)
	wall_mat.set_shader_parameter("inner_color", inner_col)
	wall_mat.set_shader_parameter("inner_stripe", inner_stripe)
	wall_mat.set_shader_parameter("building_center", pos)
	# Floor finish on top; a ceiling finish (plaster / concrete / acoustic tile) underneath,
	# so a room's ceiling never looks like the floor of the storey above.
	var floor_mat := _floor_material(rng)
	var ceil_col := Color(rng.randf_range(0.62, 0.74), rng.randf_range(0.60, 0.72), rng.randf_range(0.56, 0.66))
	var ceil_style: int = rng.randi_range(0, 2)
	floor_mat.set_shader_parameter("ceiling_enable", 1.0)
	floor_mat.set_shader_parameter("ceiling_color", ceil_col)
	floor_mat.set_shader_parameter("ceiling_style", ceil_style)
	# Roof slab: concrete on top, the same ceiling underneath for the top storey.
	var roof_mat: ShaderMaterial = _surface_mat(2, Color(rng.randf_range(0.42, 0.52), rng.randf_range(0.42, 0.52), rng.randf_range(0.42, 0.52)), Color(0.40, 0.40, 0.40), Vector2(1.0, 1.0), 0.0, 0.95)
	roof_mat.set_shader_parameter("ceiling_enable", 1.0)
	roof_mat.set_shader_parameter("ceiling_color", ceil_col)
	roof_mat.set_shader_parameter("ceiling_style", ceil_style)
	var sh: float = STORY_H
	var th: float = 0.3
	var stair_w: float = minf(5.0, w - 5.0)     # stairwell (two half-flights wide) in the back-left corner
	var stair_run: float = minf(5.5, d - 3.0)
	var hx1: float = -w * 0.5 + stair_w         # stairwell occupies x in [-w/2, hx1]
	var hz1: float = -d * 0.5 + stair_run       # ...and z in [-d/2, hz1]
	var base_level: int = -1 if has_basement else 0
	var base_y: float = float(base_level) * sh
	var height: float = float(stories) * sh
	var door_w: float = 2.4
	var door_h: float = 2.8

	# --- Basement perimeter walls. The terrain is holed under the footprint (see
	# MapContext.city_point_in_basement), so this below-grade space is open and reachable
	# down the stairwell. ---
	if has_basement:
		_wall(b, Vector3(0.0, base_y * 0.5, -d * 0.5), Vector3(w, -base_y, th), mat)
		_wall(b, Vector3(-w * 0.5, base_y * 0.5, 0.0), Vector3(th, -base_y, d), mat)
		_wall(b, Vector3(w * 0.5, base_y * 0.5, 0.0), Vector3(th, -base_y, d), mat)
		_wall(b, Vector3(0.0, base_y * 0.5, d * 0.5), Vector3(w, -base_y, th), mat)
		# A soft fill light so the cellar reads as a dim room rather than a pit of shadow.
		# The basement is sealed off from the sun, so without this it gets only ambient and
		# you cross a hard dark line at the hole edge. Shadows on so the glow stays in the
		# cellar (and up the stairwell) instead of bleeding through the street; distance-fade
		# so only the basement you are near actually pays for a shadow.
		var cellar := OmniLight3D.new()
		cellar.position = Vector3(0.0, base_y + sh * 0.62, 0.0)
		cellar.light_color = Color(1.0, 0.91, 0.78)
		cellar.light_energy = 1.6
		cellar.omni_range = maxf(w, d) * 1.1
		cellar.shadow_enabled = true
		cellar.distance_fade_enabled = true
		cellar.distance_fade_begin = 80.0
		cellar.distance_fade_shadow = 45.0
		cellar.distance_fade_length = 25.0
		b.add_child(cellar)

	# --- Above-ground walls with real window openings (grid frame). Window proportions
	# vary per building (sill height, window height, spacing) so the city isn't uniform;
	# within a building they stay consistent for rhythm. The door goes on the street-facing
	# wall (door_normal) so it is never trapped in the narrow alley between two lots. ---
	var sill_h: float = rng.randf_range(1.0, 2.0)
	var win_h: float = clampf(rng.randf_range(1.1, 1.9), 0.9, sh - sill_h - 1.0)
	var win_w: float = rng.randf_range(1.2, 2.4)   # absolute window width; solid piers fill the rest
	_grid_wall(b, Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, -d * 0.5), w * 0.5, height, wall_mat, (door_w if door_normal.z < -0.5 else 0.0), sill_h, win_h, win_w)
	_grid_wall(b, Vector3(0.0, 0.0, 1.0), Vector3(-1.0, 0.0, 0.0), Vector3(-w * 0.5, 0.0, 0.0), d * 0.5, height, wall_mat, (door_w if door_normal.x < -0.5 else 0.0), sill_h, win_h, win_w)
	_grid_wall(b, Vector3(0.0, 0.0, 1.0), Vector3(1.0, 0.0, 0.0), Vector3(w * 0.5, 0.0, 0.0), d * 0.5, height, wall_mat, (door_w if door_normal.x > 0.5 else 0.0), sill_h, win_h, win_w)
	_grid_wall(b, Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, d * 0.5), w * 0.5, height, wall_mat, (door_w if door_normal.z > 0.5 else 0.0), sill_h, win_h, win_w)
	# A roof-access building gets a walkable holed deck + parapet instead of this solid cap.
	if not roof_access:
		_decor_box(b, Vector3(0.0, height + 0.15, 0.0), Vector3(w + 0.4, 0.3, d + 0.4), roof_mat)

	# --- Walkable floors (stairwell hole + solid landing strip) + rooms ---
	var land_d: float = 1.5
	for lvl in range(base_level, stories):
		var fy: float = float(lvl) * sh
		var fth: float = 0.7 if lvl == 0 else 0.2     # ground floor is a thick foundation slab
		var fcy: float = fy - fth * 0.5               # keep the floor TOP at fy
		if lvl == base_level:
			var ov: float = 0.4 if lvl == 0 else 0.0  # foundation overhangs to hide the wall base on uneven terrain
			_wall(b, Vector3(0.0, fcy, 0.0), Vector3(w + ov, fth, d + ov), floor_mat)  # solid base / foundation
		else:
			# Footprint minus the stairwell corner; the room floor just past it is the landing.
			_wall(b, Vector3((hx1 + w * 0.5) * 0.5, fcy, 0.0), Vector3(w * 0.5 - hx1, fth, d), floor_mat)
			_wall(b, Vector3((-w * 0.5 + hx1) * 0.5, fcy, (hz1 + d * 0.5) * 0.5), Vector3(stair_w, fth, d * 0.5 - hz1), floor_mat)
		if lvl >= 0:   # a real interior floor plan above ground (the basement stays open)
			_floor_plan(b, w, d, hx1, hz1, fy, sh, div_mat, door_h, rng)

	# --- U-shaped half-landing stair per level (two short flights + a landing) ---
	for lvl in range(base_level, stories - 1):
		_build_ustair(b, -w * 0.5, hx1, -d * 0.5, hz1, float(lvl) * sh, float(lvl + 1) * sh, land_d, mat, floor_mat)

	# --- Optional rooftop access: a final flight up through a holed roof deck onto a
	# parapeted roof. Reuses the same holed-floor + stair patterns as every storey, so it
	# connects and reads identically; the parapet is a collidable wall that stops you
	# walking off the edge. ---
	if roof_access:
		var ry: float = height                                   # roof-deck top = top of the walls
		var rcy: float = ry - th * 0.5                            # deck slab (th thick), top flush at ry
		# Deck = footprint minus the stairwell hole, so you emerge from the stairwell.
		_wall(b, Vector3((hx1 + w * 0.5) * 0.5, rcy, 0.0), Vector3(w * 0.5 - hx1, th, d), floor_mat)
		_wall(b, Vector3((-w * 0.5 + hx1) * 0.5, rcy, (hz1 + d * 0.5) * 0.5), Vector3(stair_w, th, d * 0.5 - hz1), floor_mat)
		# Final flight: top storey up to the roof deck.
		_build_ustair(b, -w * 0.5, hx1, -d * 0.5, hz1, float(stories - 1) * sh, ry, land_d, mat, floor_mat)
		# Parapet: a low collidable wall ringing the roof edge so you can't walk off.
		var ph: float = 1.15
		var pth: float = 0.25
		_wall(b, Vector3(0.0, ry + ph * 0.5, -d * 0.5), Vector3(w, ph, pth), mat)
		_wall(b, Vector3(0.0, ry + ph * 0.5, d * 0.5), Vector3(w, ph, pth), mat)
		_wall(b, Vector3(-w * 0.5, ry + ph * 0.5, 0.0), Vector3(pth, ph, d), mat)
		_wall(b, Vector3(w * 0.5, ry + ph * 0.5, 0.0), Vector3(pth, ph, d), mat)


# A U-shaped half-landing stair for one storey: flight A climbs the left half to a
# mid-landing at the far end, then flight B climbs the right half back to the floor
# above. Readable, connects cleanly, keeps head height. Solid steps the capsule
# rounds into a smooth ~25 deg slope.
static func _build_ustair(parent: Node3D, x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, land_d: float, mat: Material, floor_mat: Material) -> void:
	# z0 = back wall, z1 = interior (open-room) edge. The mid-landing sits at the back,
	# and the arrival flight climbs back toward the room — so you never face a wall.
	var x_mid: float = (x0 + x1) * 0.5
	var mid_y: float = (y0 + y1) * 0.5
	var land_z1: float = z0 + land_d
	_wall(parent, Vector3((x0 + x1) * 0.5, mid_y - 0.1, (z0 + land_z1) * 0.5), Vector3(x1 - x0, 0.2, land_z1 - z0), floor_mat)
	_build_flight(parent, x0, x_mid, land_z1, z1, y0, mid_y, false, mat)   # left: interior edge up to the back landing
	_build_flight(parent, x_mid, x1, land_z1, z1, mid_y, y1, true, mat)    # right: back landing up to the interior edge


# One straight flight of solid steps between z_lo (back) and z_hi (interior edge).
# ascend_toward_hi: the climb arrives at z_hi facing the open room; else arrives at z_lo.
static func _build_flight(parent: Node3D, x0: float, x1: float, z_lo: float, z_hi: float, y0: float, y1: float, ascend_toward_hi: bool, mat: Material) -> void:
	var n: int = 6
	var rise: float = (y1 - y0) / float(n)
	var depth: float = (z_hi - z_lo) / float(n)
	var cx: float = (x0 + x1) * 0.5
	var sw: float = x1 - x0
	for j in range(n):
		var z: float = (z_lo + (float(j) + 0.5) * depth) if ascend_toward_hi else (z_hi - (float(j) + 0.5) * depth)
		var fill_h: float = float(j + 1) * rise
		_wall(parent, Vector3(cx, y0 + fill_h * 0.5, z), Vector3(sw - 0.3, fill_h, depth + 0.05), mat)


# --- Interior floor plan: a corridor fronting the stairwell + BSP rooms off it. ----------
# Approach distilled from procedural-floorplan research (BSP for building interiors +
# reserved corridor; Liapis PCG-book ch.3, Müller/CityEngine split grammar): only ever cut
# a rectangle with a FULL-SPAN wall, so partitions always terminate on another wall (no
# floating stubs), and punch one doorway per cut so the spanning tree of doors keeps every
# room reachable from the stair. A hall reserved in front of the stairwell gives circulation.
const ROOM_MIN: float = 3.0      # smallest room edge
const HALL_W: float = 1.6        # corridor width
const DOOR_W: float = 1.0        # interior doorway clear width
const PLAN_MAX_DEPTH: int = 2    # rooms per block stay believable (and the body count lean)

static func _floor_plan(parent: Node3D, w: float, d: float, hx1: float, hz1: float, fy: float, sh: float, mat: Material, door_h: float, rng: StableRng) -> void:
	var half_w: float = w * 0.5
	var half_d: float = d * 0.5
	var front_depth: float = half_d - hz1
	var has_back: bool = (half_w - hx1) > ROOM_MIN and (hz1 + half_d) > ROOM_MIN
	if w >= 9.0 and d >= 9.0 and front_depth > HALL_W + ROOM_MIN + 0.4 and has_back:
		# Hall (full width) right in front of the stairwell — you step off the stairs into it.
		var cz1: float = hz1 + HALL_W
		_wall_with_door(parent, false, cz1, -half_w, half_w, fy, sh, door_h, _rand_door(rng, -half_w, half_w), mat)
		_wall_with_door(parent, false, hz1, hx1, half_w, fy, sh, door_h, _rand_door(rng, hx1, half_w), mat)
		_seg(parent, true, hx1, -half_d, hz1, fy + sh * 0.5, sh, 0.18, mat)   # seal the stairwell's open side
		_subdivide(parent, -half_w, half_w, cz1, half_d, fy, sh, mat, door_h, rng, 0)   # rooms ahead of the hall
		_subdivide(parent, hx1, half_w, -half_d, hz1, fy, sh, mat, door_h, rng, 0)      # rooms behind-right of it
	else:
		# Smaller building: rooms fill the area in front of the stairs (entered straight off
		# the landing); a back-right pocket, if any, becomes its own room with a door in.
		_subdivide(parent, -half_w, half_w, hz1, half_d, fy, sh, mat, door_h, rng, 0)
		if has_back:
			_wall_with_door(parent, false, hz1, hx1, half_w, fy, sh, door_h, _rand_door(rng, hx1, half_w), mat)
			_seg(parent, true, hx1, -half_d, hz1, fy + sh * 0.5, sh, 0.18, mat)
			_subdivide(parent, hx1, half_w, -half_d, hz1, fy, sh, mat, door_h, rng, 0)


# A door centre keeping the whole opening inside [lo, hi].
static func _rand_door(rng: StableRng, lo: float, hi: float) -> float:
	if hi - lo < DOOR_W + 0.5:
		return (lo + hi) * 0.5
	return rng.randf_range(lo + DOOR_W * 0.5 + 0.25, hi - DOOR_W * 0.5 - 0.25)


# Recursively split a rectangle with full-span doorway-walls, cutting the longer side so
# rooms stay roughly square. Leaves are rooms.
static func _subdivide(parent: Node3D, x0: float, x1: float, z0: float, z1: float, fy: float, sh: float, mat: Material, door_h: float, rng: StableRng, depth: int) -> void:
	var wdt: float = x1 - x0
	var dpt: float = z1 - z0
	var can_x: bool = wdt >= ROOM_MIN * 2.0 + 0.2 and dpt >= DOOR_W + 0.6
	var can_z: bool = dpt >= ROOM_MIN * 2.0 + 0.2 and wdt >= DOOR_W + 0.6
	if not can_x and not can_z:
		return
	if depth >= PLAN_MAX_DEPTH or (depth >= 1 and rng.randf() < 0.22):
		return
	var split_x: bool
	if wdt > dpt * 1.2:
		split_x = true
	elif dpt > wdt * 1.2:
		split_x = false
	else:
		split_x = rng.randf() < 0.5
	if split_x and not can_x:
		split_x = false
	elif not split_x and not can_z:
		split_x = true
	if split_x:
		var cut: float = rng.randf_range(x0 + ROOM_MIN, x1 - ROOM_MIN)
		_wall_with_door(parent, true, cut, z0, z1, fy, sh, door_h, _rand_door(rng, z0, z1), mat)
		_subdivide(parent, x0, cut, z0, z1, fy, sh, mat, door_h, rng, depth + 1)
		_subdivide(parent, cut, x1, z0, z1, fy, sh, mat, door_h, rng, depth + 1)
	else:
		var cz: float = rng.randf_range(z0 + ROOM_MIN, z1 - ROOM_MIN)
		_wall_with_door(parent, false, cz, x0, x1, fy, sh, door_h, _rand_door(rng, x0, x1), mat)
		_subdivide(parent, x0, x1, z0, cz, fy, sh, mat, door_h, rng, depth + 1)
		_subdivide(parent, x0, x1, cz, z1, fy, sh, mat, door_h, rng, depth + 1)


# A full-span interior wall with a doorway gap + header. wall_is_x: wall lies along Z at
# x=fixed (spanning z in [span0,span1]); else along X at z=fixed (spanning that x range).
static func _wall_with_door(parent: Node3D, wall_is_x: bool, fixed: float, span0: float, span1: float, fy: float, sh: float, door_h: float, door_pos: float, mat: Material) -> void:
	var th: float = 0.18
	var d0: float = door_pos - DOOR_W * 0.5
	var d1: float = door_pos + DOOR_W * 0.5
	if d0 - span0 > 0.25:
		_seg(parent, wall_is_x, fixed, span0, d0, fy + sh * 0.5, sh, th, mat)
	if span1 - d1 > 0.25:
		_seg(parent, wall_is_x, fixed, d1, span1, fy + sh * 0.5, sh, th, mat)
	if sh - door_h > 0.2:
		_seg(parent, wall_is_x, fixed, d0, d1, fy + (door_h + sh) * 0.5, sh - door_h, th, mat)


# One solid wall segment spanning a..b (along Z if wall_is_x, else along X), at the fixed
# cross-coord, centred vertically at cy with height h.
static func _seg(parent: Node3D, wall_is_x: bool, fixed: float, a: float, b: float, cy: float, h: float, th: float, mat: Material) -> void:
	var mid: float = (a + b) * 0.5
	var length: float = b - a
	if wall_is_x:
		_wall(parent, Vector3(fixed, cy, mid), Vector3(th, h, length), mat)
	else:
		_wall(parent, Vector3(mid, cy, fixed), Vector3(length, h, th), mat)


static func _surface_mat(style: int, base: Color, line: Color, cell: Vector2, line_frac: float, rough: float, stripe: float = 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CITY_SHADER
	m.set_shader_parameter("style", style)
	m.set_shader_parameter("base_color", base)
	m.set_shader_parameter("line_color", line)
	m.set_shader_parameter("cell_size", cell)
	m.set_shader_parameter("line_frac", line_frac)
	m.set_shader_parameter("rough", rough)
	m.set_shader_parameter("stripe", stripe)
	return m


# Exterior cladding: brick, stone, or concrete (one per building, for between-building variety).
static func _exterior_material(rng: StableRng) -> ShaderMaterial:
	var pick: int = rng.randi_range(0, 2)
	if pick == 0:
		var base := Color.from_hsv(rng.randf_range(0.02, 0.07), rng.randf_range(0.45, 0.65), rng.randf_range(0.40, 0.55))
		return _surface_mat(0, base, Color(0.70, 0.68, 0.64), Vector2(rng.randf_range(0.42, 0.52), 0.16), 0.07, 0.9)
	elif pick == 1:
		var g: float = rng.randf_range(0.42, 0.60)
		return _surface_mat(1, Color(g, g * 0.99, g * 0.95), Color(0.32, 0.31, 0.30), Vector2(rng.randf_range(0.7, 1.0), rng.randf_range(0.35, 0.5)), 0.05, 0.92)
	var c: float = rng.randf_range(0.50, 0.66)
	return _surface_mat(2, Color(c, c, c * 0.98), Color(0.40, 0.40, 0.40), Vector2(1.0, 1.0), 0.0, 0.95)


# Interior floor finish: tile, carpet, wood planks, or concrete (one per building).
static func _floor_material(rng: StableRng) -> ShaderMaterial:
	var pick: int = rng.randi_range(0, 3)
	if pick == 0:
		var t: float = rng.randf_range(0.45, 0.70)
		return _surface_mat(5, Color(t, t, t * 1.02), Color(0.25, 0.25, 0.27), Vector2(rng.randf_range(0.5, 0.8), rng.randf_range(0.5, 0.8)), 0.05, 0.55)
	elif pick == 1:
		var carpet := Color.from_hsv(rng.randf_range(0.0, 1.0), rng.randf_range(0.25, 0.50), rng.randf_range(0.30, 0.50))
		return _surface_mat(6, carpet, carpet, Vector2(1.0, 1.0), 0.0, 1.0)
	elif pick == 2:
		var wood := Color.from_hsv(rng.randf_range(0.05, 0.10), rng.randf_range(0.45, 0.65), rng.randf_range(0.30, 0.50))
		return _surface_mat(3, wood, Color(0.12, 0.08, 0.05), Vector2(rng.randf_range(1.6, 2.4), rng.randf_range(0.18, 0.26)), 0.04, 0.7)
	var c2: float = rng.randf_range(0.32, 0.46)
	return _surface_mat(2, Color(c2, c2, c2 * 1.02), Color(0.30, 0.30, 0.30), Vector2(1.0, 1.0), 0.0, 0.9)


# Interior partition walls: painted plaster, ~40% with a faint wallpaper stripe.
# A grid-frame exterior wall: vertical mullions + horizontal bands (sill, floor
# lines, parapet) leaving real window openings between them, so light gets in and you
# can see out. `along` is the in-plane horizontal axis, `normal` points outward; the
# front wall passes door_w > 0 for a ground-level doorway gap. Wall rises y=0..top_y.
# Facade rhythm shared by exterior walls AND interior dividers, so a divider can land
# on a solid pier and never split a window. Fixed-width windows; solid piers (>= min)
# absorb the leftover wall, so a wider wall gets MORE windows, not wider ones.
static func _facade_layout(half_len: float, win_w: float) -> Dictionary:
	var length: float = half_len * 2.0
	var min_pier: float = 1.4
	var cols: int = maxi(1, int((length - min_pier) / (win_w + min_pier)))
	var pier_w: float = (length - float(cols) * win_w) / float(cols + 1)
	var piers: Array[float] = []
	var windows: Array[float] = []
	for i in range(cols + 1):
		piers.append(-half_len + float(i) * (pier_w + win_w) + pier_w * 0.5)
	for i in range(cols):
		windows.append(-half_len + float(i) * (pier_w + win_w) + pier_w + win_w * 0.5)
	return {"piers": piers, "windows": windows, "pier_w": pier_w}


static func _grid_wall(parent: Node3D, along: Vector3, normal: Vector3, center_xz: Vector3, half_len: float, top_y: float, mat: Material, door_w: float, sill_h: float, win_h: float, win_w: float) -> void:
	var th: float = 0.3
	var rows: int = maxi(1, int(top_y / STORY_H + 0.5))
	var lay: Dictionary = _facade_layout(half_len, win_w)
	var pier_w: float = lay["pier_w"]
	for t in lay["piers"]:
		var p: Vector3 = center_xz + along * t
		_wall(parent, Vector3(p.x, top_y * 0.5, p.z), along.abs() * pier_w + Vector3(0.0, top_y, 0.0) + normal.abs() * th, mat)
	# Door sits in the window cell nearest the wall centre (a real opening, no pier in it).
	var door_t: float = 0.0
	if door_w > 0.0:
		var best: float = 1e9
		for wc in lay["windows"]:
			if absf(wc) < best:
				best = absf(wc)
				door_t = wc
	# Per storey: a solid sill band below the windows and a spandrel band above, so the
	# openings are real punched windows (not full-height gaps). Ground sill carries the door.
	for f in range(rows):
		var fy: float = float(f) * STORY_H
		_grid_band(parent, along, normal, center_xz, half_len, fy + sill_h * 0.5, sill_h, th, mat, (win_w + 0.6 if (door_w > 0.0 and f == 0) else 0.0), door_t)
		var sp_bot: float = fy + sill_h + win_h
		var sp_top: float = float(f + 1) * STORY_H
		if sp_top - sp_bot > 0.15:
			_grid_band(parent, along, normal, center_xz, half_len, (sp_bot + sp_top) * 0.5, sp_top - sp_bot, th, mat, 0.0, 0.0)


static func _grid_band(parent: Node3D, along: Vector3, normal: Vector3, center_xz: Vector3, half_len: float, y: float, h: float, th: float, mat: Material, door_w: float, door_t: float = 0.0) -> void:
	var length: float = half_len * 2.0
	if door_w > 0.0:
		# Solid segment left of the door gap, then right of it (gap centred at door_t).
		var left_seg: float = (door_t - door_w * 0.5) - (-half_len)
		var right_seg: float = half_len - (door_t + door_w * 0.5)
		if left_seg > 0.3:
			var lp: Vector3 = center_xz + along * (-half_len + left_seg * 0.5)
			_wall(parent, Vector3(lp.x, y, lp.z), along.abs() * left_seg + Vector3(0.0, h, 0.0) + normal.abs() * th, mat)
		if right_seg > 0.3:
			var rp: Vector3 = center_xz + along * (half_len - right_seg * 0.5)
			_wall(parent, Vector3(rp.x, y, rp.z), along.abs() * right_seg + Vector3(0.0, h, 0.0) + normal.abs() * th, mat)
	else:
		_wall(parent, Vector3(center_xz.x, y, center_xz.z), along.abs() * length + Vector3(0.0, h, 0.0) + normal.abs() * th, mat)


static func _wall(parent: Node3D, center: Vector3, size: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)


static func _decor_box(parent: Node3D, center: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = center
	parent.add_child(mi)


# --- Parks (run wild) --------------------------------------------------------

static func _build_park(parent: Node3D, pos: Vector3, rng: StableRng, height_fn: Callable) -> void:
	var p := Node3D.new()
	p.position = pos
	parent.add_child(p)
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.32, 0.24, 0.16)
	trunk_mat.roughness = 1.0
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.18, 0.34, 0.16)
	leaf_mat.roughness = 1.0

	var count: int = rng.randi_range(7, 13)
	for k in range(count):
		var ox: float = rng.randf_range(-BLOCK * 0.45, BLOCK * 0.45)
		var oz: float = rng.randf_range(-BLOCK * 0.45, BLOCK * 0.45)
		var gy: float = float(height_fn.call(pos.x + ox, pos.z + oz)) - pos.y
		if rng.randf() < 0.6:
			var s: float = rng.randf_range(0.8, 1.5)
			var trunk := MeshInstance3D.new()
			var tm := CylinderMesh.new()
			tm.top_radius = 0.18 * s
			tm.bottom_radius = 0.26 * s
			tm.height = 2.2 * s
			trunk.mesh = tm
			trunk.material_override = trunk_mat
			trunk.position = Vector3(ox, gy + 1.1 * s, oz)
			p.add_child(trunk)
			var canopy := MeshInstance3D.new()
			var cm := SphereMesh.new()
			cm.radius = rng.randf_range(1.4, 2.4) * s
			cm.height = cm.radius * 1.8
			canopy.mesh = cm
			canopy.material_override = leaf_mat
			canopy.position = Vector3(ox, gy + 2.6 * s, oz)
			p.add_child(canopy)
		else:
			var bush := MeshInstance3D.new()
			var bm := SphereMesh.new()
			bm.radius = rng.randf_range(0.7, 1.3)
			bm.height = bm.radius * 1.4
			bush.mesh = bm
			bush.material_override = leaf_mat
			bush.position = Vector3(ox, gy + bm.radius * 0.5, oz)
			bush.scale = Vector3(1.0, rng.randf_range(0.7, 1.0), 1.0)
			p.add_child(bush)


# --- Rubble lots -------------------------------------------------------------

static func _build_rubble(parent: Node3D, pos: Vector3, rng: StableRng) -> void:
	var r := Node3D.new()
	r.position = pos
	parent.add_child(r)
	var mat := _concrete_material(rng)
	for k in range(rng.randi_range(4, 9)):
		var chunk := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(rng.randf_range(0.6, 2.2), rng.randf_range(0.4, 1.4), rng.randf_range(0.6, 2.2))
		chunk.mesh = cm
		chunk.material_override = mat
		chunk.position = Vector3(rng.randf_range(-BLOCK * 0.4, BLOCK * 0.4), cm.size.y * 0.35, rng.randf_range(-BLOCK * 0.4, BLOCK * 0.4))
		chunk.rotation_degrees = Vector3(rng.randf_range(-18.0, 18.0), rng.randf_range(0.0, 360.0), rng.randf_range(-18.0, 18.0))
		r.add_child(chunk)


# --- Materials & ground ------------------------------------------------------

static func _street_slab(parent: Node3D, center: Vector3, size: Vector3, mat: Material, height_fn: Callable) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = Vector3(center.x, float(height_fn.call(center.x, center.z)) + 0.02, center.z)
	parent.add_child(mi)


static func _concrete_material(rng: StableRng) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var tone: float = rng.randf_range(0.38, 0.56)
	var stain: float = rng.randf_range(-0.04, 0.02)
	mat.albedo_color = Color(tone, tone + stain, tone + stain * 0.5)
	mat.roughness = rng.randf_range(0.88, 1.0)
	return mat


static func _street_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.16, 0.18)
	mat.roughness = 1.0
	return mat


