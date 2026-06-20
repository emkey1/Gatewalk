extends RefCounted
class_name RoadFactory

const MapContext = preload("res://scripts/core/MapContext.gd")
const MultiMeshScatter = preload("res://scripts/factories/MultiMeshScatter.gd")

# Remnants of ancient roads — meandering paths of broken paving slabs that hug the
# terrain. Each tile is grounded to its own spot, some are missing, and some are
# tilted/sunk, so the road reads as long-abandoned rather than freshly laid.
# All tiles render in a single MultiMesh draw call (no collision; they sit flush
# with the ground the player already walks on).

const SEGMENTS_BASE: int = 2


static func scatter_roads(parent: Node3D, world_seed: int, density_level: int, context: MapContext) -> void:
	_scatter_internal(
		parent,
		world_seed,
		density_level,
		context.water_level,
		Callable(context, "height_at_world"),
		context.world_half_size() * 0.82
	)


static func _scatter_internal(parent: Node3D, world_seed: int, density_level: int, water_level: float, height_fn: Callable, half: float) -> void:
	var rng := StableRng.new(StableRng.mix_string(world_seed, "roads"))
	var segments: int = SEGMENTS_BASE + (1 if density_level >= 2 else 0)

	var transforms: Array = []
	var colors: Array = []
	for s in range(segments):
		_build_segment(rng, water_level, height_fn, half, transforms, colors)

	if transforms.is_empty():
		return

	var slab := BoxMesh.new()
	slab.size = Vector3(1.5, 0.18, 1.25)
	var mat := MultiMeshScatter.instance_color_material(1.0)
	MultiMeshScatter.build(parent, "RuinedRoad", slab, mat, transforms, colors)


static func _build_segment(rng: StableRng, water_level: float, height_fn: Callable, half: float, transforms: Array, colors: Array) -> void:
	var x: float = rng.randf_range(-half, half)
	var z: float = rng.randf_range(-half, half)
	var heading: float = rng.randf_range(0.0, TAU)
	var spacing: float = 1.15
	var tiles: int = rng.randi_range(24, 44)

	for i in range(tiles):
		# Gentle meander.
		heading += rng.randf_range(-0.12, 0.12)
		x += cos(heading) * spacing
		z += sin(heading) * spacing
		if absf(x) > half or absf(z) > half:
			break
		var ty: float = float(height_fn.call(x, z))
		if ty < water_level + 0.2:
			continue  # road washes out over water
		if rng.randf() < 0.22:
			continue  # a missing slab

		var dir := Vector3(cos(heading), 0.0, sin(heading))
		var b := Basis.looking_at(dir, Vector3.UP)
		# Tilt about the road's width axis for an uneven, settled look.
		b = b.rotated(b.x.normalized(), deg_to_rad(rng.randf_range(-7.0, 7.0)))
		b = b.scaled(Vector3(rng.randf_range(0.82, 1.12), 1.0, rng.randf_range(0.9, 1.1)))
		transforms.append(Transform3D(b, Vector3(x, ty + 0.04, z)))
		var g: float = rng.randf_range(0.32, 0.48)
		colors.append(Color(g, g * 1.02, g * 0.94))
