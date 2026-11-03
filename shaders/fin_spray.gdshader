shader_type spatial;
// The fine spray off a swimming fish's fin (scripts/endless/swim_fish.gd): one
// droplet per MultiMesh instance, its place the instance's origin, its velocity
// the basis's first column, INSTANCE_CUSTOM.x its size (m) and .y how much is
// left of it (1 to 0). Each a soft dot drawn along its flight, lit as the
// leaping fish's splash droplets are (shaders/wake_splash.gdshader).
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, specular_disabled, world_vertex_coords, shadows_disabled;

global uniform vec3 zs_hemi_sky;
global uniform float zs_hemi_energy;

uniform vec3 tint : source_color = vec3(0.86, 0.92, 0.96);
uniform float sky_fill = 1.3;

varying float fade;

void vertex() {
	vec3 at = MODEL_MATRIX[3].xyz;
	vec3 moving = MODEL_MATRIX[0].xyz;
	float size = INSTANCE_CUSTOM.x;
	fade = INSTANCE_CUSTOM.y;
	vec2 q = UV * 2.0 - 1.0;
	vec3 eye = INV_VIEW_MATRIX[3].xyz;
	vec3 look = normalize(at - eye);
	float far = distance(at, eye);
	// Never under a pixel or so far off.
	float half_size = max(size * 0.5 * sqrt(fade), far * 0.0011);
	// Drawn along its flight against the air, which is how the eye takes a drop
	// that fast.
	float speed = length(moving);
	vec3 along = moving / max(speed, 0.01);
	vec3 across = cross(along, look);
	float wide = length(across);
	across = wide > 0.01 ? across / wide : INV_VIEW_MATRIX[0].xyz;
	float streak = 1.0 + min(speed, 12.0) * 0.25 * wide;
	VERTEX = at + across * q.x * half_size + along * q.y * half_size * streak;
	NORMAL = -look;
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	ALPHA = (1.0 - smoothstep(0.4, 1.0, length(q))) * clamp(fade * 1.6, 0.0, 1.0) * 0.85;
	ALBEDO = tint;
	EMISSION = tint * zs_hemi_sky * zs_hemi_energy / PI * sky_fill;
}
