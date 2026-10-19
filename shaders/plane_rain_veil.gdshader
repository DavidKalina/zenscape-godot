shader_type spatial;
// The rain's distance (scripts/plane_weather.gd `rain`): an open cylinder
// round the eye, seen from inside, drawn as a faint grey veil streaked with
// soft falling lines, so what lies past it greys into the rain. `columns`
// lines round, each a run of segments `run` m long sliding down at `fall`
// m/s, leaning `slant` (m across per m down) with the wind and the flight.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.5, 0.53, 0.58, 0.14);
uniform float strength = 0.0;
uniform float haze = 0.75;
uniform float columns = 900.0;
uniform float run = 30.0;
uniform float fall = 9.0;
uniform float slant = 0.0;

varying vec3 local;

void vertex() {
	local = VERTEX;
}

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	float down = local.y + TIME * fall;
	float round = atan(local.z, local.x) / 6.2831853 + 0.5 + slant * down / 600.0;
	float c = round * columns;
	float id = floor(c);
	float line = 1.0 - smoothstep(0.0, 0.5, abs(fract(c) - 0.5));
	float seg = fract(down / (run * (0.6 + 0.8 * hash(id))) + hash(id + 5.0));
	float lit = smoothstep(0.0, 0.35, seg) * smoothstep(1.0, 0.55, seg) * step(0.55, hash(id + 9.0)) * hash(id + 2.0);
	// Fades out where it would stand overhead or underfoot.
	float level = 1.0 - smoothstep(60.0, 140.0, abs(local.y));
	ALBEDO = tint.rgb;
	ALPHA = strength * tint.a * level * (haze + (1.0 - haze) * line * lit);
}
