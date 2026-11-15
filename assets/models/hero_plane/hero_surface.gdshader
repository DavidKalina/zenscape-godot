shader_type spatial;
// Written by art/blender/hero_plane/hero_plane_build.py. Lit as the world is: no
// ambient, the sky's hemisphere added as emission (shaders/folk_surface.
// gdshaderinc). The albedo is the plane's own paint; the livery tints by
// slot/default through the mask (R body, G trim, B wing, A dark), so stains and
// wear stay and bared metal doesn't take the paint. COLOR is baked darkness.
render_mode diffuse_lambert, specular_schlick_ggx;
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;
global uniform vec3 zs_key_direction;
global uniform float zs_daylight;
global uniform float zs_exposure;
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D mask_tex : hint_default_black, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 paint_body : source_color = vec3(0.725, 0.345, 0.231);
uniform vec3 paint_trim : source_color = vec3(0.184, 0.4, 0.439);
uniform vec3 paint_wing : source_color = vec3(0.925, 0.886, 0.784);
uniform vec3 paint_dark : source_color = vec3(0.184, 0.29, 0.31);
const vec3 BASE_BODY = vec3(0.485, 0.0976, 0.0437);
const vec3 BASE_TRIM = vec3(0.0284, 0.133, 0.162);
const vec3 BASE_WING = vec3(0.838, 0.76, 0.578);
const vec3 BASE_DARK = vec3(0.0284, 0.0685, 0.0781);
uniform float normal_depth = 1.0;
uniform float fill = 2.2;
uniform float rim = 0.3;
uniform float bounce = 4.0;
// The side turned from the sun. The world's fill is about a twentieth of the
// sun in the red and blue besides, so a saturated paint in it goes to black: a
// near-neutral light scaled off the sky's own, so moods and night reach it,
// strongest away from the sun and a little of it on the lit side, so cast
// shadows lift too without washing the lit paint out.
uniform float shade_lift = 3.0;
// By night the lift and the sky's fill give way to these shares: the land goes
// dark then, the fill does nearly all the plane's lighting (hardly the moon),
// and in full they read as lit from within.
uniform float shade_night = 0.1;
uniform float fill_night = 0.6;
// How far a roof shuts the sky out (PlaneFigure `_cover`), 0 open air to 1 under
// stone, and how much of the sky's light it takes away then.
uniform float roof = 0.0;
uniform float roof_dim = 0.82;
uniform float shade_lit = 0.3;
uniform float shade_neutral = 0.7;
uniform float coat_roughness = 0.08;
// set_wear: 0 new; faded, dusty and dull at 1, as the old paint did.
uniform float wear : hint_range(0.0, 1.0) = 0.0;
uniform vec3 wear_dust : source_color = vec3(0.71, 0.65, 0.55);
// A skin's finish (scripts/endless/shop_stock.gd FINISH), on the painted parts
// only (the mask), so brass, cloth and bared metal keep their own: the paint's
// roughness and clearcoat (below 0 the atlas's own), how far it reads as metal
// and how much of a lacquer's white sheen it shows (a sky of its own in the
// shine for both, since the world's isn't in the reflections),
// a pearl's shift toward `pearl` seen edge-on, and a glow by slot (body, trim,
// wing, dark) that comes up as the day goes.
uniform float finish_rough = -1.0;
uniform float finish_coat = -1.0;
uniform float finish_metal : hint_range(0.0, 1.0) = 0.0;
uniform float finish_sheen : hint_range(0.0, 1.0) = 0.0;
// A matte's chalkiness: the paint a little greyed and lifted, its rim gone.
uniform float finish_chalk : hint_range(0.0, 1.0) = 0.0;
uniform vec3 pearl : source_color = vec3(1.0);
uniform float pearl_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 glow : source_color = vec3(0.0);
uniform vec4 glow_slots = vec4(0.0);
uniform float glow_power = 0.0;
// Per instance (the airframe's and wires': the hinged parts' x is their own):
// the wing tips' bend, by distance out along the span, scripts/plane_figure.gd.
instance uniform float flex = 0.0;
void vertex() {
	float span_out = max(abs(VERTEX.x) - 0.16, 0.0);
	VERTEX.y += flex * span_out * span_out * 0.35;
}
// The scene light that shows as `display` (sRGB) through the world's ACES
// (white 16) at its exposure: shaders/reference_display.gdshaderinc's, so a
// glow shows in its own colour, not washed to white.
vec3 shown_as(vec3 display) {
	vec3 desired = mix(display / 12.92, pow((display + 0.055) / 1.055, vec3(2.4)), greaterThan(display, vec3(0.04045)));
	mat3 input_matrix = mat3(vec3(0.59719, 0.07600, 0.02840), vec3(0.35458, 0.90834, 0.13383), vec3(0.04823, 0.01566, 0.83777));
	mat3 output_matrix = mat3(vec3(1.60475, -0.10208, -0.00327), vec3(-0.53108, 1.10813, -0.07276), vec3(-0.07367, -0.00605, 1.07602));
	float w = 16.0 * 1.8;
	float white_scale = (w * (w + 0.0245786) - 0.000090537) / (w * (0.983729 * w + 0.432951) + 0.238081);
	vec3 y = inverse(output_matrix) * desired * white_scale;
	vec3 a = y * 0.983729 - 1.0;
	vec3 b = y * 0.432951 - 0.0245786;
	vec3 c = y * 0.238081 + 0.000090537;
	vec3 x = (-b - sqrt(max(b * b - 4.0 * a * c, vec3(0.0)))) / (2.0 * a);
	return max(inverse(input_matrix) * x / (1.8 * max(zs_exposure, 0.01)), vec3(0.0));
}
void fragment() {
	vec4 m = texture(mask_tex, UV);
	vec3 orm = texture(orm_tex, UV).rgb;
	vec3 base = texture(albedo_tex, UV).rgb;
	vec3 tint = vec3(1.0);
	tint = mix(tint, paint_body / BASE_BODY, m.r);
	tint = mix(tint, paint_trim / BASE_TRIM, m.g);
	tint = mix(tint, paint_wing / BASE_WING, m.b);
	tint = mix(tint, paint_dark / BASE_DARK, m.a);
	base *= tint;
	float painted = clamp(m.r + m.g + m.b + m.a, 0.0, 1.0);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	if (pearl_amount > 0.0) {
		float shift = pow(1.0 - facing, 1.5) * pearl_amount * painted;
		base = mix(base, pearl * max(dot(base, vec3(0.3, 0.55, 0.15)), 0.25) * 1.6, shift);
	}
	// What glows is dimmed under its light, so the light keeps its colour.
	float glowing = glow_power > 0.0 ? clamp(dot(m, glow_slots), 0.0, 1.0) * (1.0 - smoothstep(0.1, 0.65, zs_daylight)) : 0.0;
	base *= 1.0 - 0.92 * glowing;
	// A lacquer deepens the paint under it: richer and a little darker.
	float lac = finish_sheen * painted;
	base = max(mix(vec3(dot(base, vec3(0.3, 0.55, 0.15))), base, 1.0 + 0.45 * lac) * (1.0 - 0.15 * lac), vec3(0.0));
	float chalk = finish_chalk * painted;
	base = mix(base, mix(base, vec3(dot(base, vec3(0.3, 0.55, 0.15))), 0.45) * 1.2 + 0.035, chalk);
	vec3 up = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float dull = 0.0;
	if (wear > 0.0) {
		base = mix(base, vec3(dot(base, vec3(0.3, 0.55, 0.15))), 0.28 * wear * painted);
		float dust = smoothstep(0.15, 0.85, up.y) * wear;
		base = mix(base, wear_dust, dust * 0.34);
		dull = wear * 0.7;
	}
	base *= COLOR.r;
	ALBEDO = base;
	float rough = finish_rough < 0.0 ? orm.r : mix(orm.r, finish_rough, painted);
	float coat = finish_coat < 0.0 ? orm.b : mix(orm.b, finish_coat, painted);
	float metal = finish_metal * painted;
	ROUGHNESS = clamp(mix(rough, 1.0, dull * 0.6), 0.0, 1.0);
	// The sky isn't in the reflections, so a true metal would go black: a
	// third of one keeps its colour and its sheen.
	METALLIC = mix(orm.g * 0.35, 0.6, metal);
	// A matte has no highlight at all, the sun's included.
	SPECULAR = mix(0.5, 0.04, chalk);
	CLEARCOAT = coat * (1.0 - dull * 0.8);
	CLEARCOAT_ROUGHNESS = coat_roughness;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	// What looks down takes the sunlit land's bounce: a thin wing with nothing but
	// the world's dark ground term under it reads black, where a round body didn't.
	vec3 hemi = mix(zs_hemi_ground * bounce, zs_hemi_sky, up.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float edge = pow(1.0 - facing, 3.0);
	vec3 diffuse = base * (1.0 - mix(orm.g * 0.3, 0.92, metal));
	float sunward = clamp(dot(up, zs_key_direction), 0.0, 1.0);
	vec3 lift = mix(zs_hemi_sky, vec3(dot(zs_hemi_sky, vec3(0.2126, 0.7152, 0.0722))), shade_neutral) * zs_hemi_energy * shade_lift * mix(shade_night, 1.0, zs_daylight) * mix(1.0, shade_lit, sunward);
	EMISSION = (diffuse * (hemi * fill * mix(fill_night, 1.0, zs_daylight) + lift) + mix(diffuse, vec3(0.5), 0.4) * zs_hemi_sky * zs_hemi_energy * edge * rim * (1.0 - chalk)) * (1.0 - roof * roof_dim);
	float sheen = finish_sheen * painted * (1.0 - dull) * (1.0 - glowing);
	if (metal + sheen > 0.0) {
		// The paint's own sky: what the mirror sees, the sky above and the land
		// below parted sharply at the horizon, a pale band just over it. A metal
		// is all mirror, in its own colour: bright over dark down a round body.
		// A lacquer's is white, faint face-on and strong edge-on, with a
		// window's streak of light high up that runs along the fuselage.
		float seen = (INV_VIEW_MATRIX * vec4(reflect(-VIEW, NORMAL), 0.0)).y;
		float above = smoothstep(-0.03, 0.03, seen);
		float band = above * (1.0 - smoothstep(0.05, 0.3, seen));
		vec3 sky_lum = vec3(dot(zs_hemi_sky, vec3(0.2126, 0.7152, 0.0722)));
		vec3 env = (mix(zs_hemi_ground * bounce * 0.5, zs_hemi_sky * 2.0, above) + sky_lum * 2.5 * band) * zs_hemi_energy;
		float grazing = pow(1.0 - facing, 2.0);
		float streak = smoothstep(0.32, 0.4, seen) * (1.0 - smoothstep(0.5, 0.58, seen));
		vec3 lacquer = (env * mix(0.1, 1.0, grazing) + sky_lum * zs_hemi_energy * 3.0 * streak) * sheen;
		// A metal's mirror is harder: the land in it near black, the sky and
		// the band over the horizon bright, so a round body reads bright over dark.
		// Its colour is the paint's hue, lifted: a dark paint's metal still mirrors.
		float peak = max(max(base.r, base.g), max(base.b, 0.001));
		vec3 alloy = base * max(peak, 0.4) / peak;
		vec3 mirror = (mix(zs_hemi_ground * bounce * 0.08, sky_lum * 2.4, above) + sky_lum * 5.0 * band) * zs_hemi_energy;
		EMISSION += (mirror * alloy * metal * mix(1.3, 2.0, grazing) + lacquer) * (1.0 - roof * roof_dim);
	}
	// glow_power 1 shows the glow's own colour (its sRGB, up to 0.95 a
	// channel); below dims it, above pushes it brighter and into bloom.
	if (glowing > 0.0) {
		vec3 hue = mix(glow * 12.92, pow(glow, vec3(1.0 / 2.4)) * 1.055 - 0.055, greaterThan(glow, vec3(0.0031308)));
		EMISSION += shown_as(clamp(hue * min(glow_power, 1.0), 0.0, 0.95)) * max(glow_power, 1.0) * glowing;
	}
}
