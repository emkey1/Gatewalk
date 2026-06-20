extends RefCounted
class_name MultiMeshScatter

# Renders many identical-mesh instances in a single draw call via MultiMesh, instead
# of one MeshInstance3D node per object. Used to collapse dense procedural scatter
# (rocks, flowers, crystals, trees) from thousands of draw calls to a handful.
#
# Positions still come from StableRng in each factory; this only changes the render
# container, so generation stays deterministic.

# transforms: Array[Transform3D] in the space of `parent` (factories pass world-space
# transforms and parent at the generated-root origin). colors: optional Array[Color]
# (same length as transforms) for per-instance albedo — the material must enable
# vertex_color_use_as_albedo for it to show.
static func build(parent: Node3D, node_name: String, mesh: Mesh, material: Material, transforms: Array, colors: Array = []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var use_colors: bool = not colors.is_empty()
	mm.use_colors = use_colors
	mm.mesh = mesh
	# instance_count must be set after format/colors/mesh; setters come after.
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
		if use_colors:
			mm.set_instance_color(i, colors[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	if material != null:
		mmi.material_override = material
	parent.add_child(mmi)
	return mmi


# Convenience: a StandardMaterial3D set up to read per-instance MultiMesh colors as
# albedo. roughness defaults high (matte) for terrain props.
static func instance_color_material(roughness: float = 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true
	mat.roughness = roughness
	return mat
