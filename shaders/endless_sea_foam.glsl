#[compute]
#version 450
// The sea's foam that lingers (scripts/endless/sea_foam.gd): a square of
// the sea round the eye, addressed by world position wrapped on its side
// (a toroidal buffer), so moving the square costs nothing; what slides in
// at the leading edge starts clean. Each frame every texel takes last
// frame's foam from upstream (the drift downwind plus a slow swirl that
// pulls patches out into veins), lets it spread a little and fade, then
// adds what the wind sea's breaking crests leave right now. The crests are
// found the way shaders/endless_sea.gdshader finds them (zs_swell_body,
// waves 5..8 of the wind sea), so the trail starts where the drawn cap is.
//
//   r  the foam's density (fades over `caps.y` s)
//   g  how young it is (1 at the crest, fading over `flow.w` s)
//   b  the churned water round it (spreads wider, fades slower)
//   a  the wake's foam laid into the buffer

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer Params {
	vec4 window;  // origin x, z now; side m; texels
	vec4 before;  // origin x, z last frame; dt; time (zs_flow_time)
	vec4 swell;   // body_swell xyz; swell_groups
	vec4 patches;   // body_patch xyz; wind_patches.x
	vec4 wind;    // body_wind xy; last frame valid; spread (m^2/s)
	vec4 caps;    // whitecaps xyz (amount, life s, streak); halo spread
	vec4 flow;    // drift m/s; swirl m/s; swirl size m; youth s
	vec4 wake;    // plane x, z; strength 0..1; radius m
	vec4 extra;   // foam_caps xyz; -
} P;

// Last frame's foam, read as an image (sampling the texture the pass wrote
// the frame before hung Metal), filtered by hand.
layout(set = 0, binding = 1, rgba16f) uniform restrict readonly image2D prev;
layout(set = 0, binding = 2, rgba16f) uniform restrict writeonly image2D next;

const float PI = 3.14159265;
const float TAU = 6.2831853;
const float GRAVITY = 9.81;
const float BODY_LENGTH[11] = float[11](118.0, 86.0, 64.0, 74.0, 52.0, 28.0, 20.0, 14.5, 10.5, 7.6, 5.5);
const float BODY_TURN[11] = float[11](0.0, 0.16, -0.22, 0.0, 0.3, 0.0, 0.38, -0.32, 0.62, -0.55, 0.9);
const float BODY_SIZE[11] = float[11](0.45, 0.42, 0.38, 0.32, 0.28, 0.07, 0.068, 0.064, 0.06, 0.055, 0.05);

float body_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float body_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(body_hash(i), body_hash(i + vec2(1.0, 0.0)), f.x), mix(body_hash(i + vec2(0.0, 1.0)), body_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// The world point this texel stands for: the one inside the square at
// `origin` that wraps onto it.
vec2 world_of(ivec2 texel, vec2 origin, float side, float n) {
	vec2 c = (vec2(texel) + 0.5) * side / n;
	return origin + mod(c - origin, side);
}

// Last frame's foam at world `p` (0 outside last frame's square).
vec4 prev_at(vec2 p) {
	if (P.wind.z < 0.5) return vec4(0.0);
	vec2 o = P.before.xy;
	float side = P.window.z;
	vec2 inside = (p - o) / side;
	if (any(lessThan(inside, vec2(0.0))) || any(greaterThan(inside, vec2(1.0)))) return vec4(0.0);
	float n = P.window.w;
	vec2 at = p / side * n - 0.5;
	ivec2 i = ivec2(floor(at));
	vec2 f = at - vec2(i);
	int m = int(n);
	ivec2 a = ivec2((i.x % m + m) % m, (i.y % m + m) % m);
	ivec2 b = ivec2((a.x + 1) % m, (a.y + 1) % m);
	vec4 c00 = imageLoad(prev, a), c10 = imageLoad(prev, ivec2(b.x, a.y));
	vec4 c01 = imageLoad(prev, ivec2(a.x, b.y)), c11 = imageLoad(prev, b);
	return mix(mix(c00, c10, f.x), mix(c01, c11, f.x), f.y);
}

void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	float n = P.window.w;
	if (id.x >= int(n) || id.y >= int(n)) return;
	float side = P.window.z;
	float texel = side / n;
	vec2 p = world_of(id, P.window.xy, side, n);
	float dt = P.before.z;
	float t = P.before.w;
	vec2 hw = normalize(P.wind.xy);

	// Upstream: the steady drift downwind and a slow swirl (the curl of a
	// drifting noise), which stretches a patch into streaks and veins.
	vec2 q = (p - hw * t * P.flow.x) / max(P.flow.z, 1.0) + vec2(t * 0.013, -t * 0.009);
	const float E = 0.15;
	float nx = body_noise(q + vec2(E, 0.0)) - body_noise(q - vec2(E, 0.0));
	float ny = body_noise(q + vec2(0.0, E)) - body_noise(q - vec2(0.0, E));
	vec2 swirl = vec2(ny, -nx) / (2.0 * E);
	vec2 vel = hw * P.flow.x + swirl * P.flow.y;
	vec2 from = p - vel * dt;
	vec4 here = prev_at(from);
	// Spreading: a little of the neighbours' (diffusion, D m^2/s), the
	// churned water's wider.
	vec4 ring = (prev_at(from + vec2(texel, 0.0)) + prev_at(from - vec2(texel, 0.0)) + prev_at(from + vec2(0.0, texel)) + prev_at(from - vec2(0.0, texel))) * 0.25;
	float k = clamp(4.0 * P.wind.w * dt / (texel * texel), 0.0, 0.5);
	float kb = clamp(4.0 * P.caps.w * dt / (texel * texel), 0.0, 0.5);
	vec4 foam = vec4(mix(here.rg, ring.rg, k), mix(here.b, ring.b, kb), mix(here.a, ring.a, k));
	// Fading: the thin goes first.
	float life = max(P.caps.y, 0.2);
	foam.r = max(foam.r * exp(-dt / life) - dt * 0.012, 0.0);
	foam.g *= exp(-dt / max(P.flow.w, 0.05));
	foam.b = max(foam.b * exp(-dt / (life * 1.3)) - dt * 0.006, 0.0);
	foam.a = max(foam.a * exp(-dt / (life * 0.8)) - dt * 0.012, 0.0);

	// What the breaking crests leave now (zs_swell_body's whitecaps).
	vec2 wa = vec2(dot(p, hw), dot(p, vec2(-hw.y, hw.x))) - vec2(t * 1.5, 0.0);
	vec2 wr = wa / vec2(P.patches.w, P.patches.w * 0.7);
	float rough = smoothstep(0.3, 0.7, body_noise(wr + vec2(5.9, 1.3)) * 0.65 + body_noise(wr * 2.3 + vec2(2.2, 9.1)) * 0.35);
	float wsea = mix(P.patches.x, P.patches.y, rough);
	float bend = (body_noise(p / 95.0 + vec2(t * 0.01, 7.1)) - 0.5) * 2.4 + (body_noise(p / 37.0 + vec2(2.4, t * 0.015)) - 0.5) * 0.9;
	float gt = body_noise(vec2(dot(p, hw) - t * 2.6, dot(p, vec2(-hw.y, hw.x))) / vec2(90.0, 120.0) + vec2(3.1, 6.6));
	vec2 gp = (p - hw * t * 2.0) / 55.0;
	float gust = smoothstep(0.45, 0.8, body_noise(gp + vec2(9.1, 3.7)) * 0.7 + body_noise(gp * 2.7 + vec2(1.3, 8.8)) * 0.3);
	float laid = 0.0;
	for (int i = 5; i <= 8; i++) {
		float L = BODY_LENGTH[i];
		float c = cos(BODY_TURN[i]), s = sin(BODY_TURN[i]);
		vec2 d = vec2(c * hw.x - s * hw.y, s * hw.x + c * hw.y);
		float kk = TAU / L;
		float omega = sqrt(GRAVITY * kk);
		vec2 along = vec2(dot(p, d) - 0.5 * omega / kk * t, dot(p, vec2(-d.y, d.x)));
		float own = body_noise(along / (L * vec2(2.6, 3.4)) + vec2(float(i) * 3.7, float(i) * 1.3));
		float group = smoothstep(0.2, 0.8, mix(gt, own, 0.65));
		group = mix(1.0, 0.12 + 1.6 * group * group, P.swell.w);
		float phase = dot(p, d) * kk - omega * t + float(i) * 2.39 + bend * (0.5 + 0.1 * float(i));
		float u = (PI * 0.5 - phase) / TAU;
		float since = fract(u), crest = floor(u);
		float r = max(wsea, P.extra.z) * group;
		float chance = clamp((r - P.extra.x) * 0.32 * P.caps.x, 0.0, 0.3) * (P.extra.y + (1.0 - P.extra.y) * gust);
		float nn = body_noise(vec2(dot(p, vec2(-d.y, d.x)) / (L * 0.3), dot(p, d) / (L * 0.4)) + vec2(crest * 1.37 + float(i) * 5.1, crest * 2.71));
		float ragged = body_noise(p / 1.7 + vec2(crest * 0.73, float(i) * 2.9));
		float birth = smoothstep(1.0 - chance, 1.2 - chance, nn + (ragged - 0.5) * 0.3) * smoothstep(0.0, 0.14, chance);
		// Just behind the crest, where the drawn cap stands.
		float window = smoothstep(0.0, 0.03, since) * (1.0 - smoothstep(0.08, 0.16, since));
		laid = max(laid, birth * window);
	}
	foam.r = max(foam.r, laid);
	foam.g = max(foam.g, laid);
	foam.b = max(foam.b, laid * 0.8);
	// The plane's wake, laid where it skims.
	if (P.wake.z > 0.0) {
		float w = 1.0 - smoothstep(P.wake.w * 0.3, P.wake.w, length(p - P.wake.xy));
		float churn = body_noise(p / 0.9 + vec2(t * 3.0, 0.0)) * 0.6 + body_noise(p / 0.4 - vec2(0.0, t * 2.0)) * 0.4;
		foam.a = max(foam.a, w * P.wake.z * smoothstep(0.3, 0.6, churn));
		foam.b = max(foam.b, w * P.wake.z * 0.3);
	}
	// Clean at the square's rim, where the wrap meets.
	vec2 rim = min(p - P.window.xy, P.window.xy + side - p);
	foam *= step(texel * 2.0, min(rim.x, rim.y));
	imageStore(next, id, clamp(foam, 0.0, 1.0));
}
