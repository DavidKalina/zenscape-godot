shader_type canvas_item;
render_mode unshaded;
// A title card's face (a SubViewport, scripts/menu_card.gd) set in the scene
// tilted in perspective: `to_card` takes a point of the drawn rect back to
// the card's design pixels (the inverse of the card's homography), so the
// face is sampled as if the card leaned toward the pointer. Under it, the
// card's drop shadow (0 16px 34px), which leans with it; over it, the sheen
// that follows the pointer.
uniform sampler2D face : source_color, filter_linear, repeat_disable;
uniform mat3 to_card;
uniform vec2 card = vec2(240.0,336.0);
uniform float radius = 16.0;
uniform float shadow_alpha = 0.45;
uniform vec2 sheen_at = vec2(0.5,0.35);
uniform float sheen = 0.0;
uniform float opacity = 1.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

float round_rect(vec2 p, vec2 size, float r) {
	vec2 q = abs(p-size*0.5)-size*0.5+vec2(r);
	return length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-r;
}

void fragment() {
	vec3 h = to_card*vec3(local,1.0);
	if (h.z <= 0.0) discard;
	vec2 p = h.xy/h.z;
	vec2 w = fwidth(p);
	float aa = max(max(w.x,w.y),1e-3);
	float shadow = shadow_alpha*(1.0-smoothstep(-17.0,17.0,round_rect(p-vec2(0.0,16.0),card,radius)));
	float body = 1.0-smoothstep(-aa*0.5,aa*0.5,round_rect(p,card,radius));
	vec3 colour = texture(face,clamp(p/card,vec2(0.0),vec2(1.0))).rgb;
	// radial-gradient(circle at sheen_at, rgba(255,246,224,sheen) 0%, transparent 58%),
	// the circle reaching the farthest corner.
	vec2 at = sheen_at*card;
	float reach = length(max(at,card-at))*0.58;
	colour = mix(colour,vec3(1.0,0.965,0.878),sheen*clamp(1.0-length(p-at)/reach,0.0,1.0));
	float alpha = body+shadow*(1.0-body);
	vec3 shade = vec3(0.039,0.031,0.047);
	vec3 rgb = alpha > 0.0 ? (colour*body+shade*shadow*(1.0-body))/alpha : vec3(0.0);
	COLOR = vec4(rgb,alpha*opacity);
}
