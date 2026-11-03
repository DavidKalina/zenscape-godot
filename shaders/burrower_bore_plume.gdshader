shader_type spatial;
// The burrower's plume out of a tunnel's far mouth (scripts/endless/bore_plume.gd): one mesh
// of quads, the node at the mouth on the floor; this places each. Three kinds, by COLOR.a:
// the column of dust up out of the sinkhole, dust rolling back down the bore, chips thrown.
// COLOR's other three and NORMAL are each bit's draws, UV its corner. Unshaded, like his
// dust on the land (burrower_dust.gdshader), so it reads the same in the bore and out of it.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float now = 0.0;
uniform float lit_at = 0.0;
// The mouth's way out (world, level).
uniform vec3 out_way = vec3(0.0, 0.0, 1.0);
// The shares of the bits that are column and back-rolling dust; the rest are chips.
uniform float dust_share = 0.42;
uniform float back_share = 0.13;
// The mouth: half width and how far up (m).
uniform float wide = 15.0;
uniform float tall = 20.0;
uniform float fall = 13.0;
// The column's rise, out and growth; its slow climb after the jet is spent (m/s).
uniform vec2 rise = vec2(22.0, 135.0);
uniform vec2 away = vec2(12.0, 44.0);
uniform float climb = 7.0;
uniform float least = 0.0034;
// A puff this near the eye (m) fades, so flying through it is not a wall of quads.
uniform float near_fade = 14.0;
uniform float soft = 2.0;
// How dark the dust gets back down the bore, by how far in (m).
uniform float back_dim = 0.3;
uniform float back_dark = 45.0;
uniform vec3 dust : source_color = vec3(0.47, 0.40, 0.31);
uniform vec3 dust_hot : source_color = vec3(0.85, 0.55, 0.32);
uniform vec3 stone : source_color = vec3(0.34, 0.29, 0.24);
uniform vec3 ember : source_color = vec3(1.0, 0.5, 0.2);
uniform float ember_glow = 2.2;

varying float v_a;
varying float v_kind;
varying float v_hot;
varying float v_seed;
varying float v_tone;
varying float v_up;
varying vec2 v_uv;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	float t = now - lit_at;
	vec3 root = MODEL_MATRIX[3].xyz;
	vec3 r = COLOR.rgb;
	float kind = COLOR.a;
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 side = normalize(cross(up, out_way));
	float across = r.x * 2.0 - 1.0;
	vec3 mouth = root + side * across * wide + up * r.y * tall;
	vec3 w = mouth;
	float born;
	float life;
	float size;
	float grow = 1.0;
	float a = 1.0;
	float tone = 0.8 + 0.35 * NORMAL.x;
	float k;
	float age;
	if (kind < dust_share) {
		// The column: thrown out and up hard, the drag taking it, then a slow climb.
		v_kind = 1.0;
		born = r.z * r.z * 1.8;
		life = 4.5 + 4.0 * NORMAL.x;
		age = t - born;
		float high = NORMAL.y * sqrt(NORMAL.y);
		vec3 v = up * mix(rise.x, rise.y, high) + out_way * mix(away.x, away.y, r.z) + side * across * 12.0;
		v += (side * (NORMAL.z - 0.5) + out_way * (r.y - 0.5)) * 44.0 * high;
		w = mouth + v * (1.0 - exp(-max(age, 0.0) * 0.75)) / 0.75 + up * climb * max(age, 0.0);
		size = (5.0 + 7.0 * NORMAL.z) * (1.0 + 0.8 * high);
		grow = 2.6;
	} else if (kind < dust_share + back_share) {
		// Back down the bore at the plane, the rock's way.
		v_kind = 1.0;
		born = r.z * 0.35;
		life = 2.4 + 2.2 * NORMAL.x;
		age = t - born;
		float run = mix(30.0, 95.0, NORMAL.y);
		w = mouth - out_way * run * (1.0 - exp(-max(age, 0.0) * 1.4)) / 1.4;
		w.y = root.y + r.y * tall * 0.8 + 1.5 * max(age, 0.0);
		size = 5.0 + 4.0 * NORMAL.z;
		grow = 1.6;
		tone = mix(1.0, back_dim, clamp(dot(root - w, out_way) / back_dark, 0.0, 1.0));
	} else {
		// Chips.
		v_kind = 0.0;
		born = r.z * 0.3;
		life = 3.0 + 2.0 * NORMAL.x;
		age = t - born;
		vec3 v = up * mix(32.0, 70.0, NORMAL.y) + out_way * mix(6.0, 34.0, r.z) + side * across * 18.0;
		w = mouth + v * age + vec3(0.0, -0.5 * fall * age * age, 0.0);
		size = 0.35 + 1.1 * NORMAL.z * NORMAL.z;
	}
	k = age / life;
	if (k < 0.0 || k > 1.0) {
		VERTEX = vec3(0.0, 0.0, 1.0);
		a = 0.0;
	} else {
		vec4 vw = VIEW_MATRIX * vec4(w, 1.0);
		if (v_kind > 0.5) {
			size *= 1.0 + grow * sqrt(k);
			a = 0.5 * smoothstep(0.0, 0.05, k) * (1.0 - k) * (1.0 - k);
			a *= clamp((-vw.z - size * 0.3) / near_fade, 0.0, 1.0);
		} else {
			size = max(size, -vw.z * least);
			a = 1.0 - smoothstep(0.8, 1.0, k);
		}
		VERTEX = vw.xyz + vec3(UV * size, 0.0);
	}
	float spin = (NORMAL.y + NORMAL.z * max(age, 0.0) * 3.0) * 6.0;
	NORMAL = vec3(0.0, 0.0, 1.0);
	v_a = a;
	float o = 1.0 - clamp(age / 0.9, 0.0, 1.0);
	v_hot = o * o;
	v_seed = (r.x + r.z * 3.0) * 40.0;
	v_tone = tone;
	v_up = UV.y;
	v_uv = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin))) * UV;
}

void fragment() {
	float a;
	if (v_kind > 0.5) {
		// Ragged, not round: lobes and noise, as his dust on the land.
		float ang = atan(v_uv.y, v_uv.x);
		float edge = 1.0 + 0.22 * sin(3.0 * ang + v_seed * 5.0) + 0.14 * sin(5.0 * ang + v_seed * 9.0);
		float d = dot(v_uv, v_uv) / (edge * edge);
		a = (1.0 - smoothstep(0.1, 1.0, d)) * v_a;
		// Inside the quad's own edge, whatever the lobes reach.
		a *= 1.0 - smoothstep(0.62, 0.98, length(v_uv));
		float n = vnoise(v_uv * 2.6 + vec2(v_seed * 3.1, v_seed * 7.3)) * 0.7 + vnoise(v_uv * 5.5 + v_seed) * 0.3;
		a *= smoothstep(0.15, 0.7, n) * 1.5;
		// Soft where it meets the rock.
		float z = textureLod(depth_tex, SCREEN_UV, 0.0).r;
		vec4 wp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, z, 1.0);
		a *= clamp((VERTEX.z - wp.z / wp.w) / soft, 0.0, 1.0);
		// A billow: lit on top, in shade under, each puff its own tone, and darker down
		// the bore, away from the daylight.
		float top = 0.62 + 0.5 * (v_up * 0.5 + 0.5) + 0.3 * (n - 0.5);
		ALBEDO = mix(dust * top * v_tone, dust_hot, v_hot);
	} else {
		// A shard, each its own shape.
		vec2 q = v_uv * vec2(1.0 + 0.5 * sin(v_seed), 1.0 - 0.3 * cos(v_seed * 1.7));
		float tri = max(abs(q.x) * 0.87 + q.y * 0.5, -q.y);
		a = (1.0 - smoothstep(0.5, 0.64, tri)) * v_a;
		ALBEDO = stone + ember * ember_glow * v_hot;
	}
	if (a < 0.003) discard;
	ALPHA = clamp(a, 0.0, 1.0);
}
