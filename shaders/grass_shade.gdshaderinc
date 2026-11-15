#ifndef ZS_GRASS_SHADE
#define ZS_GRASS_SHADE
// What a cast shadow leaves of the sun on grass and ground. The land takes
// its sky fill as emission and ambient is off, so where a tree or a hill
// shuts the sun out, only that thin fill was left: near black, and navy.
// This puts back a share of the sun's own strength in the sky's cool colour,
// only where the sun is shut out (`shade`, 1 in shadow or turned from the
// sun, 0 in full sun), so lit pixels are untouched. Added to DIFFUSE_LIGHT
// (Godot multiplies it by the albedo), from light(), for the directional
// light only.
const float ZS_SHADE_KEEP = 0.14;
// How cool the lift runs (0 the sun's colour, 1 the sky fill's hue).
const float ZS_SHADE_COOL = 0.3;
// At a low sun the lift keeps this share (whole hillsides stand in shade
// then, and a full lift turned them brighter than the trees on them);
// `sun_up` is the sun's height (the light's world y, 0 at the horizon).
const float ZS_SHADE_LOW = 0.4;
vec3 zs_grass_shade_lift(vec3 light_color, vec3 sky, float shade, float sun_up) {
	shade *= mix(ZS_SHADE_LOW, 1.0, smoothstep(0.05, 0.45, sun_up));
	float l = dot(light_color, vec3(0.2126, 0.7152, 0.0722));
	vec3 cool = sky / max(dot(sky, vec3(0.2126, 0.7152, 0.0722)), 1.0e-3);
	return mix(vec3(1.0), cool, ZS_SHADE_COOL) * l * ZS_SHADE_KEEP * shade / PI;
}
float zs_sch(float u) {
	float m = clamp(1.0 - u, 0.0, 1.0);
	float m2 = m * m;
	return m2 * m2 * m;
}
// Godot's Burley diffuse and Schlick-GGX specular, as the default light does
// them (a light() replaces the default), for a surface with no light() of its
// own. Returns the diffuse in .xyz's place via the out parameters.
void zs_grass_light(vec3 normal, vec3 light, vec3 view, vec3 light_color, float atten, float rough, float spec, out vec3 diffuse, out vec3 specular) {
	vec3 h = normalize(light + view);
	float nl = clamp(dot(normal, light), 0.0, 1.0);
	float nv = max(dot(normal, view), 0.0001);
	float nh = clamp(dot(normal, h), 0.0, 1.0);
	float lh = clamp(dot(light, h), 0.0, 1.0);
	float fd90m1 = 2.0 * lh * lh * rough - 0.5;
	float burley = (1.0 + fd90m1 * zs_sch(nv)) * (1.0 + fd90m1 * zs_sch(nl));
	vec3 energy = light_color * atten;
	diffuse = energy * nl * burley / PI;
	float a = max(rough * rough, 0.002025);
	float a2 = a * a;
	float den = nh * nh * (a2 - 1.0) + 1.0;
	float d = a2 / (PI * den * den);
	float vis = 0.5 / max(nl * sqrt(a2 + (1.0 - a2) * nv * nv) + nv * sqrt(a2 + (1.0 - a2) * nl * nl), 0.0001);
	float f0 = 0.16 * spec * spec;
	float fres = f0 + (1.0 - f0) * zs_sch(lh);
	specular = energy * nl * d * vis * fres;
}
#endif
