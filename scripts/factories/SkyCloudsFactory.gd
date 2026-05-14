extends RefCounted
class_name SkyCloudsFactory


static func create_clouds(parent: Node3D, map_type: String, graphics_level: int, world_seed: int) -> void:
	if map_type == "moon" or map_type == "cave":
		return
	if graphics_level == 0:
		return

	var cloud_root := Node3D.new()
	cloud_root.name = "SkyClouds"

	var cloud_shader := Shader.new()
	cloud_shader.code = """
shader_type spatial;

render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform float time_offset : hint_range(0.0, 1000.0) = 0.0;
uniform float time_scale : hint_range(0.0, 1.0) = 0.025;
uniform float density : hint_range(0.0, 1.0) = 0.38;
uniform float coverage : hint_range(0.0, 1.0) = 0.55;
uniform float softness : hint_range(0.0, 1.0) = 0.25;
uniform float alpha_scale : hint_range(0.0, 1.0) = 0.4;
uniform vec3 cloud_color : source_color = vec3(1.0, 0.98, 0.92);
uniform vec3 cloud_shadow_color : source_color = vec3(0.70, 0.74, 0.78);

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		v += amp * noise2(p);
		p = p * 2.05 + vec2(13.2, 7.1);
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	float t = TIME * time_scale + time_offset;
	vec2 p = UV * 5.0;
	p += vec2(t * 0.35, t * 0.10);
	float large = fbm(p);
	float detail = fbm(p * 2.7 + vec2(31.7, 19.4));
	float cloud = large * 0.75 + detail * 0.25;
	float threshold = 1.0 - coverage;
	float alpha = smoothstep(threshold, threshold + softness, cloud) * density;
	vec2 centered = UV * 2.0 - 1.0;
	float edge = max(abs(centered.x), abs(centered.y));
	alpha *= 1.0 - smoothstep(0.72, 1.0, edge);
	vec3 color = mix(cloud_shadow_color, cloud_color, clamp(cloud + 0.12, 0.0, 1.0));
	ALBEDO = color;
	ALPHA = alpha * alpha_scale;
}
"""

	var near_clouds := MeshInstance3D.new()
	near_clouds.name = "CloudLayerNear"
	var near_mesh := PlaneMesh.new()
	near_mesh.size = Vector2(950.0, 950.0)
	near_clouds.mesh = near_mesh
	near_clouds.position = Vector3(0.0, 130.0, 0.0)

	var mat := ShaderMaterial.new()
	mat.shader = cloud_shader
	mat.set_shader_parameter("time_offset", float(world_seed % 1000))
	mat.set_shader_parameter("time_scale", 0.025)
	mat.set_shader_parameter("density", 0.22 if graphics_level >= 2 else 0.16)
	mat.set_shader_parameter("coverage", 0.44)
	mat.set_shader_parameter("softness", 0.35)
	mat.set_shader_parameter("alpha_scale", 0.55)
	mat.set_shader_parameter("cloud_color", Color(1.0, 0.98, 0.92))
	mat.set_shader_parameter("cloud_shadow_color", Color(0.82, 0.84, 0.88))
	near_clouds.material_override = mat
	cloud_root.add_child(near_clouds)

	var far_clouds := MeshInstance3D.new()
	far_clouds.name = "CloudLayerFar"
	var far_mesh := PlaneMesh.new()
	far_mesh.size = Vector2(1450.0, 1450.0)
	far_clouds.mesh = far_mesh
	far_clouds.position = Vector3(0.0, 210.0, 0.0)

	var mat2 := ShaderMaterial.new()
	mat2.shader = cloud_shader
	mat2.set_shader_parameter("time_offset", float(world_seed % 1000) + 250.0)
	mat2.set_shader_parameter("time_scale", 0.014)
	mat2.set_shader_parameter("density", 0.10 if graphics_level >= 2 else 0.07)
	mat2.set_shader_parameter("coverage", 0.48)
	mat2.set_shader_parameter("softness", 0.45)
	mat2.set_shader_parameter("alpha_scale", 0.40)
	mat2.set_shader_parameter("cloud_color", Color(1.0, 0.98, 0.94))
	mat2.set_shader_parameter("cloud_shadow_color", Color(0.84, 0.86, 0.90))
	far_clouds.material_override = mat2
	cloud_root.add_child(far_clouds)

	parent.add_child(cloud_root)
