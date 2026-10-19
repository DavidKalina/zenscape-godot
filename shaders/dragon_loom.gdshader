shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// The dragon looming out of a whiteout's murk (scripts/dragon_glimpse.gd):
// a second pass over its hide and wings, drawn after the murk's sheet
// (shaders/storm_whiteout.gdshader, which greys all past a few tens of m),
// that gives its shape back as a darker shade in the murk: near, a deep
// dark shape whose edges go soft; farther, fainter and greyer, until a
// hundred m or so off it is lost. It never draws it crisp: the shade is
// the murk's own colour darkened, not the hide. In a flash (`lit`) the
// murk behind it blooms (the flash is right behind it from the eye), so it
// is a near-black silhouette against the bloom, seen much farther
// (lit_near, lit_reach), its edges still softened by the murk's wisps.

// How thick the murk is (0 to 1) and how lit the dragon is now (0 to 1).
uniform float murk = 0.0;
uniform float lit = 0.0;
// The shade at its nearest and what it fades to with distance.
uniform vec3 shade : source_color = vec3(0.07, 0.065, 0.08);
uniform vec3 murk_colour : source_color = vec3(0.3, 0.31, 0.33);
// Within `near` m it is as dark as it gets; it fades over `reach` m past.
uniform float near = 14.0;
uniform float reach = 55.0;
uniform float strength = 0.85;
// In a full flash: as dark as it gets within `lit_near` m, fading over
// `lit_reach` m past; the silhouette's strength.
uniform float lit_near = 45.0;
uniform float lit_reach = 600.0;
uniform float lit_strength = 1.0;
// The murk's wisps passing between it and the eye (m, their size).
uniform float wisp = 7.0;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	// A hair nearer than its own hide (reverse z: larger is nearer), so this
	// pass meets its own depth and only its front face shows.
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	POSITION.z *= 1.0005;
}

void fragment() {
	float d = length(VERTEX);
	float k = clamp(murk, 0.0, 1.0);
	// Seen at all (`lit` past half), it is a full silhouette: the bloom fades
	// round it, it does not fade into a ghost.
	float l = smoothstep(0.0, 0.5, lit);
	float fade = exp(-max(d - mix(near, lit_near, l), 0.0) / mix(reach, lit_reach, l));
	// Edges seen side-on go soft, as a shape in fog does.
	float face = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float soft = mix(mix(0.45, 0.85, l), 1.0, sqrt(face));
	// Wisps of the murk between: a few m into the view from it, in the
	// world, racing past; where one is thick the shape is half lost.
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX * 0.8, 1.0)).xyz;
	float n = noise(world / wisp + vec3(TIME * 0.6, TIME * 0.25, 0.0)) * 0.65
		+ noise(world / (wisp * 0.4) + vec3(0.0, TIME * 0.9, TIME * 0.4)) * 0.35;
	float through = mix(1.0, mix(0.35, 0.84, l), smoothstep(0.35, 0.8, n));
	// Lit from behind, it is all shade: the distance thins it (alpha), and
	// what shows through is the bloom.
	ALBEDO = mix(murk_colour * 0.6, shade, max(fade, l));
	ALPHA = clamp(mix(strength, lit_strength, l) * k * fade * soft * through, 0.0, 1.0);
}
