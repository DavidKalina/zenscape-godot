shader_type spatial;
// A kit cache's tell (scripts/kit_isle/kit_cache_glint.gd): one small point
// on the piece's surface, like light caught on a gem lodged in a joint.
// Mostly a faint point; when it catches (`glint`, an envelope the script
// drives) a short star of four long and four short arms, and one or two
// motes lifting off the spot (`age`: s since it caught). A weak hit's
// `flare` makes the same, brighter and bigger.
//
// Drawn on a camera-facing quad (a Sprite3D, QUAD m across) pulled `pull` m
// toward the camera so the stone it sits on doesn't cut it. The node's +Z is
// the face's normal: seen from behind the face it isn't drawn.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// How far toward the camera the quad is drawn (m).
uniform float pull = 0.14;
// The quiet point: brightness, radius (m), and the distances over which it
// fades out (it is only for someone close by).
uniform float idle = 0.55;
uniform float idle_size = 0.022;
uniform vec2 idle_fade = vec2(9.0, 18.0);
// The glint: its hot core (brightness, radius m) and the star (arm length
// m, arm half-width m, brightness, the short diagonal arms' share).
uniform float core = 3.0;
uniform float core_size = 0.03;
uniform float star_len = 0.2;
uniform float star_width = 0.0045;
uniform float star_gain = 2.2;
uniform float diagonal = 0.4;
// How much whiter than the tint the glint's middle burns.
uniform float white = 0.5;
// Far off, the thin parts are held at least this wide on screen (radians
// of view: about a pixel at 0.0012 on a 900-high 60-degree view), and the
// arms grow a little past `grow_from` m (by the root of the distance), so
// at walking distance the star still reads as one.
uniform float least = 0.0013;
uniform float grow_from = 5.0;
// A weak hit's flare (1 at the hit): how much brighter, and how much longer
// the arms.
uniform float flare_gain = 1.6;
uniform float flare_len = 1.2;
// The motes off the spot: brightness, radius (m), rise (m/s), life (s).
uniform float mote_gain = 1.4;
uniform float mote_size = 0.013;
uniform float mote_rise = 0.2;
uniform float mote_life = 1.5;
// The whole tell fades out over these distances (m).
uniform vec2 fade = vec2(28.0, 50.0);
// Seen this edge-on (cosine to the face's normal) or less, it is gone.
uniform float face_cut = 0.0;

instance uniform vec4 tint : source_color = vec4(0.62, 0.86, 0.94, 1.0);
instance uniform float glint = 0.0;
instance uniform float flare = 0.0;
instance uniform float age = 99.0;
instance uniform float spin = 0.0;

varying float vis;
varying float idle_vis;
varying float far;
varying vec2 local;

float arm(vec2 p, float len, float w) {
	float a = max(1.0 - abs(p.x) / len, 0.0);
	return a * a * a * exp(-(p.y * p.y) / (w * w));
}

void vertex() {
	vec3 at = MODEL_MATRIX[3].xyz;
	vec3 n = normalize(MODEL_MATRIX[2].xyz);
	vec3 to_cam = CAMERA_POSITION_WORLD - at;
	float dist = max(length(to_cam), 1e-4);
	float facing = dot(n, to_cam / dist);
	vis = smoothstep(face_cut, face_cut + 0.3, facing) * (1.0 - smoothstep(fade.x, fade.y, dist));
	idle_vis = 1.0 - smoothstep(idle_fade.x, idle_fade.y, dist);
	far = dist;
	local = VERTEX.xy;
	vec4 c = VIEW_MATRIX * vec4(at, 1.0);
	c.xyz += normalize(-c.xyz) * min(pull, dist * 0.5);
	POSITION = PROJECTION_MATRIX * vec4(c.xyz + vec3(VERTEX.xy, 0.0), 1.0);
}

void fragment() {
	vec2 p = local;
	float r2 = dot(p, p);
	float f = flare;
	float g = clamp(glint + f, 0.0, 1.0);
	float px = far * least;
	float isz = max(idle_size, px * 1.2);
	float light = idle * idle_vis * exp(-r2 / (isz * isz)) * (idle_size * idle_size) / (isz * isz) * 1.0;
	float hot = 0.0;
	if (g > 0.001) {
		float len = star_len * (0.35 + 0.65 * g) * (1.0 + f * flare_len) * sqrt(max(far / grow_from, 1.0));
		float w = max(star_width * (1.0 + f), px * 0.7);
		float cs = cos(spin);
		float sn = sin(spin);
		vec2 q = vec2(cs * p.x - sn * p.y, sn * p.x + cs * p.y);
		vec2 d = vec2(q.x + q.y, q.x - q.y) * 0.70710678;
		float s = arm(q, len, w) + arm(q.yx, len, w) + arm(d, len * diagonal, w) + arm(d.yx, len * diagonal, w);
		float csz = max(core_size, px * 1.6);
		float c = exp(-r2 / (csz * csz * (1.0 + f)));
		light += g * (star_gain * s + core * c);
		hot = g * c;
	}
	for (int i = 0; i < 2; i++) {
		float t = age - float(i) * 0.18;
		if (t > 0.0 && t < mote_life) {
			float k = t / mote_life;
			vec2 m = vec2((float(i) - 0.5) * 0.08 * k + sin(spin * 3.0 + float(i) * 2.4) * 0.03 * k, mote_rise * t + 0.015);
			vec2 dm = p - m;
			float msz = max(mote_size, px * 0.8);
			dm *= mote_size / msz;
			light += mote_gain * (1.0 - k) * smoothstep(0.0, 0.12, k) * exp(-dot(dm, dm) / (mote_size * mote_size));
		}
	}
	light *= (1.0 + f * flare_gain) * vis;
	ALBEDO = mix(tint.rgb, vec3(1.0), white * hot) * light;
}
