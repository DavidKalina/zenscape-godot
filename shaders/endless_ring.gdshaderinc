// The endless grass's ring distance (scripts/endless/endless_grass.gd
// `ring_lead`): how far a point is from the eye for the carpet's rings,
// measured along the ground, led out ahead along the view.
//
// `ring_lead`.xy is the lead (world x, z): the view's level direction times
// k (< 1), so a ring R m out stands R(1+k) m ahead, R(1-k) m behind and
// R*sqrt(1-k*k) m to the side: a disc of radius R centred k*R ahead, as
// wide as the unled one (the same tufts in it). `.z` is the eye's height
// past which the rings close in (m over the ground past FLAT_UP, as a
// height over a disc: d = sqrt(R*R + z*z)), so from high up they shrink as
// a 3D distance would. `.w` 0: the plain 3D distance (the isles' rule).
uniform vec4 ring_lead = vec4(0.0);

float endless_ring_d(vec3 eye, vec3 p) {
	if (ring_lead.w <= 0.0) return distance(eye, p);
	vec2 q = p.xz - eye.xz;
	vec2 l = ring_lead.xy;
	float ll = min(dot(l, l), 0.81);
	float ql = dot(q, l);
	float r = (sqrt(ql * ql + (1.0 - ll) * dot(q, q)) - ql) / (1.0 - ll);
	return sqrt(r * r + ring_lead.z * ring_lead.z);
}
