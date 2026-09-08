// Soft cellular light ridges, anchored to the submerged surface in world space.
float zs_pool_caustics(vec2 point, float time) {
	vec2 p = point * 2.8;
	p += vec2(sin(p.y*1.8 + time*0.23),sin(p.x*1.6-time*0.19))*0.24;
	vec2 cell = floor(p);
	vec2 local = fract(p);
	float first = 8.0;
	float second = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			vec2 id = cell + offset;
			vec2 seed = fract(sin(vec2(dot(id,vec2(127.1,311.7)),dot(id,vec2(269.5,183.3)))) * 43758.5453);
			vec2 center = 0.5 + 0.28 * sin(seed * 6.283185 + time * 0.38);
			float distance = length(offset + center - local);
			if (distance < first) { second = first; first = distance; }
			else if (distance < second) { second = distance; }
		}
	}
	float patches = smoothstep(-0.15,0.65,sin(point.x*1.2+time*0.21)*sin(point.y*1.5-time*0.13));
	return (1.0 - smoothstep(0.015, 0.18, second-first)) * patches;
}
