shader_type canvas_item;
render_mode unshaded;
// The five translucent layers in Electron title.js, composited front to back.
// `strength` scales the lot (1 as the source; the game's front door eases it
// down at night, scripts/kit_isle/front_door.gd, so the night isle under it
// is not pressed to a black cutout).
uniform float strength = 1.0;
void fragment() {
	vec2 p = UV;
	float halo = 0.34*(1.0-clamp(length((p-vec2(0.5,0.2))/vec2(0.55,0.4))/0.72,0.0,1.0));
	float crown = p.y < 0.44 ? mix(0.40,0.06,p.y/0.44) : mix(0.06,0.0,clamp((p.y-0.44)/0.22,0.0,1.0));
	float desk = p.y < 0.50 ? mix(0.0,0.60,clamp((p.y-0.28)/0.22,0.0,1.0)) : p.y < 0.74 ? mix(0.60,0.80,(p.y-0.50)/0.24) : mix(0.80,0.62,(p.y-0.74)/0.26);
	float center = 0.74*(1.0-clamp(length((p-vec2(0.5,0.64))/vec2(0.62,0.34))/0.82,0.0,1.0));
	float foot = 0.55*clamp((p.y-0.84)/0.16,0.0,1.0);
	float alpha = 1.0-(1.0-halo)*(1.0-crown)*(1.0-desk)*(1.0-center)*(1.0-foot);
	COLOR = vec4(vec3(0.031,0.043,0.059),alpha * strength);
}
