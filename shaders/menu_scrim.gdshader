shader_type canvas_item;
render_mode unshaded;
// The main menu's scrim (scripts/endless/main_menu.gd): the old title's
// (git tag archive/before-the-cut, shaders/title_scrim.gdshader) lightened
// for a menu over the parked plane, so the plane in the middle stays clear:
// a crown of shade behind the wordmark, a soft foot under the picks and a
// light vignette, composited as the old one's layers were. `strength`
// scales the lot.
uniform float strength = 1.0;
void fragment() {
	vec2 p = UV;
	float halo = 0.30*(1.0-clamp(length((p-vec2(0.5,0.17))/vec2(0.5,0.22))/0.9,0.0,1.0));
	float crown = p.y < 0.36 ? mix(0.22,0.0,p.y/0.36) : 0.0;
	float foot = 0.48*smoothstep(0.66,1.0,p.y);
	float vignette = 0.32*smoothstep(0.55,1.05,length((p-vec2(0.5,0.52))*vec2(1.25,1.0)));
	float alpha = 1.0-(1.0-halo)*(1.0-crown)*(1.0-foot)*(1.0-vignette);
	COLOR = vec4(vec3(0.031,0.043,0.059),alpha*strength);
}
