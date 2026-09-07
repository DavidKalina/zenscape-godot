// Generated from water.js ringGLSL by tools/export_rain_rings.py.
// Apply in world space before the view transform; rotation commutes with normalization.
vec3 zs_rain_ring_normal(vec3 normal, vec3 world_p, float time, float wet, float ice) {
if (wet > 0.01 && ice < 0.5) {
        vec2 zsP = world_p.xz * 3.4;              // ~0.29 m per drop's cell
        vec2 zsG = floor(zsP), zsL = fract(zsP);
        // one drop per cell per cycle, phase hashed off the cell, so the
        // stipple has no beat
        float zsAge = fract(time * 0.85 + zs_noise_hash(zsG));
        vec2 zsD = zsL - vec2(zs_noise_hash(zsG + 1.3), zs_noise_hash(zsG + 7.7));
        float zsR = length(zsD) + 1e-4;
        float zsQ = zsR * 26.0 - zsAge * 20.0;
        float zsEnv = exp(-zsR * 7.0) * (1.0 - zsAge);
        // The ring's own gradient, analytic — three taps of the field would
        // cost three hashes to say the same thing less exactly. Normalised by
        // the 26 the wavenumber contributes, so what comes out is a slope of
        // at most 1 and 0.8 is a tilt rather than an arbitrary gain. It is
        // not: a raw d/dr here is ~68, which normalize() turns into a surface
        // lying on its side, and a lake in the rain came out in polka dots.
        vec2 zsGrad = (zsD / zsR) * (cos(zsQ) - 0.27 * sin(zsQ)) * zsEnv;
        // a height field's normal is (-dh/dx, 1, -dh/dz); the surface is flat
        // and horizontal, so the tilt goes in in world x/z and comes back
        // through viewMatrix, which is the space the normal is in.
        vec3 zsT = vec3(zsGrad.x, 0.0, zsGrad.y);
        normal = normalize(normal - zsT * 0.8 * wet);
}

return normal;
}
