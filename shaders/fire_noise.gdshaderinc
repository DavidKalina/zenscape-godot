#ifndef ZS_FIRE_NOISE
#define ZS_FIRE_NOISE
// Value noise shared by the three fire sprites. Cheap enough to run on 384
// add-blended quads: one hash, four taps, three octaves.
float zs_fire_hash(vec2 p) {
	p = fract(p*vec2(123.34,456.21));
	p += dot(p,p+45.32);
	return fract(p.x*p.y);
}

float zs_fire_value(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	float a = zs_fire_hash(i);
	float b = zs_fire_hash(i+vec2(1.0,0.0));
	float c = zs_fire_hash(i+vec2(0.0,1.0));
	float d = zs_fire_hash(i+vec2(1.0,1.0));
	return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
}

float zs_fire_fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.55;
	for (int i = 0; i < 3; i++) {
		sum += zs_fire_value(p)*amp;
		p = p*2.07+vec2(17.0,-11.0);
		amp *= 0.5;
	}
	return sum;
}
#endif
