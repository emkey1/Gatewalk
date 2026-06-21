extends RefCounted
class_name LandmarkFactory

const MapContext = preload("res://scripts/core/MapContext.gd")

# Sparse, procedurally-varied landscape oddities — ancient monuments and strange
# relics that turn up here and there to make the world feel old and lived-in.
# Each landmark is seeded individually (so no two are quite alike) and grounded to
# the lowest terrain under its footprint, so it sits on slopes instead of floating.

const LANDMARK_COUNT_BASE: int = 9

const KIND_MONOLITH: int = 0
const KIND_ARCH: int = 1
const KIND_CAIRN: int = 2
const KIND_RELIC: int = 3

# Footprint radius used both to ground a landmark and to reject too-lumpy spots.
const FOOTPRINT: float = 2.0

const LM_ADJECTIVES: Array[String] = [
	"Ancient", "Weathered", "Forgotten", "Silent", "Mossy", "Cracked", "Lonely",
	"Hollow", "Sunken", "Crooked", "Timeworn", "Shrouded", "Toppled", "Lichen-clad",
]


# Scatters landmarks under `parent` and returns their world-space XZ centers
# (y = 0) so callers can keep trees and other scatter clear of them.
static func scatter_landmarks(parent: Node3D, world_seed: int, density_level: int, context: MapContext) -> Array:
	return _scatter_internal(
		parent,
		world_seed,
		density_level,
		context.water_level,
		Callable(context, "height_at_world"),
		Callable(context, "river_distance"),
		context.world_half_size() * 0.85
	)


static func _scatter_internal(parent: Node3D, world_seed: int, density_level: int, water_level: float, height_fn: Callable, river_fn: Callable, half: float) -> Array:
	var rng := StableRng.new(StableRng.mix_string(world_seed, "landmarks"))
	var count: int = int(float(LANDMARK_COUNT_BASE) * _density_mult(density_level))

	var root := Node3D.new()
	root.name = "Landmarks"
	parent.add_child(root)

	var positions: Array = []
	var placed: int = 0
	var attempts: int = 0
	while placed < count and attempts < count * 12:
		attempts += 1
		var x: float = rng.randf_range(-half, half)
		var z: float = rng.randf_range(-half, half)
		var surf: float = float(height_fn.call(x, z))
		# Dry, open ground: above water, away from spawn, clear of the river.
		if surf < water_level + 1.0:
			continue
		if Vector2(x, z).length() < 24.0:
			continue
		if float(river_fn.call(x, z)) < 8.0:
			continue
		var ground: float = _ground_y(x, z, height_fn)
		if surf - ground > 2.2:
			continue  # too steep/lumpy to seat a monument here

		var kind: int = _pick_kind(rng)
		var lm_seed: int = rng.next_u32()
		var landmark: Node3D = _build_landmark(kind, lm_seed)
		landmark.position = Vector3(x, ground, z)
		landmark.rotation_degrees.y = rng.randf_range(0.0, 360.0)
		# Metadata so the cartographer's survey can catalog it into the Field Guide.
		landmark.set_meta("catalog_id", "landmark_" + str(placed))
		landmark.set_meta("survey_name", _landmark_name(lm_seed, kind))
		root.add_child(landmark)
		positions.append(Vector3(x, 0.0, z))
		placed += 1

	return positions


static func _density_mult(level: int) -> float:
	match level:
		0:
			return 0.4
		1:
			return 0.7
		_:
			return 1.0


# Lowest terrain under the footprint (with a small embed) so posts/bases sit on
# the ground rather than hovering above it on a slope.
static func _ground_y(x: float, z: float, height_fn: Callable) -> float:
	var lo: float = float(height_fn.call(x, z))
	for i in range(6):
		var a: float = TAU * float(i) / 6.0
		lo = minf(lo, float(height_fn.call(x + cos(a) * FOOTPRINT, z + sin(a) * FOOTPRINT)))
	return lo - 0.15


static func _landmark_name(seed: int, kind: int) -> String:
	var rng := StableRng.new(seed)
	var adjective: String = LM_ADJECTIVES[rng.randi_range(0, LM_ADJECTIVES.size() - 1)]
	var noun: String = "Landmark"
	match kind:
		KIND_MONOLITH:
			noun = "Monolith"
		KIND_ARCH:
			noun = "Archway"
		KIND_CAIRN:
			noun = "Cairn"
		KIND_RELIC:
			noun = "Relic"
	return adjective + " " + noun


static func _pick_kind(rng: StableRng) -> int:
	var r: float = rng.randf()
	if r < 0.30:
		return KIND_MONOLITH
	if r < 0.55:
		return KIND_ARCH
	if r < 0.82:
		return KIND_CAIRN
	return KIND_RELIC


static func _build_landmark(kind: int, seed: int) -> Node3D:
	match kind:
		KIND_ARCH:
			return _build_arch(seed)
		KIND_CAIRN:
			return _build_cairn(seed)
		KIND_RELIC:
			return _build_relic(seed)
		_:
			return _build_monolith(seed)


# Weathered grey stone with a touch of per-instance tone + moss variation.
static func _stone_material(rng: StableRng) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var tone: float = rng.randf_range(0.34, 0.50)
	var moss: float = rng.randf_range(0.0, 0.12)
	mat.albedo_color = Color(tone, tone + moss, tone * 0.92)
	mat.roughness = rng.randf_range(0.85, 1.0)
	return mat


# A solid box mesh under a StaticBody so the player collides with it (and the
# engine's loose-mesh auto-collision leaves it alone).
static func _solid_box(parent: Node3D, size: Vector3, mat: Material, local_pos: Vector3, rot: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = local_pos
	body.rotation_degrees = rot
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position.y = size.y * 0.5
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position.y = size.y * 0.5
	body.add_child(cs)
	parent.add_child(body)


# A tall leaning standing stone with a little tumbled rubble at its base.
static func _build_monolith(seed: int) -> Node3D:
	var rng := StableRng.new(seed)
	var root := Node3D.new()
	root.name = "Monolith"
	var mat := _stone_material(rng)

	var h: float = rng.randf_range(3.2, 6.5)
	var w: float = rng.randf_range(0.7, 1.4)
	var d: float = rng.randf_range(0.45, 0.9)
	var lean: float = rng.randf_range(-10.0, 10.0)
	_solid_box(root, Vector3(w, h, d), mat, Vector3.ZERO, Vector3(lean * 0.4, rng.randf_range(0.0, 360.0), lean))

	for i in range(rng.randi_range(2, 4)):
		var stone := MeshInstance3D.new()
		var sm := BoxMesh.new()
		var s: float = rng.randf_range(0.3, 0.7)
		sm.size = Vector3(s, s * rng.randf_range(0.5, 0.9), s)
		stone.mesh = sm
		stone.material_override = mat
		var ang: float = rng.randf_range(0.0, TAU)
		var rad: float = rng.randf_range(0.7, 1.3)
		stone.position = Vector3(cos(ang) * rad, sm.size.y * 0.4, sin(ang) * rad)
		stone.rotation_degrees = Vector3(rng.randf_range(-20.0, 20.0), rng.randf_range(0.0, 360.0), rng.randf_range(-20.0, 20.0))
		root.add_child(stone)
	return root


# A ruined freestanding archway: two posts (one often broken short) and, usually,
# a tilted lintel still bridging the top.
static func _build_arch(seed: int) -> Node3D:
	var rng := StableRng.new(seed)
	var root := Node3D.new()
	root.name = "RuinedArch"
	var mat := _stone_material(rng)

	var span: float = rng.randf_range(2.4, 4.0)
	var post_h: float = rng.randf_range(2.6, 4.4)
	var post_w: float = rng.randf_range(0.5, 0.8)
	# One side may have collapsed to a stump.
	var left_h: float = post_h * rng.randf_range(0.55, 1.0)

	_solid_box(root, Vector3(post_w, left_h, post_w * rng.randf_range(0.9, 1.2)), mat,
		Vector3(-span * 0.5, 0.0, 0.0), Vector3(rng.randf_range(-4.0, 4.0), 0.0, rng.randf_range(-4.0, 4.0)))
	_solid_box(root, Vector3(post_w, post_h, post_w * rng.randf_range(0.9, 1.2)), mat,
		Vector3(span * 0.5, 0.0, 0.0), Vector3(rng.randf_range(-4.0, 4.0), 0.0, rng.randf_range(-4.0, 4.0)))

	# Lintel survives only if the broken post is still tallish.
	if left_h > post_h * 0.78 and rng.randf() < 0.7:
		var lintel := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(span * rng.randf_range(0.85, 1.15), post_w * 0.9, post_w * 1.1)
		lintel.mesh = lm
		lintel.material_override = mat
		lintel.position = Vector3(rng.randf_range(-0.3, 0.3), min(left_h, post_h) - post_w * 0.45, 0.0)
		lintel.rotation_degrees = Vector3(0.0, 0.0, rng.randf_range(-10.0, 10.0))
		root.add_child(lintel)
	return root


# A balanced pile of rounded stones, shrinking toward the top.
static func _build_cairn(seed: int) -> Node3D:
	var rng := StableRng.new(seed)
	var root := Node3D.new()
	root.name = "Cairn"
	var mat := _stone_material(rng)

	var n: int = rng.randi_range(4, 7)
	var y: float = 0.0
	var r: float = rng.randf_range(0.5, 0.8)
	for i in range(n):
		var stone := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * rng.randf_range(1.4, 1.9)
		stone.mesh = sm
		stone.material_override = mat
		stone.position = Vector3(rng.randf_range(-0.12, 0.12), y + sm.height * 0.4, rng.randf_range(-0.12, 0.12))
		stone.scale = Vector3(1.0, rng.randf_range(0.7, 0.95), 1.0)
		stone.rotation_degrees.y = rng.randf_range(0.0, 360.0)
		root.add_child(stone)
		y += sm.height * 0.55
		r *= rng.randf_range(0.72, 0.86)
	return root


# A strange, half-buried geometric relic — polished, alien, faintly humming with
# light. The odd thing you stumble on and wonder who left it.
static func _build_relic(seed: int) -> Node3D:
	var rng := StableRng.new(seed)
	var root := Node3D.new()
	root.name = "BuriedRelic"

	var glow := Color.from_hsv(rng.randf(), 0.55, 0.95)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.13, 0.16)
	mat.metallic = 0.6
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = glow
	mat.emission_energy_multiplier = rng.randf_range(0.6, 1.4)

	var size: float = rng.randf_range(1.6, 2.8)
	var is_shard: bool = rng.randf() < 0.5
	var mesh: Mesh
	var top_h: float
	if is_shard:
		var pm := PrismMesh.new()
		top_h = size * rng.randf_range(1.3, 1.9)
		pm.size = Vector3(size, top_h, size)
		mesh = pm
	else:
		var sm := SphereMesh.new()
		top_h = size
		sm.radius = size * 0.5
		sm.height = size
		mesh = sm
	var sink: float = top_h * rng.randf_range(0.35, 0.6)
	var tilt := Vector3(rng.randf_range(-25.0, 25.0), rng.randf_range(0.0, 360.0), rng.randf_range(-25.0, 25.0))

	var body := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position.y = top_h * 0.5 - sink
	mi.rotation_degrees = tilt
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size, top_h, size)
	cs.shape = shape
	cs.position.y = top_h * 0.5 - sink
	cs.rotation_degrees = tilt
	body.add_child(cs)
	root.add_child(body)

	# Cheap, shadowless glow so it casts a little colored light on the ground at night.
	var light := OmniLight3D.new()
	light.light_color = glow
	light.light_energy = rng.randf_range(0.6, 1.2)
	light.omni_range = size * 2.6
	light.shadow_enabled = false
	light.position.y = maxf(0.4, top_h * 0.4 - sink + 0.3)
	root.add_child(light)
	return root
