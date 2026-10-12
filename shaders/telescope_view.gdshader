shader_type canvas_item;
// The view through the pilot's telescope (scripts/telescope.gd): one big
// round lens, a faint warm tint inside it, a gentle vignette toward its
// edge, a thin soft brass rim, and dark round it. Lengths are in screen
// heights from the middle, as the script's are.

uniform float shown = 0.0;
uniform float aspect = 1.7778;
uniform float radius = 0.66;

void fragment() {
	vec2 p = (UV-0.5)*vec2(aspect,1.0);
	float d = length(p)-radius;
	float outside = smoothstep(-0.002,0.01,d);
	float rim = 1.0-smoothstep(0.0,0.009,abs(d+0.007));
	// Lit from above: the rim's top catches the light, its foot is in shade.
	float lit = 0.75+0.25*(-p.y/max(length(p),0.001));
	float vignette = smoothstep(-0.26,0.0,d);
	vec4 c = vec4(0.32,0.25,0.12,0.05);
	c = mix(c,vec4(0.015,0.012,0.008,1.0),vignette*0.5);
	c = mix(c,vec4(vec3(0.66,0.49,0.24)*lit,0.92),rim*0.8);
	c = mix(c,vec4(0.012,0.01,0.008,1.0),outside);
	COLOR = vec4(c.rgb,c.a*shown);
}
