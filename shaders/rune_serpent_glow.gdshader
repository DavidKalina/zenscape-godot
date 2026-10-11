shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never, fog_disabled;
// The rune serpent's soft lights (scripts/rune_serpent.gd): a haze of light
// round each eye, as the lodestone's hum (shaders/lodestone_glow.gdshader)
// is round the stone: a quad facing the eye, carried by the head's bone.
// All four corners stand at the light's middle; UV is the corner (0..1),
// UV2 its radius (m) and how far it is drawn toward the eye (m), so it
// shows in front of the stone it sits on. No fog (an added colour would
// glow through it): it fades with distance instead, out by `reach` m.
uniform vec3 colour : source_color = vec3(1.0, 0.8, 0.5);
uniform float strength = 1.0;
uniform float reach = 900.0;

varying vec2 corner;
varying float far_fade;

void vertex() {
	corner = UV * 2.0 - 1.0;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 to_cam = CAMERA_POSITION_WORLD - world;
	float dist = length(to_cam);
	to_cam /= max(dist, 1e-4);
	world += to_cam * UV2.y;
	world += (INV_VIEW_MATRIX[0].xyz * corner.x + INV_VIEW_MATRIX[1].xyz * corner.y) * UV2.x;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	far_fade = 1.0 - smoothstep(reach * 0.4, reach, dist);
}

void fragment() {
	float r = length(corner);
	float g = exp(-r * r * 4.5) * (1.0 - smoothstep(0.75, 1.0, r));
	ALBEDO = colour * g * strength * far_fade;
}
