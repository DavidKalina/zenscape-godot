shader_type spatial;
// The grit and dust of a spur's tell (scripts/endless/bore_tell.gd): one mesh of quads,
// the node at the spur's root; this places each. Three kinds, by COLOR.a: grit falling
// out of the crack through the hold, chips thrown at the snap, dust at the snap. COLOR's
// other three and NORMAL are each bit's draws, UV its corner. Lit by what lights the rock.
render_mode blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, diffuse_lambert, specular_disabled, ambient_light_disabled, fog_disabled, shadows_disabled;

uniform float now = 0.0;
uniform float hold = 0.8;
uniform float fall = 13.0;
// The shares of the bits that are grit and chips; the rest are dust.
uniform float grit_share = 0.6;
uniform float chip_share = 0.25;
// The least size of a grit or chip (a share of its distance): about two pixels.
uniform float least = 0.0034;
uniform vec3 stone : source_color = vec3(0.5, 0.43, 0.36);
uniform vec3 dust : source_color = vec3(0.42, 0.36, 0.30);
uniform vec3 ember : source_color = vec3(1.0, 0.5, 0.2);
uniform float ember_glow = 1.8;

instance uniform float lit_at = 0.0;
instance uniform vec3 up = vec3(0.0, 1.0, 0.0);
instance uniform float wide = 8.0;
instance uniform float tall = 3.0;

varying float v_a;
varying float v_kind;
varying float v_hot;
varying vec2 v_uv;

void vertex() {
	float t = now - lit_at;
	vec3 root = MODEL_MATRIX[3].xyz;
	vec3 r = COLOR.rgb;
	float kind = COLOR.a;
	vec3 side = normalize(cross(up, abs(up.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
	vec3 fore = cross(up, side);
	// Out of the blister's skin, not from under it.
	float ring = sqrt(r.x);
	float skin = tall * (1.0 - 0.64 * r.x) + 0.4;
	float ang = r.y * TAU;
	vec3 disc = side * cos(ang) + fore * sin(ang);
	vec3 p;
	vec3 v;
	float born;
	float life;
	float size;
	float a = 1.0;
	float hot = 0.0;
	float g = fall;
	if (kind < grit_share) {
		v_kind = 0.0;
		born = r.z * hold * 0.92;
		life = 1.3 + 0.8 * NORMAL.x * NORMAL.x;
		p = root + disc * ring * wide * 0.8 + up * skin;
		v = up * (1.5 + 3.0 * r.x) + NORMAL * 1.5;
		size = 0.1 + 0.16 * r.z;
		hot = 0.8;
	} else if (kind < grit_share + chip_share) {
		v_kind = 0.0;
		born = hold + r.z * 0.06;
		life = 1.2 + 0.5 * r.x;
		p = root + disc * ring * wide * 0.3 + up * tall;
		v = up * (10.0 + 18.0 * r.x) + (disc * 0.7 + NORMAL * 0.5) * (5.0 + 9.0 * r.z);
		size = 0.16 + 0.42 * r.x * r.z;
		hot = 1.0;
	} else {
		v_kind = 1.0;
		born = hold + r.z * 0.12;
		life = 1.1 + 0.9 * r.x;
		p = root + disc * ring * wide * 0.55 + up * tall;
		v = up * (2.0 + 5.0 * r.z) + disc * (1.0 + 4.0 * r.x);
		g = 0.6;
		size = 2.2;
	}
	float k = (t - born) / life;
	vec3 w;
	if (k < 0.0 || k > 1.0) {
		VERTEX = vec3(0.0, 0.0, 1.0);
		a = 0.0;
	} else {
		float age = t - born;
		w = p + v * age + vec3(0.0, -0.5 * g * age * age, 0.0);
		if (v_kind > 0.5) {
			size *= 1.0 + 2.4 * sqrt(k);
			a = 0.42 * sin(min(k * 6.0, 1.0) * 1.57) * (1.0 - k) * (1.0 - k);
			w = p + v * (1.0 - exp(-age * 1.6)) / 1.6;
		} else {
			a = 1.0 - smoothstep(0.75, 1.0, k);
		}
		vec4 vw = VIEW_MATRIX * vec4(w, 1.0);
		if (v_kind < 0.5) size = max(size, -vw.z * least);
		VERTEX = vw.xyz + vec3(UV * size, 0.0);
	}
	float spin = (NORMAL.y + NORMAL.z * max(t - born, 0.0) * 3.0) * 6.0;
	NORMAL = vec3(0.0, 0.0, 1.0);
	v_a = a;
	float o = 1.0 - clamp(k * 1.6, 0.0, 1.0);
	v_hot = hot * o * o;
	v_uv = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin))) * UV;
}

void fragment() {
	float d = dot(v_uv, v_uv);
	float a;
	if (v_kind > 0.5) {
		a = (1.0 - smoothstep(0.1, 1.0, d)) * v_a;
		ALBEDO = dust;
	} else {
		// A shard: a three-cornered chip, not a ball.
		float tri = max(abs(v_uv.x) * 0.87 + v_uv.y * 0.5, -v_uv.y);
		a = (1.0 - smoothstep(0.5, 0.64, tri)) * v_a;
		ALBEDO = stone;
		EMISSION = ember * ember_glow * v_hot;
	}
	if (a < 0.003) discard;
	ALPHA = a;
}
