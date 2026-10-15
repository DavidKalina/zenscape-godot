shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// The Hollow Child's fired clay (scripts/city_hollow_child.gd, its mesh
// scripts/city_hollow_child_mesh.gd): a burnished white kaolin slip over red
// clay, as the Olmec hollow babies are. Painted in solid noise over the
// figure's own space (the mesh's VERTEX), from its vertex colours:
//   r  crevice  grime settled in the folds, the slits and under the chin
//   g  wear     the slip worn through to the red clay (knees, nose, toes,
//               knuckles, cheekbones, the belly's curve, the crown)
//   b  thin     where the light inside shows through, like a lampshade
//   a  cavity   inside the open mouth: dark, and where the light pours out
// Over the slip: soft mottling, grey fire-clouds from the firing, a fine
// crazing of the slip (faded by the pixel's footprint), chips where the
// slip flaked to the clay. Burnished, the slip is a touch glossy; the clay
// is dry.
// The light it drinks (`fill`, 0..1) climbs inside it from the feet to the
// eyes (UV2.x is the figure's height, 0 feet .. 1 crown; the eyes at
// `eyes`): dim, warm, amber through the thin places, never bright. `breath`
// (0..1) the held breath before the cry: the eyes and mouth glow. `blaze`
// (0..1) the cry: everything it drank pours out through the clay and the
// mouth.
// The underground's fill as the Olmec's stone has it (shaders/olmec_stone.gdshader).

global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;
global uniform float zs_under;
global uniform vec3 zs_under_sky;
global uniform vec3 zs_under_ground;

uniform vec3 slip : source_color = vec3(0.79, 0.75, 0.66);
uniform vec3 slip_low : source_color = vec3(0.62, 0.57, 0.48);
uniform vec3 clay : source_color = vec3(0.50, 0.31, 0.22);
uniform vec3 clay_dark : source_color = vec3(0.32, 0.20, 0.15);
uniform vec3 grime : source_color = vec3(0.17, 0.14, 0.11);
// Dust and ash settled on its tops and low down.
uniform vec3 dust : source_color = vec3(0.50, 0.45, 0.37);
uniform vec3 glow_colour : source_color = vec3(1.0, 0.55, 0.22);
uniform float hemi_fill = 0.6;
uniform float fill : hint_range(0.0, 1.0) = 0.0;
uniform float eyes = 0.8;
uniform float glow_energy = 1.4;
uniform float breath : hint_range(0.0, 1.0) = 0.0;
uniform float blaze : hint_range(0.0, 1.0) = 0.0;
uniform float blaze_energy = 3.0;
// The time, for the glow's slow swell (a living ember, not a bulb).
uniform float clock = 0.0;
// The head's mesh sits about its neck pivot: this puts its grain back in
// the figure's space, so the noise runs on across the neck.
uniform vec3 obj_offset = vec3(0.0);

varying vec3 obj;
varying vec4 paint;
varying float tall;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return s;
}

// A cell-edge network for the crazing: near 1 on a crack.
float craze(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int x = -1; x <= 1; x++)
	for (int y = -1; y <= 1; y++)
	for (int z = -1; z <= 1; z++) {
		vec3 g = vec3(float(x), float(y), float(z));
		vec3 o = vec3(hash(i + g), hash(i + g + 13.1), hash(i + g + 27.7));
		float d = length(g + o - f);
		if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
	}
	return 1.0 - smoothstep(0.0, 0.06, d2 - d1);
}

void vertex() {
	obj = VERTEX + obj_offset;
	paint = COLOR;
	tall = UV2.x;
}

void fragment() {
	vec3 p = obj;
	float foot = length(fwidth(p));
	float n1 = fbm(p * 5.0);
	float n2 = fbm(p * 21.0 + 4.0);
	float n0 = fbm(p * 1.6 + vec3(5.2, 1.3, 0.7));
	float n3 = fbm(p * 52.0 + 9.0);
	// The slip: mottled, a little warmer where it is thick, a broad wash of
	// lighter and darker over it.
	vec3 c = mix(slip_low, slip, smoothstep(0.3, 0.7, n1 * 0.7 + n0 * 0.3));
	c *= 0.86 + 0.24 * n0;
	// Fire-clouds: soft grey-black smudges from the firing.
	float cloud = smoothstep(0.58, 0.78, fbm(p * 2.2 + vec3(3.1, 0.4, 7.7)));
	c = mix(c, c * vec3(0.52, 0.5, 0.49), cloud * 0.55);
	// Crazing in the slip, faded out where a pixel covers a cell.
	float cz = craze(p * 38.0) * (1.0 - smoothstep(0.004, 0.012, foot));
	c = mix(c, c * 0.74, cz * 0.35);
	// Worn through to the clay, its edge broken by the grain; flakes of
	// lost slip anywhere, rarer.
	float fine = mix(0.5, n3, 1.0 - smoothstep(0.006, 0.02, foot));
	float w = paint.g + (n2 - 0.5) * 0.8 + (n1 - 0.5) * 0.35 + (fine - 0.5) * 0.35;
	float flake = smoothstep(0.76, 0.8, fbm(p * 9.0 + 11.0)) * 0.75;
	float worn = max(smoothstep(0.5, 0.58, w), flake);
	vec3 cl = mix(clay_dark, clay, smoothstep(0.25, 0.75, n2));
	c = mix(c, cl, worn);
	// Dust on what faces up and low on the figure; grime in the folds.
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float du = clamp(smoothstep(0.2, 0.9, wn.y) * 0.45 + (1.0 - smoothstep(0.0, 0.35, tall)) * 0.35, 0.0, 1.0);
	c = mix(c, dust * (0.8 + 0.4 * n2), du * smoothstep(0.3, 0.7, n1 * 0.6 + n2 * 0.4) * 0.8);
	float gr = clamp(paint.r * (0.8 + 0.6 * n1), 0.0, 1.0);
	c = mix(c, grime, gr * 0.9);
	// The open mouth: dark inside.
	c = mix(c, vec3(0.07, 0.035, 0.025), paint.a);
	ALBEDO = c;
	ROUGHNESS = mix(0.48 + 0.12 * n2, 0.9, max(worn, gr * 0.6));
	SPECULAR = mix(0.4, 0.2, worn);
	// The underground's fill, as the stone has it.
	vec3 normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, normal.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	hemi = mix(hemi, mix(zs_under_ground, zs_under_sky, normal.y * 0.5 + 0.5) / PI, zs_under);
	vec3 em = c * hemi * hemi_fill;
	// The light inside, climbing: lit below the fill line (feet to eyes),
	// through the thin places most, a dim warm swell.
	float line = fill * eyes;
	float below = 1.0 - smoothstep(line - 0.06, line + 0.02, tall);
	float swell = 0.85 + 0.15 * sin(clock * 1.7 + n1 * 6.0);
	float thin = paint.b * (1.0 - paint.a);
	float inner = below * step(0.001, fill) * (0.1 + 0.9 * thin) * (1.0 - worn * 0.5) * (1.0 - gr * 0.7);
	em += glow_colour * inner * glow_energy * swell * (0.35 + 0.65 * fill);
	// The mouth and the eye slits glow from inside as it fills; at the
	// breath they burn.
	float slit = smoothstep(0.55, 0.85, paint.r) * smoothstep(0.7, 0.78, tall);
	em += glow_colour * (paint.a + slit * 0.6) * (fill * fill * 0.8 + breath * 2.5) * glow_energy;
	// The cry: it pours out through everything.
	em += glow_colour * (0.25 + thin + paint.a * 3.0) * blaze * blaze_energy * (0.8 + 0.2 * swell);
	EMISSION = em;
}
