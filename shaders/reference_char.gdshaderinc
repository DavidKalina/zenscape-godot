// The burnt look, modelled on reference_autumn.gdshaderinc. `char` 0..1 browns,
// curls and finally skeletonises foliage; `burn` 0..1 is live flame heat on the
// mesh and adds an ember glow. Both arrive as INSTANCE_CUSTOM.rg, written per
// record by GardenView.set_object_fire, so (0, 0) costs one comparison and
// leaves the surface exactly as it was before fire existed.
#ifndef ZS_REFERENCE_CHAR_INCLUDED
#define ZS_REFERENCE_CHAR_INCLUDED

// Linear forms of the design colours: dead-leaf brown #3a2a1e, charcoal
// #141210, ember #ff6a1a.
const vec3 ZS_CHAR_BROWN = vec3(0.0423, 0.0231, 0.0130);
const vec3 ZS_CHAR_COAL = vec3(0.0070, 0.0061, 0.0052);
const vec3 ZS_CHAR_EMBER = vec3(1.0000, 0.1442, 0.0103);

float zs_char_hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

// One value per leaf clump. Quantised in object space so a whole tuft browns,
// curls and vanishes together instead of dissolving triangle by triangle.
float zs_char_clump(vec3 local_vertex) {
	return zs_char_hash(floor(local_vertex * 1.7));
}

// Per-record flicker seed from the placement root, so neighbouring trees do not
// pulse in lockstep.
float zs_char_seed(vec2 root) {
	return fract(sin(dot(root, vec2(12.9898, 78.233))) * 43758.5453);
}

// Vertex stage. Over char 0 -> 0.5 the foliage curls in toward the stem and
// sags, an exaggerated version of the wet droop; over 0.5 -> 1 what is left
// collapses onto the branches. `foliage` is false for trunks, deadwood and
// stone, which darken but must never move or thin.
void zs_char_curl(inout vec3 vertex, float amount, float clump, bool foliage) {
	if (!foliage || amount <= 0.004) return;
	float curl = clamp(amount * 2.0, 0.0, 1.0);
	float bare = smoothstep(0.5, 1.0, amount);
	float wobble = 0.55 + 0.90 * clump;
	vertex.xz *= 1.0 - clamp((0.11 * curl + 0.42 * bare) * wobble, 0.0, 0.88);
	vertex.y -= max(vertex.y, 0.0) * clamp((0.035 * curl + 0.16 * bare) * wobble, 0.0, 0.55);
}

// Alpha scissor for reference_surface: true once this clump has burned away.
// At char 1 seven clumps in eight are gone, which is the skeleton silhouette.
// The layered canopy leans on `leaf_thinness` instead and never calls this.
bool zs_char_gone(float amount, float clump, bool foliage) {
	return foliage && clump < smoothstep(0.45, 0.90, amount) * 0.88;
}

// Fragment stage. `scorch` is how far roughness should be driven to 1 and
// `ember_light` is the glow term for EMISSION; the same glow is folded into the
// albedo because bloom is off under the Balanced preset, so brightness has to
// come from the colour itself. The ember rides the silhouette - facets turning
// away from the eye - which is where a real leaf edge glows.
void zs_char_paint(inout vec3 color, out float scorch, out vec3 ember_light,
		vec3 world_position, vec3 face_normal, float amount, float ember, float seed, float time) {
	scorch = 0.0;
	ember_light = vec3(0.0);
	if (amount > 0.004) {
		// Luminance-keyed like the autumn turn, so the shading baked into the
		// vertex colours (dark leaf roots, bright tips) survives the burn.
		float lum = dot(color, vec3(0.30, 0.55, 0.15));
		vec3 target = mix(ZS_CHAR_BROWN, ZS_CHAR_COAL, smoothstep(0.45, 0.95, amount));
		target *= 0.55 + 0.70 * clamp(lum * 3.2, 0.0, 1.0);
		// Dead brown by char 0.4, charcoal by 1. Green survives nothing here:
		// half-charred leaves must not still read as foliage from a distance.
		scorch = clamp(amount * 2.6, 0.0, 1.0);
		color = mix(color, target, scorch);
	}
	if (ember > 0.004) {
		// Two beats of flicker so the glow breathes rather than strobes.
		float flicker = 0.5 + 0.5 * sin(time * (5.5 + 6.0 * seed) + seed * 41.0)
			* (0.6 + 0.4 * sin(time * (2.3 + 1.7 * seed) + seed * 17.0));
		// Scattered coals, drifting: only about a third of the surface is ever
		// alight at once, weighted toward facets turning away from the eye,
		// which is where a leaf shows its burning edge.
		float coals = zs_noise(world_position.xz * 9.0 + vec2(time * 0.9, world_position.y * 6.0));
		vec3 to_eye = normalize(zs_camera_position - world_position);
		float rim = 1.0 - abs(dot(normalize(face_normal), to_eye));
		float edge = smoothstep(0.70, 0.97, coals) * (0.35 + 0.65 * rim);
		// Coals bank up as the leaves die back and dim once there is nothing
		// left to burn, so the browning underneath still reads through them.
		float phase = smoothstep(0.03, 0.28, amount) * (1.0 - 0.5 * smoothstep(0.70, 1.0, amount));
		float glow = clamp(ember, 0.0, 1.0) * (0.6 + 0.4 * flicker)
			* (0.03 + 0.97 * edge) * mix(0.35, 1.0, phase) * 0.34;
		color = mix(color, ZS_CHAR_EMBER, clamp(glow, 0.0, 1.0));
		ember_light = ZS_CHAR_EMBER * glow * 2.6;
	}
}

#endif
