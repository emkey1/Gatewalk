extends RefCounted
class_name WaterPlaneFactory


static func create_water(
	parent: Node3D,
	map_type: String,
	graphics_level: int,
	grid_size: int,
	cell_size: float,
	water_level: float,
) -> void:
	if map_type == "moon" or map_type == "cave":
		return
	if map_type == "gate_room" or map_type == "map_nexus":
		return

	var water_size: float = float(_effective_grid_size(map_type, grid_size, 1)) * cell_size * 0.94

	var water := MeshInstance3D.new()
	water.name = "RiverAndLakeWater"
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(water_size, water_size)
	if graphics_level <= 0:
		water_mesh.subdivide_width = 32
		water_mesh.subdivide_depth = 32
	elif graphics_level == 1:
		water_mesh.subdivide_width = 64
		water_mesh.subdivide_depth = 64
	else:
		water_mesh.subdivide_width = 128
		water_mesh.subdivide_depth = 128
	water.mesh = water_mesh
	water.position.y = water_level

	var mat := ShaderMaterial.new()
	mat.shader = _water_shader()
	if map_type == "water":
		mat.set_shader_parameter("shallow_color", Color(0.08, 0.30, 0.50, 0.28))
		mat.set_shader_parameter("deep_color", Color(0.02, 0.13, 0.30, 0.38))
		mat.set_shader_parameter("sky_tint", Color(0.32, 0.54, 0.82))
		mat.set_shader_parameter("wave_strength", 0.075 if graphics_level >= 2 else 0.045)
		mat.set_shader_parameter("wave_speed", 0.90 if graphics_level >= 2 else 0.65)
		mat.set_shader_parameter("wave_scale", 3.1)
		mat.set_shader_parameter("normal_strength", 1.05 if graphics_level >= 2 else 0.75)
		mat.set_shader_parameter("sheen_strength", 0.20)
		mat.set_shader_parameter("alpha_boost", 0.02)
	else:
		mat.set_shader_parameter("shallow_color", Color(0.08, 0.28, 0.44, 0.14))
		mat.set_shader_parameter("deep_color", Color(0.02, 0.14, 0.28, 0.22))
		mat.set_shader_parameter("sky_tint", Color(0.36, 0.60, 0.88))
		mat.set_shader_parameter("wave_strength", 0.045 if graphics_level >= 2 else 0.025)
		mat.set_shader_parameter("wave_speed", 0.60 if graphics_level >= 2 else 0.40)
		mat.set_shader_parameter("wave_scale", 4.4)
		mat.set_shader_parameter("normal_strength", 0.85 if graphics_level >= 2 else 0.60)
		mat.set_shader_parameter("sheen_strength", 0.16)
		mat.set_shader_parameter("alpha_boost", 0.0)

	water.material_override = mat
	parent.add_child(water)

	var water_collision := StaticBody3D.new()
	water_collision.name = "WaterCollision"
	water_collision.collision_layer = 4
	water_collision.collision_mask = 0

	var water_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(water_size, 0.2, water_size)
	water_shape.shape = box

	water_collision.add_child(water_shape)
	water_collision.position.y = water_level
	parent.add_child(water_collision)


static func _effective_grid_size(map_type: String, grid_size: int, moon_grid_scale: int) -> int:
	if map_type == "moon":
		return grid_size * moon_grid_scale
	return grid_size


static func _water_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;

render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.15, 0.40, 0.50, 0.34);
uniform vec4 deep_color : source_color = vec4(0.05, 0.15, 0.30, 0.44);
uniform vec3 sky_tint : source_color = vec3(0.34, 0.56, 0.82);
uniform float wave_strength : hint_range(0.0, 1.0) = 0.08;
uniform float wave_speed : hint_range(0.0, 2.0) = 0.12;
uniform float wave_scale : hint_range(0.1, 20.0) = 4.0;
uniform float normal_strength : hint_range(0.0, 5.0) = 0.85;
uniform float sheen_strength : hint_range(0.0, 1.0) = 0.32;
uniform float alpha_boost : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_normal;
varying vec3 v_world_position;

float wave_value(vec2 p, float t) {
	float a = sin(p.x * wave_scale + t * wave_speed);
	float b = sin(p.y * wave_scale * 1.37 + t * wave_speed * 1.11);
	float c = sin((p.x + p.y) * wave_scale * 0.71 + t * wave_speed * 0.63);
	return (a + b + c * 0.65) / 2.65;
}

void vertex() {
	float t = TIME;
	vec2 p = VERTEX.xz * 0.08;
	float h = wave_value(p, t) * wave_strength;
	VERTEX.y += h;

	float e = 0.08;
	float hx = wave_value(p + vec2(e, 0.0), t) * wave_strength;
	float hz = wave_value(p + vec2(0.0, e), t) * wave_strength;
	vec3 local_normal = normalize(vec3(
		-(hx - h) * normal_strength,
		1.0,
		-(hz - h) * normal_strength
	));
	NORMAL = local_normal;
	v_normal = normalize((MODEL_MATRIX * vec4(local_normal, 0.0)).xyz);
	v_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (!FRONT_FACING) {
		ALBEDO = vec3(0.02, 0.05, 0.08);
		ALPHA = 0.0;
		ROUGHNESS = 1.0;
		METALLIC = 0.0;
		SPECULAR = 0.0;
	} else {
		float face = 1.0;
		vec3 n = normalize(v_normal);
		vec3 view_dir = normalize(CAMERA_POSITION_WORLD - v_world_position);
		float fresnel = pow(1.0 - clamp(dot(n, view_dir), 0.0, 1.0), 3.0);
		float ripple = sin(v_world_position.x * 0.32 + TIME * wave_speed * 1.4)
			* sin(v_world_position.z * 0.25 - TIME * wave_speed * 1.0);
		ripple = ripple * 0.5 + 0.5;

		vec3 base_color = mix(shallow_color.rgb, deep_color.rgb, 0.45);
		base_color += vec3(ripple * 0.018);
		float sheen = clamp(fresnel * sheen_strength * face, 0.0, 0.28);
		ALBEDO = mix(base_color, sky_tint, sheen);
		ALPHA = clamp((mix(shallow_color.a, deep_color.a, 0.45) + fresnel * 0.03 + alpha_boost) * face, 0.03, 0.24);
		ROUGHNESS = 0.18;
		METALLIC = 0.0;
		SPECULAR = 0.35;
	}
}
"""
	return shader
