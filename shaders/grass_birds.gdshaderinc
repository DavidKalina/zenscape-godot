// The grass flocks' flight (scripts/endless/grass_birds.gd), for both looks:
// each bird's whole life is worked out here from what was written once, at
// its burst, so a wave costs the CPU nothing while it flies.
//
// A MultiMesh instance's transform holds no transform: its first column is
// the launch velocity, its second the velocity it eases to, its third the
// sway's axis and reach, its origin the spot in the grass. INSTANCE_CUSTOM is
// (start time, seed, size, life). The node stands at the world's origin.
//
// `clock` runs in the birds' own step, so a pause stops them. A bird not yet
// off, or done, draws nothing.

uniform float clock = 0.0;
// The wings' hinge on the mesh (mesh units, right wing), the wrist's reach
// past it, how far the hand bends at the wrist, and how much of the wing
// folds in on the upstroke. The song body's wing is one stiff blade.
uniform vec3 shoulder = vec3(0.045,0.0,0.0);
uniform float wrist = 0.2;
uniform float hand = 0.75;
uniform float fold = 0.4;

const float TAU_ = 6.2831853;
// The ease to cruise (1/s).
const float EASE = 1.7;
// Wing beats a second at the burst and flying, and how fast the one eases to
// the other (1/s).
const float BEAT_BURST = 17.0;
const float BEAT_FLY = 8.0;
const float BEAT_EASE = 2.2;
// The sway's rate (rad/s).
const float SWAY = 2.3;
// Seconds to come up out of the grass full size, and to go at the end.
const float RISE = 0.07;
const float FADE = 0.5;

void vertex() {
	float seed = INSTANCE_CUSTOM.g;
	float size = INSTANCE_CUSTOM.b;
	float life = INSTANCE_CUSTOM.a;
	float age = clock-INSTANCE_CUSTOM.r;
	if (size <= 0.0 || age < 0.0 || age > life) {
		VERTEX = vec3(0.0);
		NORMAL = vec3(0.0,1.0,0.0);
	} else {
		vec3 launch = MODEL_MATRIX[0].xyz;
		vec3 away = MODEL_MATRIX[1].xyz;
		vec3 sway = MODEL_MATRIX[2].xyz;
		vec3 at = MODEL_MATRIX[3].xyz;

		// Launch speed eased off to the bird's own way, and a slow sway across it.
		float e = exp(-age*EASE);
		float sw = SWAY*age+seed*TAU_;
		vec3 pos = at+away*age+(launch-away)*(1.0-e)/EASE+sway*(sin(sw)-sin(seed*TAU_))/SWAY;
		vec3 vel = away+(launch-away)*e+sway*cos(sw);

		// Facing its way, no steeper than a climb can look; rolled by the sway,
		// and twisted a moment off the ground.
		vec3 level = vec3(vel.x,0.0,vel.z);
		float flat_speed = max(length(level),0.5);
		vec3 ahead = normalize(vec3(vel.x,min(vel.y,flat_speed*1.7),vel.z));
		vec3 right = normalize(cross(ahead,vec3(0.0,1.0,0.0)));
		vec3 top = cross(right,ahead);
		float roll = dot(sway,right)*cos(sw+1.2)*0.09+(fract(seed*7.3)-0.5)*1.5*exp(-age*2.5);
		float rc = cos(roll);
		float rs = sin(roll);
		vec3 r2 = right*rc+top*rs;
		vec3 t2 = top*rc-right*rs;

		// The beat: from a blur down to the flying rate, its phase the sum of
		// the rate so far; hard strokes at the burst, then flap and glide.
		float beat = BEAT_FLY*age+(BEAT_BURST-BEAT_FLY)*(1.0-exp(-age*BEAT_EASE))/BEAT_EASE;
		float phi = beat*TAU_+seed*TAU_*3.0;
		float glide = smoothstep(1.3,2.2,age)*smoothstep(0.1,-0.5,sin(age*3.1+seed*TAU_));
		float reach = mix(1.05,0.8,smoothstep(0.2,1.2,age))*(1.0-glide*0.85);
		float lift = sin(phi)*reach+0.14+glide*0.1;

		vec3 v = VERTEX;
		vec3 n = NORMAL;
		if (UV.x > 0.5) {
			float side = v.x < 0.0 ? -1.0 : 1.0;
			vec3 q = v-vec3(shoulder.x*side,shoulder.y,shoulder.z);
			float out_ = abs(q.x);
			// In on the upstroke, swept back at the wrist, out on the down.
			float tuck = fold*max(cos(phi),0.0)*(1.0-glide);
			float sweep = smoothstep(0.0,wrist*2.0,out_);
			out_ *= 1.0-tuck*sweep;
			q.z += out_*tuck*0.8*sweep;
			float arm = min(out_,wrist);
			float rest = max(out_-wrist,0.0);
			float bend = lift-hand*(reach*0.8*sin(phi-1.0)+tuck*0.8);
			if (wrist <= 0.0) bend = lift;
			vec2 a = vec2(cos(lift),sin(lift));
			vec2 b = vec2(cos(bend),sin(bend));
			vec2 w = a*arm+b*rest;
			v = vec3((w.x+shoulder.x)*side,w.y+q.y+shoulder.y,q.z+shoulder.z);
			vec2 turn = rest > 0.0 ? b : a;
			n = vec3(n.x*turn.x*side*side-side*n.y*turn.y,side*n.x*turn.y+n.y*turn.x,n.z);
		}

		// Out of the grass small, and small again at the end, far off.
		float s = size*min(0.35+age/RISE,1.0)*clamp((life-age)/FADE,0.0,1.0);
		vec3 world = pos+r2*v.x*s+t2*v.y*s-ahead*v.z*s;
		vec3 wn = r2*n.x+t2*n.y-ahead*n.z;
		VERTEX = (VIEW_MATRIX*vec4(world,1.0)).xyz;
		NORMAL = normalize(mat3(VIEW_MATRIX)*wn);
	}
}
