// The tunnel a plane tears through a cloud (scripts/cloud_wakes.gd): its
// curve over a point's age, kept the same as CloudWakes `strength` and
// `radius` (OPEN, HOLD, LIFE, RADIUS, WIDEN, WIDEN_TIME there).
// Each point is a Vector4(x, y, z, time laid) and its way back to the
// point before it with its radius, Vector4(dx, dy, dz, radius); a radius
// of 0 is none.

const float ZS_WAKE_OPEN = 0.35;
const float ZS_WAKE_HOLD = 7.0;
const float ZS_WAKE_LIFE = 29.0;
const float ZS_WAKE_WIDEN = 1.5;
const float ZS_WAKE_WIDEN_TIME = 3.0;

// How open a point is at `age` seconds (0 to 1).
float zs_wake_strength(float age) {
	if (age < 0.0 || age >= ZS_WAKE_LIFE) return 0.0;
	return smoothstep(0.0, ZS_WAKE_OPEN, age) * (1.0 - smoothstep(ZS_WAKE_HOLD, ZS_WAKE_LIFE, age));
}

// Its radius (m) at `age`, from the radius it was laid with.
float zs_wake_radius(float laid, float age) {
	return laid * (1.0 + ZS_WAKE_WIDEN * smoothstep(0.0, ZS_WAKE_WIDEN_TIME, age)) * sqrt(zs_wake_strength(age));
}

// The point on the step from `b - back` to `b` nearest `p`.
vec3 zs_wake_nearest(vec3 p, vec3 b, vec3 back) {
	vec3 a = b - back;
	float len2 = dot(back, back);
	float h = len2 > 1e-4 ? clamp(dot(p - a, back) / len2, 0.0, 1.0) : 1.0;
	return a + back * h;
}
