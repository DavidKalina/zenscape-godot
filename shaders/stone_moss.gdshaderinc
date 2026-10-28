#ifndef ZS_STONE_MOSS_INC
#define ZS_STONE_MOSS_INC
// Moss and ivy grown over the stone, painted by the stone's own shader
// (shaders/gothic_stone.gdshader, the amberlands' gothic set pieces only,
// scripts/gothic_growth.gd `stone`): the overgrowth's mass at no triangle
// cost, the geometry growth left for the silhouette. In solid noise over
// the piece's own frame (its rest pose), after the weathering
// (shaders/kit_weather.gdshaderinc, whose noise it uses):
//   - thick on what faces up: wall heads, ledges, sills, set-offs, rubble,
//   - creeping down the upright faces in tongues and streaks, longer where
//     the face looks away from the sun and lower down,
//   - a ragged band thick from the ground up, climbing higher in shade,
//   - broken by the stone's courses: each block (its own face colour) takes
//     the cover a little more or less, so the edges step along the joints,
//   - thinner on the undersides and under a roof.
// Colours: dry olive and dusty green-grey, ochre where it dries on sunlit
// tops, rare dull rust, darker in the deep of a clump. Also the stone's own
// lift for these pieces (`stone_lift`, and `shade_lift` in the fill:
// shaders/folk_surface.gdshaderinc), so the inside of a nave isn't black.
// Cost: value noise only, about eight lookups a pixel, the fine ones only
// near enough to see.

uniform float moss : hint_range(0.0, 1.5) = 0.0;
// How high (m) the ground's band climbs before it thins out.
uniform float moss_low = 10.0;
// The tongues' threshold on their noise (lower: more and longer).
uniform float moss_tongue = 0.6;
uniform float stone_lift = 1.0;
uniform float shade_lift = 0.0;
uniform vec3 moss_olive : source_color = vec3(0.37, 0.36, 0.21);
uniform vec3 moss_grey : source_color = vec3(0.42, 0.43, 0.35);
uniform vec3 moss_ochre : source_color = vec3(0.53, 0.45, 0.25);
uniform vec3 moss_rust : source_color = vec3(0.42, 0.29, 0.19);
uniform vec3 moss_deep : source_color = vec3(0.19, 0.2, 0.12);

// Grows moss over colour `c` (linear) at rest point `p`; `n` the view-space
// normal (bumped in place), `wn` the world normal, `vtx` the view-space
// position, `shelter` 0 open air to 1 under a roof, `vcol` the face's own
// colour (the block it is), `sun` toward the key light. Returns how much
// rougher.
float stone_moss(inout vec3 c, inout vec3 n, vec3 wn, vec3 p, vec3 vtx, float shelter, vec3 vcol, vec3 sun) {
	c *= stone_lift;
	if (moss <= 0.0) return 0.0;
	float px = length(fwidth(p));
	float f_mid = 1.0 - smoothstep(0.08, 0.45, px);
	float f_fine = 1.0 - smoothstep(0.015, 0.06, px);

	float up = clamp(wn.y, 0.0, 1.0);
	float down = clamp(-wn.y, 0.0, 1.0);
	float side = 1.0 - abs(wn.y);
	float shade = 1.0 - clamp(dot(wn, sun), 0.0, 1.0);
	// The block: its own colour hashed, so each takes the cover its own way.
	float blk = kw_h31(floor(vcol * 251.0) + vec3(3.1, 7.7, 1.3));

	float big = kw_fbm(p * 0.21 + 91.0);
	float mid = kw_noise(p * 0.9 + 37.0);
	float fine = f_mid > 0.0 ? kw_noise(p * 3.7 + 13.0) : 0.5;
	float breakup = big * 0.6 + mid * 0.3 + (fine - 0.5) * 0.25 * f_mid + 0.05;

	// The tops: near-whole, holed where the breakup is lowest.
	float on_top = smoothstep(0.28, 0.62, up);
	float top_cover = on_top * smoothstep(0.24, 0.36, breakup + (blk - 0.5) * 0.12 + 0.08 * shade);

	// Tongues down the faces: noise stretched tall, its edge ragged near to.
	float tall = kw_fbm(vec3(p.x * 0.65, p.y * 0.06, p.z * 0.65) + 17.0);
	float drip = kw_noise(vec3(p.x * 2.4, p.y * 0.32, p.z * 2.4) + 5.0);
	float tongue_n = tall * 0.72 + drip * 0.28;
	float low_band = 1.0 - smoothstep(moss_low * (0.25 + 0.45 * shade), moss_low * (0.7 + 0.8 * shade), p.y + (big - 0.5) * 7.0);
	float thr = moss_tongue - 0.12 * shade - 0.16 * low_band + (blk - 0.5) * 0.14 - 0.06 * (moss - 1.0);
	// Whole stretches of a wall left bare, where the slowest noise is low.
	float reach = smoothstep(0.24, 0.42, big + 0.1 * shade);
	float tongues = smoothstep(thr, thr + 0.07, tongue_n) * side * reach;
	// The ground's band, thick and ragged.
	float ground = low_band * smoothstep(0.3, 0.42, breakup + 0.15 * shade + (blk - 0.5) * 0.1) * side;

	float cover = max(top_cover, max(tongues, ground));
	cover *= 1.0 - down * 0.65;
	cover *= 1.0 - shelter * 0.35;
	cover = clamp(cover * min(moss, 1.0), 0.0, 1.0);
	// (No early out past here: the bump takes derivatives, which need every
	// pixel of a quad to run them.)

	// Its colour: olive and grey in broad patches, ochre drying on sunlit
	// tops, rare dull rust, deep in its clumps and down in the shade.
	float hue = smoothstep(0.35, 0.65, kw_noise(p * 0.33 + 23.0));
	vec3 col = mix(moss_olive, moss_grey, hue);
	float dry = smoothstep(0.55, 0.8, kw_noise(p * 0.45 + 51.0)) * (0.35 + 0.65 * up * (1.0 - shade));
	col = mix(col, moss_ochre, clamp(dry, 0.0, 1.0) * 0.6);
	float rust = smoothstep(0.8, 0.88, kw_noise(p * 0.27 + 77.0));
	col = mix(col, moss_rust, rust * 0.55);
	float clump = f_mid > 0.0 ? kw_noise(p * 4.5 + 3.0) * 0.65 + kw_noise(p * 11.0 + 8.0) * 0.35 : 0.5;
	float tuft = f_fine > 0.0 ? kw_noise(p * 21.0 + 9.0) : 0.5;
	float depth = clamp(0.12 * shade + 0.35 * down + (0.5 - clump) * 0.6 * f_mid, 0.0, 1.0);
	col = mix(col, moss_deep, depth);
	col *= mix(1.0, 0.78 + 0.4 * clump, f_mid) * (0.88 + 0.24 * tuft * f_fine + 0.12 * (1.0 - f_fine));
	// The edge of a patch thins in clumps (stone showing through) before it ends.
	float body = smoothstep(0.0, 0.5, cover) * mix(1.0, smoothstep(0.25, 0.55, clump + cover * 0.6 - 0.2), f_mid * (1.0 - smoothstep(0.6, 1.0, cover)));
	c = mix(c, col, body);

	// The normal: the clumps raised a little.
	float height = cover * ((clump - 0.5) * 0.7 + (tuft - 0.5) * 0.3 * f_fine) * 0.05;
	vec3 sx = dFdx(vtx);
	vec3 sy = dFdy(vtx);
	vec3 r1 = cross(sy, n);
	vec3 r2 = cross(n, sx);
	float det = dot(sx, r1);
	vec3 grad = sign(det) * (dFdx(height) * r1 + dFdy(height) * r2);
	vec3 bumped = abs(det) * n - 0.8 * f_mid * grad;
	if (dot(bumped, bumped) > 1e-20) n = normalize(bumped);
	return body * 0.15;
}
#endif
