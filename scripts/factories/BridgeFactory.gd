extends RefCounted
class_name BridgeFactory

const MapContext = preload("res://scripts/core/MapContext.gd")

# A weathered stone bridge thrown across the river. We locate the river channel
# (where river_distance bottoms out), find the dry banks on either side, then build
# a deck spanning bank-to-bank above the water, with piers down to the riverbed and
# low railings. The deck is solid so the player can actually walk across.
# Intended for the overworld, where the river is genuinely carved below the water.


static func scatter_bridges(parent: Node3D, world_seed: int, density_level: int, context: MapContext) -> Array:
	return _scatter_internal(
		parent,
		world_seed,
		density_level,
		context.water_level,
		Callable(context, "height_at_world"),
		Callable(context, "river_distance"),
		context.world_half_size()
	)


static func _scatter_internal(parent: Node3D, world_seed: int, density_level: int, water_level: float, height_fn: Callable, river_fn: Callable, half: float) -> Array:
	var rng := StableRng.new(StableRng.mix_string(world_seed, "bridges"))
	var root := Node3D.new()
	root.name = "Bridges"
	parent.add_child(root)

	var positions: Array = []
	var want: int = 1
	if density_level >= 2 and rng.randf() < 0.6:
		want = 2

	var placed: int = 0
	var attempts: int = 0
	while placed < want and attempts < 16:
		attempts += 1
		var x: float = rng.randf_range(-half * 0.68, half * 0.68)
		var zc: float = _river_center_z(x, river_fn, half)
		if is_nan(zc):
			continue
		# Don't crowd two bridges together.
		var too_close: bool = false
		for p in positions:
			if absf(p.x - x) < 30.0:
				too_close = true
		if too_close:
			continue
		var bridge: Node3D = _build_bridge(rng, x, zc, water_level, height_fn)
		if bridge == null:
			continue
		root.add_child(bridge)
		positions.append(Vector3(x, 0.0, zc))
		placed += 1

	return positions


# Scan across z at this x and return the river centerline, or NAN if there's no
# clear channel here.
static func _river_center_z(x: float, river_fn: Callable, half: float) -> float:
	var best_z: float = 0.0
	var best_d: float = 1e9
	var steps: int = 140
	for i in range(steps):
		var z: float = -half + (2.0 * half) * float(i) / float(steps - 1)
		var d: float = float(river_fn.call(x, z))
		if d < best_d:
			best_d = d
			best_z = z
	if best_d > 3.0:
		return NAN
	return best_z


static func _build_bridge(rng: StableRng, x: float, zc: float, water_level: float, height_fn: Callable) -> Node3D:
	# Walk outward from the channel to the first dry bank on each side.
	var z_neg: float = zc
	for i in range(70):
		z_neg -= 0.5
		if float(height_fn.call(x, z_neg)) >= water_level + 0.6:
			break
	var z_pos: float = zc
	for i in range(70):
		z_pos += 0.5
		if float(height_fn.call(x, z_pos)) >= water_level + 0.6:
			break

	var span: float = z_pos - z_neg
	if span < 6.0 or span > 42.0:
		return null  # no sensible crossing here

	var bank_neg: float = float(height_fn.call(x, z_neg))
	var bank_pos: float = float(height_fn.call(x, z_pos))
	var mid_z: float = (z_neg + z_pos) * 0.5
	var width: float = rng.randf_range(2.8, 4.0)
	var deck_top: float = maxf(bank_neg, bank_pos) + rng.randf_range(0.25, 0.5)
	var deck_thick: float = 0.32
	var deck_center: float = deck_top - deck_thick * 0.5
	var deck_bottom: float = deck_center - deck_thick * 0.5

	var mat := _stone_material(rng)
	var root := Node3D.new()
	root.name = "StoneBridge"

	# Deck — the walkable span.
	_solid_box_at(root, Vector3(width, deck_thick, span + 0.6), mat, Vector3(x, deck_center, mid_z), Vector3.ZERO)

	# Abutments: fill the gap from each bank up to the deck so the ends sit grounded.
	_abutment(root, mat, x, z_neg, bank_neg, deck_bottom, width)
	_abutment(root, mat, x, z_pos, bank_pos, deck_bottom, width)

	# Piers down to the riverbed for support (decorative; under the deck/water).
	for frac in [0.32, 0.68]:
		var pz: float = z_neg + span * frac
		var bed: float = float(height_fn.call(x, pz))
		var pier_h: float = deck_bottom - bed
		if pier_h > 0.4:
			_decor_box(root, Vector3(width * 0.5, pier_h, 1.2), mat, Vector3(x, bed + pier_h * 0.5, pz))

	# Low railings along both edges (solid, to keep the player on the deck).
	var rail_h: float = 0.6
	for side in [-1.0, 1.0]:
		var rx: float = x + side * (width * 0.5 - 0.12)
		_solid_box_at(root, Vector3(0.2, rail_h, span + 0.6), mat, Vector3(rx, deck_top + rail_h * 0.5, mid_z), Vector3.ZERO)

	return root


static func _abutment(parent: Node3D, mat: Material, x: float, z: float, bank_y: float, deck_bottom: float, width: float) -> void:
	var h: float = deck_bottom - bank_y + 0.6  # embed slightly into the bank
	if h < 0.3:
		h = 0.3
	var center_y: float = deck_bottom - h * 0.5
	_solid_box_at(parent, Vector3(width, h, 1.6), mat, Vector3(x, center_y, z), Vector3.ZERO)


static func _stone_material(rng: StableRng) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var tone: float = rng.randf_range(0.36, 0.5)
	var moss: float = rng.randf_range(0.0, 0.1)
	mat.albedo_color = Color(tone, tone + moss, tone * 0.9)
	mat.roughness = rng.randf_range(0.85, 1.0)
	return mat


static func _solid_box_at(parent: Node3D, size: Vector3, mat: Material, center: Vector3, rot_deg: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	body.rotation_degrees = rot_deg
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


static func _decor_box(parent: Node3D, size: Vector3, mat: Material, center: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = center
	parent.add_child(mi)
