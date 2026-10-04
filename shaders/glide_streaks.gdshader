shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// The air the glide flies through (scripts/glide_air.gd). The sky box never
// moves, so out in open air nothing would show the speed. These are faint
// motes held in a box that wraps round the eye: each keeps its place in the
// world until the eye leaves it behind, then turns up again ahead. At speed
// they draw out along the way the eye flies, into soft streaks.
// Instance custom data: a seed (x), a size (y) and a brightness (z).

// The wrapping box's edge, in metres.
uniform float box = 36.0;
// The eye's velocity, metres a second.
uniform vec3 velocity = vec3(0.0);
// How long a streak draws out per metre a second of speed, and how bright
// they are overall (0 hides them).
uniform float stretch = 0.05;
uniform float strength = 0.0;
uniform vec3 tint : source_color = vec3(1.0, 0.97, 0.9);

varying float opacity;
varying vec2 across;

void vertex() {
	vec3 eye = INV_VIEW_MATRIX[3].xyz;
	vec3 base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// Wrapped into the box round the eye.
	vec3 centre = eye + mod(base - eye + 0.5 * box, box) - 0.5 * box;
	vec3 to_eye = eye - centre;
	float away = length(to_eye);
	float speed = length(velocity);
	vec3 along = speed > 0.01 ? velocity / speed : INV_VIEW_MATRIX[1].xyz;
	vec3 side = cross(along, to_eye / max(away, 0.001));
	side = length(side) > 0.001 ? normalize(side) : INV_VIEW_MATRIX[0].xyz;
	float size = INSTANCE_CUSTOM.y;
	float length_ = size + speed * stretch;
	vec3 world = centre + side * VERTEX.x * size + along * VERTEX.y * length_;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	across = VERTEX.xy * 2.0;
	// Out of the way close to the eye and towards the box's edge.
	opacity = smoothstep(1.2, 4.0, away) * (1.0 - smoothstep(box * 0.3, box * 0.5, away)) * INSTANCE_CUSTOM.z * strength;
}

void fragment() {
	float soft = 1.0 - smoothstep(0.0, 1.0, length(across));
	ALBEDO = tint;
	ALPHA = soft * soft * opacity;
}
