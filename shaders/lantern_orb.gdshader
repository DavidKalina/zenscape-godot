shader_type canvas_item;
// A Lantern mood orb (scripts/lantern_mood.gd): a tiny glass world, sky over a
// horizon glow over ground, with sphere shading, a light rim and a dark edge
// so it reads on snow and on grass alike.
uniform vec4 sky : source_color = vec4(0.47, 0.67, 0.8, 1.0);
uniform vec4 glow : source_color = vec4(0.95, 0.87, 0.73, 1.0);
uniform vec4 ground : source_color = vec4(0.36, 0.62, 0.33, 1.0);
uniform float lit = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float horizon = 0.2 + 0.035 * sin(p.x * 3.1 + 0.6);
	vec3 c = mix(sky.rgb, glow.rgb, smoothstep(-0.7, horizon, p.y));
	c = mix(c, ground.rgb, smoothstep(horizon, horizon + 0.05, p.y));
	c *= 1.0 - 0.38 * pow(r, 3.0);
	c += vec3(0.4) * smoothstep(0.42, 0.0, length(p - vec2(-0.34, -0.46)));
	float rim = smoothstep(0.76, 0.88, r) * (1.0 - smoothstep(0.88, 0.92, r));
	c = mix(c, vec3(1.0, 0.97, 0.92), rim * (0.4 + 0.4 * lit));
	float edge = smoothstep(0.9, 0.93, r);
	c = mix(c, vec3(0.03, 0.07, 0.09), edge * 0.85);
	COLOR = vec4(c, (1.0 - smoothstep(0.97, 1.0, r)) * COLOR.a);
}
