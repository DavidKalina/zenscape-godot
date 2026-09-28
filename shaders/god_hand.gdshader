shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;
// The God Hand (scripts/god_hand.gd): a hand made of light. Translucent warm
// light, brighter at the silhouette where it is seen edge-on, a faint core,
// fading to nothing past the wrist. The game's version of the Blender stand-in
// light_material() in tools/blender_hand/god_hand.py: Layer Weight "Facing" at
// blend 0.45, mapped to [0.22, 1] as `rim`; alpha is rim times the vertex
// alpha (the wrist fade); emission is the vertex colour times rim * 1.1 + 0.25.
// The glTF COLOR_0 is stored linear (a float colour attribute, exported as
// is), so COLOR is used without a decode.
// This is the colour pass, and the second of two. The first,
// shaders/god_hand_depth.gdshader, lays the nearest shell's depth; this one
// draws on that depth and writes none, so each pixel takes exactly one layer
// of light whatever order the fingers' triangles come in, and a faded wrist
// leaves no depth for the display fog to read as solid.
// It is light: unshaded, receives no shadow, and must cast none (the node
// turns cast_shadow off; no sun shadow may compete with the handful's mark).
// Where it meets the land (a pinch, a press, a knuckle brushing a slope) it
// glows brighter and thins to nothing at the line where it goes in, so a
// touch reads as light on the ground rather than a hard cut: the ground's
// depth (copied before the transparent pass, so without the hand's own
// first pass) says how far behind each fragment the land is.

// Overall visibility (0..1): the fade in and out.
uniform float hand_opacity : hint_range(0.0, 1.0) = 1.0;
// Emission energy: 1 matches the stand-in; raise it at night or for a pulse.
uniform float hand_glow : hint_range(0.0, 4.0) = 1.0;
// Multiplies the vertex colour (the stand-in's warm #fff1d2).
uniform vec3 hand_tint : source_color = vec3(1.0);
// Brightness drift across the facets, as a share (0 is the still stand-in).
uniform float hand_shimmer : hint_range(0.0, 0.3) = 0.05;
// Extra glow where the hand touches the land, as a share.
uniform float hand_touch_glow : hint_range(0.0, 3.0) = 1.1;
uniform sampler2D hand_ground : hint_depth_texture, filter_nearest, repeat_disable;

// The stand-in's Layer Weight blend (0.45) as Blender's facing exponent,
// 2 * blend below one half, and its map range.
const float HAND_FACING_POWER = 0.9;
const float HAND_RIM_LOW = 0.22;
// Shimmer: cells per metre of the model, and its slow pace.
const float HAND_SHIMMER_SCALE = 7.0;
const float HAND_SHIMMER_PACE = 0.23;
// Metres in front of the land over which the light brightens, and over which
// it thins to nothing where it goes in.
const float HAND_TOUCH_REACH = 0.45;
const float HAND_TOUCH_SOFT = 0.1;

// One point per facet (the first vertex's), so the shimmer drifts facet by
// facet, as the faceted world is painted.
varying flat vec3 hand_facet;

float hand_hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float hand_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hand_hash(i), hand_hash(i + vec3(1, 0, 0)), f.x),
			mix(hand_hash(i + vec3(0, 1, 0)), hand_hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hand_hash(i + vec3(0, 0, 1)), hand_hash(i + vec3(1, 0, 1)), f.x),
			mix(hand_hash(i + vec3(0, 1, 1)), hand_hash(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

void vertex() {
	hand_facet = VERTEX;
}

void fragment() {
	float facing = 1.0 - pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), HAND_FACING_POWER);
	float rim = mix(HAND_RIM_LOW, 1.0, facing);
	float glow = rim * 1.1 + 0.25;
	if (hand_shimmer > 0.0) {
		float t = TIME * HAND_SHIMMER_PACE;
		vec3 p = hand_facet * HAND_SHIMMER_SCALE;
		// Two octaves slid against each other so the drift never repeats plainly.
		float n = hand_noise(p + vec3(t, t * 0.6, -t * 0.8)) * 0.65
			+ hand_noise(p * 2.1 - vec3(t * 0.7, -t, t * 0.5)) * 0.35;
		glow *= 1.0 + (n * 2.0 - 1.0) * hand_shimmer;
	}
	vec4 ground = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, textureLod(hand_ground, SCREEN_UV, 0.0).r, 1.0);
	float gap = VERTEX.z - ground.z / ground.w;
	float touch = 1.0 - smoothstep(0.0, HAND_TOUCH_REACH, gap);
	glow *= 1.0 + touch * touch * hand_touch_glow;
	ALBEDO = COLOR.rgb * hand_tint * glow * hand_glow;
	ALPHA = clamp((rim + touch * touch * 0.35) * COLOR.a * hand_opacity * smoothstep(0.0, HAND_TOUCH_SOFT, gap), 0.0, 1.0);
}
