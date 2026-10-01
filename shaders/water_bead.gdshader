shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;
// A bead of the water ball's water (scripts/water_ball.gd): the drops that
// gather into it while it fills, drip from it, and fly from its splash. Each is
// a tiny lens: it shows the world behind it upside down and tinted, rims with
// the sky and catches a point of sun. Instance colour alpha fades it.
#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"
global uniform vec3 zs_palette_water;
uniform sampler2D bead_screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;
varying vec3 world_position;
varying float fade;

// pow() on a negative base is NaN on D3D12/Vulkan drivers (exp2(y·log2 x)),
// where Metal follows C and squares it: square by hand, clamp other bases.
float zs_sq(float x) { return x * x; }
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	fade = COLOR.a;
}

void fragment() {
	vec3 normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 eye = normalize(CAMERA_POSITION_WORLD - world_position);
	float facing = max(dot(eye, normal), 0.0);
	float fresnel = 0.04 + 0.9 * pow(max(1.0 - facing, 0.0), 4.0);
	// A ball lens flips what is behind it; a drop's image is small, so shift
	// the sample the other way across the drop.
	vec2 flip = NORMAL.xy * vec2(1.0, -1.0) * 0.012 * facing;
	vec3 behind = textureLod(bead_screen, clamp(SCREEN_UV + flip, vec2(0.002), vec2(0.998)), 0.0).rgb;
	vec3 tint = mix(vec3(1.0), vec3(0.62, 0.9, 0.84) * zs_palette_water / max(max(zs_palette_water.r, zs_palette_water.g), 0.001), 0.6);
	vec3 reflected = reflect(-eye, normal);
	vec3 sky = scene_linear_for_display(clamp(zsSkyGradient(vec3(reflected.x, abs(reflected.y), reflected.z)), vec3(0.0), vec3(0.98)));
	// Light gathered through the drop: a drop is brighter than what is behind
	// it, lit on its far side where the sun comes through.
	vec3 light = zs_key_irradiance / PI * zs_celestial_clear + zs_hemi_sky * zs_hemi_energy / PI;
	float through = zs_sq(max(dot(-normal, zs_key_direction), 0.0));
	vec3 color = mix(behind * tint + light * (0.12 + through * 0.35) * tint, sky * 1.2, fresnel);
	float glint = pow(max(dot(normalize(zs_key_direction + eye), normal), 0.0), 80.0);
	color += zs_key_irradiance / PI * glint * 2.5 * zs_celestial_clear;
	ALBEDO = color;
	ALPHA = fade * clamp(0.6 + fresnel + glint, 0.0, 1.0);
}
