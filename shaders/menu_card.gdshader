shader_type canvas_item;
render_mode unshaded;
// A title card's cloth and coin window (Claude Design "ZenScape Main Menu
// Cards", face 5d Coin; scripts/menu_card.gd). Lengths are the card's design
// pixels (240 x 336); the rect this draws on covers the card.
//
// Cloth: #4e463b, a 1px dark thread every 3px across and a faint light one
// every 4px down, a 1px light rim along the top and a 2px dark one along the
// foot. Coin (`coin`): a 192px window round (120,124), its sky top to low by
// 70% down, the haze and sun, the hill, a 1px dark ring outside it and a soft
// shadow inside its top.
uniform vec2 card = vec2(240.0,336.0);
uniform float radius = 16.0;
uniform bool coin = true;
uniform bool haze_on = false;
uniform vec4 top : source_color = vec4(0.545,0.584,0.635,1.0);
uniform vec4 low : source_color = vec4(0.769,0.749,0.698,1.0);
uniform vec4 haze : source_color = vec4(1.0,0.953,0.839,0.69);
uniform vec4 sun : source_color = vec4(1.0,0.953,0.839,1.0);
uniform vec4 hill : source_color = vec4(0.31,0.541,0.353,1.0);

const vec3 CLOTH = vec3(0.306,0.275,0.231);
const vec2 WINDOW = vec2(120.0,124.0);
const float WINDOW_R = 96.0;

float round_rect(vec2 p, vec2 size, float r) {
	vec2 q = abs(p-size*0.5)-size*0.5+vec2(r);
	return length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-r;
}

// How much of a pixel `w` wide round `x` a thread `on` wide every `period` covers.
float threads(float x, float period, float on, float w) {
	w = max(w,1e-3);
	float a = x-w*0.5;
	float b = x+w*0.5;
	float fa = floor(a/period)*on+clamp(mod(a,period),0.0,on);
	float fb = floor(b/period)*on+clamp(mod(b,period),0.0,on);
	return clamp((fb-fa)/w,0.0,1.0);
}

vec4 over(vec4 under, vec3 colour, float alpha) {
	return vec4(mix(under.rgb,colour,alpha),under.a);
}

void fragment() {
	vec2 p = UV*card;
	vec2 w = fwidth(p);
	float aa = max(w.x,w.y);
	float body = round_rect(p,card,radius);
	vec4 c = vec4(CLOTH,1.0-smoothstep(-aa*0.5,aa*0.5,body));
	// repeating-linear-gradient(0deg ...): from the foot up.
	c = over(c,vec3(0.078,0.055,0.031),0.16*threads(card.y-p.y,3.0,1.0,w.y));
	c = over(c,vec3(1.0,0.941,0.843),0.04*threads(p.x,4.0,1.0,w.x));
	// The rims: inside the cloth, outside it moved 1px down / 2px up.
	c = over(c,vec3(1.0,0.941,0.843),0.1*smoothstep(-aa*0.5,aa*0.5,round_rect(p-vec2(0.0,1.0),card,radius)));
	c = over(c,vec3(0.078,0.055,0.031),0.25*smoothstep(-aa*0.5,aa*0.5,round_rect(p+vec2(0.0,2.0),card,radius)));
	if (coin) {
		float r = length(p-WINDOW);
		// box-shadow 0 0 0 1px rgba(20,14,8,.5): a ring just outside.
		float ring = smoothstep(WINDOW_R-aa*0.5,WINDOW_R+aa*0.5,r)*(1.0-smoothstep(WINDOW_R+1.0-aa*0.5,WINDOW_R+1.0+aa*0.5,r));
		c = over(c,vec3(0.078,0.055,0.031),0.5*ring);
		float inside = 1.0-smoothstep(WINDOW_R-aa*0.5,WINDOW_R+aa*0.5,r);
		if (inside > 0.0) {
			vec2 q = p-(WINDOW-vec2(WINDOW_R));
			vec3 sky = mix(top.rgb,low.rgb,clamp(q.y/(WINDOW_R*2.0*0.7),0.0,1.0));
			if (haze_on) {
				// radial-gradient(circle, haze 0%, transparent 66%) in a 172px box at (10,-14).
				float h = 1.0-clamp(length(q-vec2(96.0,72.0))/(0.66*86.0*sqrt(2.0)),0.0,1.0);
				sky = mix(sky,haze.rgb,haze.a*h);
			}
			float s = 1.0-smoothstep(34.0-aa*0.5,34.0+aa*0.5,length(q-vec2(96.0,64.0)));
			sky = mix(sky,sun.rgb,s);
			vec2 e = (q-vec2(96.0,222.0))/vec2(136.0,90.0);
			float hl = 1.0-smoothstep(1.0-aa/90.0,1.0+aa/90.0,length(e));
			sky = mix(sky,hill.rgb,hl);
			// inset 0 2px 8px rgba(10,8,6,.25)
			float shade = smoothstep(-8.0,8.0,length(p-WINDOW-vec2(0.0,2.0))-WINDOW_R);
			sky = mix(sky,vec3(0.039,0.031,0.024),0.25*shade);
			c.rgb = mix(c.rgb,sky,inside);
		}
	}
	COLOR = c;
}
