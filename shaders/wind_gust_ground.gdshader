shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, depth_test_disabled, cull_front, fog_disabled;
// What a gust (scripts/wind_gust.gd) does to the ground, painted as a decal
// the way the water ball's mark is (shaders/water_ball_ground.gdshader): a box
// round the lane reads the depth buffer back to the ground it covers.
// While the hand blows, the mark is the promise (docs/scenic/handful.md): a
// pale lane from the press along the swipe, as wide as the air will be and
// as long as it will run, ending in an arrow tip, with chevrons of air light
// flowing along it (faster for a harder gust). A still press shows a ring
// instead, as far as the burst will reach, its chevrons drawing inward.
// When the gust goes, the air runs along the mark: a band of dappled shade
// and sheen at its head (cat's paws on the ground) and ripples across it,
// and the mark behind the head is used up.
// Premultiplied: ALBEDO is light added, ALPHA how much of the ground is dimmed.
#include "res://shaders/reference_globals.gdshaderinc"
uniform sampler2D ground_depth : hint_depth_texture, filter_nearest, repeat_disable;
// 0: a lane from `origin` along `heading`, `reach` m long and `half_width` m
// to each side. 1: a ring round `origin`, `reach` m out.
uniform int shape = 0;
uniform vec2 origin = vec2(0.0);
uniform vec2 heading = vec2(1.0, 0.0);
uniform float reach = 10.0;
uniform float half_width = 3.0;
// How much of the mark shows, how hard the gust will blow (0..1), where the
// air's head is (m along the lane or out from the ring's centre; far below
// zero while the hand still blows), how strongly it is passing now (0..1),
// and the head's speed (m/s).
uniform float promise = 0.0;
uniform float power = 0.5;
uniform float passed = -1000.0;
uniform float air = 0.0;
uniform float head_speed = 8.0;
uniform float age = 0.0;
// The breath the mark takes (-1..1), and the ground's height range under it:
// nothing outside it is painted.
uniform float breath = 0.0;
uniform float floor_y = -100.0;
uniform float ceiling = 100.0;

// The mark: faceted like the ground and the water ball's mark. The lane's
// back is half a MARK_SIDES-gon, its tip an arrow TIP_FLARE times the lane's
// width; the ring is a MARK_SIDES-gon turning MARK_TURN rad/s. CHEVRON_SPACING
// m between chevrons, flowing CHEVRON_FLOW (weak, strong) spacings a second.
const int MARK_SIDES = 12;
const float MARK_TURN = 0.12;
const float TIP_FLARE = 1.25;
const float CHEVRON_SPACING = 1.6;
const vec2 CHEVRON_FLOW = vec2(0.5, 2.2);
// The air's head: metres of shade ahead of it and behind it, and how far
// behind it the mark is used up.
const float PAW_FRONT = 1.8;
const float PAW_TAIL = 4.5;
const float USED_UP = 7.0;

// pow() on a negative base is NaN on D3D12/Vulkan drivers (exp2(y·log2 x)),
// where Metal follows C and squares it: square by hand.
float zs_sq(float x) { return x * x; }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float depth = textureLod(ground_depth, SCREEN_UV, 0.0).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	vec3 box = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	if (any(greaterThan(abs(box), vec3(0.5))) || world.y > ceiling || world.y < floor_y) discard;
	// Ground only: trunks, cliffs and the undersides of things stay clean.
	vec3 facing = normalize(cross(dFdy(world), dFdx(world)));
	float flat_ground = smoothstep(0.45, 0.75, abs(facing.y));
	vec3 light = zs_key_irradiance / PI * zs_celestial_clear;
	vec3 sky_light = zs_hemi_sky * zs_hemi_energy / PI;
	// Air light: pale, lit by the sky as well as the sun and never quite dark.
	vec3 glow = vec3(0.86, 0.93, 0.95) * (light * 0.3 + sky_light * 0.7 + vec3(0.02 + 0.03 * zs_night));
	vec2 rel = world.xz - origin;
	// d: 0 at the mark's spine, 1 at its edge. along: m from the start (lane)
	// or the centre (ring), the way the air runs.
	float d;
	float along;
	float across_share;
	float wedge = TAU / float(MARK_SIDES);
	if (shape == 0) {
		vec2 side = vec2(-heading.y, heading.x);
		float a = dot(rel, heading);
		float c = dot(rel, side);
		float hw = half_width * (1.0 + breath * 0.035);
		float tip = min(hw * 1.6, reach * 0.4);
		if (a < 0.0) {
			float around = mod(atan(c, a), wedge) - wedge * 0.5;
			d = length(vec2(a, c)) * cos(around) / hw;
		} else if (a <= reach) {
			float width = a < reach - tip ? hw : hw * TIP_FLARE * (reach - a) / tip;
			d = abs(c) / max(width, 0.001);
		} else {
			d = 2.0;
		}
		along = a;
		across_share = abs(c) / hw;
	} else {
		float ring = reach * (1.0 + breath * 0.035);
		float around = mod(atan(rel.y, rel.x) + age * MARK_TURN, wedge) - wedge * 0.5;
		along = length(rel);
		d = along * cos(around) / max(ring, 0.001);
		across_share = 0.0;
	}
	float shade = 0.0;
	vec3 add = vec3(0.0);
	// The promise, used up behind the passing air.
	float keep = smoothstep(passed - USED_UP, passed - 1.0, along);
	float mark = promise * keep;
	if (mark > 0.001) {
		float edge = 0.12;
		float pool = 1.0 - smoothstep(1.0 - edge, 1.0, d);
		float core = 1.0 - smoothstep(0.58 - edge * 0.5, 0.58, d);
		// Two painted tones, lighter than the water ball's: this is air.
		shade = shape == 0 ? pool * 0.2 + core * 0.07 : pool * 0.1;
		float rim = exp(-zs_sq((d - 1.0) / (shape == 0 ? 0.06 : 0.035)));
		add += glow * rim * (0.55 + 0.12 * breath);
		// Chevrons of air light flow the way it will blow: along the lane,
		// or in toward the ring's centre while a burst gathers.
		float flow = mix(CHEVRON_FLOW.x, CHEVRON_FLOW.y, power);
		float v = shape == 0 ? (along + across_share * half_width * 0.8) / CHEVRON_SPACING - age * flow : along / CHEVRON_SPACING + age * flow;
		float band = fract(v);
		float chevron = smoothstep(0.3, 0.46, band) * (1.0 - smoothstep(0.5, 0.64, band));
		float inside = pool * (1.0 - smoothstep(0.62, 0.86, d)) * (shape == 0 ? smoothstep(-0.5, 1.0, along) : smoothstep(0.1, 0.35, d));
		add += glow * chevron * inside * mix(0.28, 0.45, power);
		shade = shade * mark;
		add *= mark;
	}
	// The air passing: a band of dappled shade and sheen rides at its head,
	// sharp in front, trailing behind, with ripples running across it.
	if (air > 0.001) {
		float x = along - passed;
		float band = x > 0.0 ? exp(-x * x / (2.0 * PAW_FRONT * PAW_FRONT)) : exp(-x * x / (2.0 * PAW_TAIL * PAW_TAIL));
		float lane = shape == 0 ? 1.0 - smoothstep(0.75, 1.2, across_share) : 1.0;
		float paw = band * lane * air;
		if (paw > 0.002) {
			vec2 way = shape == 0 ? heading : rel / max(along, 0.001);
			vec2 carried = world.xz - way * age * head_speed * 0.6;
			float n = noise2(carried * 0.9) * 0.6 + noise2(carried * 2.3 + vec2(age * 0.7, 0.0)) * 0.4;
			float dark = smoothstep(0.45, 0.8, n);
			float sheen = 1.0 - smoothstep(0.1, 0.45, n);
			float ripple = pow(0.5 + 0.5 * sin((along - passed) * 3.2 - age * 9.0), 6.0);
			shade = max(shade, paw * dark * 0.24);
			add += (sky_light * 0.6 + light * 0.25) * paw * (sheen * 0.16 + ripple * 0.1);
		}
	}
	ALBEDO = add * flat_ground;
	ALPHA = clamp(shade * flat_ground, 0.0, 1.0);
}
