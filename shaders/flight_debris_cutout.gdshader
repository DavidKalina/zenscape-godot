shader_type spatial;
// The cut-outs off a knocked tree (scripts/endless/flight_debris.gd): leaves,
// needle sprigs, wood chips. A particle billboard, tinted by its particle's
// colour, lit as if it faced mostly up (like the canopy it came from) so it
// doesn't go black with the sun behind it; sun through it from behind
// (`backlight`); dithered out near the eye.
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D cutout : source_color, filter_linear_mipmap;
uniform vec3 backlight_colour : source_color = vec3(0.0);
// How far toward up the light's normal leans (0 faces the eye).
uniform float lean_up = 0.65;
// Gone nearer than x m, whole past y.
uniform vec2 near = vec2(0.0, 0.0);

varying vec3 up_view;

void vertex() {
	mat4 world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	world = world * mat4(vec4(cos(INSTANCE_CUSTOM.x), -sin(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(sin(INSTANCE_CUSTOM.x), cos(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * world;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	up_view = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
}

void fragment() {
	vec4 t = texture(cutout, UV);
	ALBEDO = t.rgb * COLOR.rgb;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	NORMAL = normalize(mix(FRONT_FACING ? NORMAL : -NORMAL, up_view, lean_up));
	BACKLIGHT = backlight_colour;
	if (near.y > 0.0) {
		const vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
		float fade = smoothstep(near.x, near.y, length(VERTEX));
		if (fade < 0.001 || fade < fract(magic.z * fract(dot(FRAGCOORD.xy, magic.xy)))) {
			discard;
		}
	}
}
