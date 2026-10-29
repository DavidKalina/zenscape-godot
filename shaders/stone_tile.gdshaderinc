#ifndef ZS_STONE_TILE_INC
#define ZS_STONE_TILE_INC
// The ruins' cut stone: a tile of coursed ashlar sculpted and baked in
// Blender (art/blender/ruin_stone/ruin_stone_build.py), laid over the kit's
// blocks in the piece's own frame (its stone stands still) from three sides,
// each face taking the side it most faces. It gives the face its joints,
// worn arrises, chips and spalls (the normal), its crevices' shade (the
// ambient occlusion, which darkens the colour and so the shade fill that no
// SSAO reaches), each stone its own tone and the mortar darker.
//   ruin_stone_normal  RGB the normal: x along u, y along v (the image's up)
//   ruin_stone_mask    R occlusion (1 open), G height, B the stone's tone (0 mortar)
// RuinKit Build.materials sets the maps; `stone_tile` 0 is the old stone
// (--ruin-stone=old).
uniform sampler2D stone_tile_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_tile_mask : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float stone_tile = 0.0;
// The tile's side in metres (the bake's TILE).
uniform float stone_tile_size = 2.4;
uniform float stone_tile_bump = 1.0;
uniform float stone_tile_ao = 0.85;
uniform float stone_tile_tone = 0.3;
uniform float stone_tile_mortar = 0.45;
varying vec3 stone_tile_n;

// The three sides' samples blended; `p` and `ln` the point and normal in the
// piece's frame. Returns the normal's offset (piece frame, along the face)
// and darkens/tones `base`.
vec3 stone_tile_apply(inout vec3 base, vec3 p, vec3 ln) {
	vec3 an = normalize(ln);
	vec3 w = pow(abs(an), vec3(6.0));
	w /= (w.x + w.y + w.z);
	float k = 1.0 / stone_tile_size;
	// Each side: u along T, v (the image's up) along B; sampled at
	// (p.T, -p.B) so that the image's up runs along +B.
	const vec3 TX = vec3(0.0, 0.0, 1.0); const vec3 BX = vec3(0.0, 1.0, 0.0);
	const vec3 TY = vec3(1.0, 0.0, 0.0); const vec3 BY = vec3(0.0, 0.0, 1.0);
	const vec3 TZ = vec3(1.0, 0.0, 0.0); const vec3 BZ = vec3(0.0, 1.0, 0.0);
	vec2 ux = vec2(dot(p, TX), -dot(p, BX)) * k;
	vec2 uy = vec2(dot(p, TY), -dot(p, BY)) * k + vec2(0.37, 0.61);
	vec2 uz = vec2(dot(p, TZ), -dot(p, BZ)) * k + vec2(0.53, 0.0);
	vec3 off = vec3(0.0);
	vec3 m = vec3(0.0);
	if (w.x > 0.01) {
		vec2 t = texture(stone_tile_normal, ux).xy * 2.0 - 1.0;
		off += (t.x * TX + t.y * BX) * w.x;
		m += texture(stone_tile_mask, ux).rgb * w.x;
	}
	if (w.y > 0.01) {
		vec2 t = texture(stone_tile_normal, uy).xy * 2.0 - 1.0;
		off += (t.x * TY + t.y * BY) * w.y;
		m += texture(stone_tile_mask, uy).rgb * w.y;
	}
	if (w.z > 0.01) {
		vec2 t = texture(stone_tile_normal, uz).xy * 2.0 - 1.0;
		off += (t.x * TZ + t.y * BZ) * w.z;
		m += texture(stone_tile_mask, uz).rgb * w.z;
	}
	m /= max(1e-4, (w.x > 0.01 ? w.x : 0.0) + (w.y > 0.01 ? w.y : 0.0) + (w.z > 0.01 ? w.z : 0.0));
	float mortar = 1.0 - smoothstep(0.03, 0.12, m.b);
	base *= mix(1.0, m.r, stone_tile_ao * stone_tile);
	// Each stone its own tone (its bake 0.2..1, about 0.6 on the mean), the
	// mortar between them darker.
	float own = 1.0 + (m.b - 0.6) * stone_tile_tone * 2.0;
	base *= mix(1.0, mix(own, 1.0 - stone_tile_mortar, mortar), stone_tile);
	return off * stone_tile_bump * stone_tile;
}
#endif
