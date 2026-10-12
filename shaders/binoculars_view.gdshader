shader_type canvas_item;
// The view through the pilot's binoculars (scripts/binoculars.gd): two soft
// circles side by side, dark round them, a faint shade just inside their rim.
// Lengths are in screen heights from the middle, as the script's are.

uniform float shown = 0.0;
uniform float aspect = 1.7778;
uniform float radius = 0.46;
uniform float apart = 0.2;

void fragment() {
	vec2 p = (UV-0.5)*vec2(aspect,1.0);
	float d = min(length(p-vec2(-apart,0.0)),length(p+vec2(-apart,0.0)))-radius;
	float dark = smoothstep(-0.06,0.025,d);
	float rim = smoothstep(-0.22,0.0,d)*0.28;
	COLOR = vec4(0.012,0.01,0.008,max(dark,rim)*shown);
}
