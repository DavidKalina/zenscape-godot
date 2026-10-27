// The storm front on the GPU (scripts/endless/storm_front.gd, its mirror):
// the globals StormFront publishes each frame and its bands by the signed
// distance d from the leading edge (positive ahead). Keep the numbers here
// equal to storm_front.gd's constants. It declares the globals, guarded, so
// any include may pull it in; the compute cloud march (GLSL) gets them as
// uniforms instead.
#ifndef ZS_STORM_FRONT
#define ZS_STORM_FRONT

// xy: the leading edge's middle (world xz); zw: the heading (unit xz).
global uniform vec4 zs_storm_line;
// x: length, y: the core's depth, z: the gust band's depth, w: on (0/1).
global uniform vec4 zs_storm_shape;
// The amount at the eye (StormFront.amount_at), for screen and light grade.
global uniform float zs_storm_here;
// The latest strike: xy its world xz, z the seconds since it, w its strength
// (written by the lightning).
global uniform vec4 zs_lightning;

const float ZS_STORM_END_TAPER = 1000.0;
const float ZS_STORM_GUST_BEHIND = 500.0;
const float ZS_STORM_SHELF_AHEAD = 400.0;
const float ZS_STORM_CORE_FROM = -300.0;
const float ZS_STORM_CLEAR = 1000.0;
const vec2 ZS_STORM_RAIN_IN = vec2(-100.0, -600.0);
const vec2 ZS_STORM_RAIN_OUT = vec2(300.0, -500.0);

// 0 at a, 1 at b (either way round), smooth: StormFront.ramp.
float zs_storm_ramp(float a, float b, float x) {
	float t = clamp((x - a) / (b - a), 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}

bool zs_storm_on() {
	return zs_storm_shape.w > 0.5;
}

// The signed distance from the leading edge (m), positive ahead.
float zs_storm_d(vec2 p) {
	return dot(p - zs_storm_line.xy, zs_storm_line.zw);
}

// Along the line from its middle (m).
float zs_storm_along(vec2 p) {
	return dot(p - zs_storm_line.xy, vec2(-zs_storm_line.w, zs_storm_line.z));
}

float zs_storm_ends(vec2 p) {
	float half_len = zs_storm_shape.x * 0.5;
	return zs_storm_ramp(half_len, half_len - ZS_STORM_END_TAPER, abs(zs_storm_along(p)));
}

// How deep in the storm (0..1): cloud and gloom.
float zs_storm_amount(vec2 p) {
	if (!zs_storm_on()) return 0.0;
	float d = zs_storm_d(p);
	float core = zs_storm_shape.y;
	return zs_storm_ramp(ZS_STORM_SHELF_AHEAD, ZS_STORM_CORE_FROM, d)
		* zs_storm_ramp(-core - ZS_STORM_CLEAR, -core, d) * zs_storm_ends(p);
}

// The rain (0..1).
float zs_storm_rain(vec2 p) {
	if (!zs_storm_on()) return 0.0;
	float d = zs_storm_d(p);
	float core = zs_storm_shape.y;
	return zs_storm_ramp(ZS_STORM_RAIN_IN.x, ZS_STORM_RAIN_IN.y, d)
		* zs_storm_ramp(-core - ZS_STORM_RAIN_OUT.x, -core - ZS_STORM_RAIN_OUT.y, d) * zs_storm_ends(p);
}

// The gust front's wind (0..1).
float zs_storm_gust(vec2 p) {
	if (!zs_storm_on()) return 0.0;
	float d = zs_storm_d(p);
	float g = d > 0.0 ? zs_storm_ramp(zs_storm_shape.z, 0.0, d) : zs_storm_ramp(-ZS_STORM_GUST_BEHIND, 0.0, d);
	return g * zs_storm_ends(p);
}

#endif
