shader_type spatial;
render_mode cull_back, diffuse_lambert;
global uniform float zs_flow_time;
global uniform vec3 zs_palette_water;
varying vec3 world_position;
varying float depth;
varying float side;
void vertex() {
    depth = UV2.x;
    side = UV2.y;
    float shore = smoothstep(0.015, 0.3, depth) * (1.0 - side);
    VERTEX.y += (sin(VERTEX.x * 2.0 + zs_flow_time * 0.65) + sin(VERTEX.z * 2.7 - zs_flow_time * 0.8)) * 0.009 * shore;
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    vec3 normal = normalize(cross(dFdx(world_position), dFdy(world_position)));
    if (normal.y < 0.0 && side < 0.5) normal = -normal;
    NORMAL = normalize((VIEW_MATRIX * vec4(normal, 0.0)).xyz);
    vec3 body = mix(vec3(0.07, 0.23, 0.20), vec3(0.018, 0.08, 0.085), 1.0 - exp(-depth * 1.8));
    ALBEDO = body;
    EMISSION = body * 0.08;
    ROUGHNESS = side > 0.5 ? 0.55 : 0.05;
    METALLIC = 0.35;
    SPECULAR = 1.0;
    // Opaque depth-colored water participates in SSR. True transmission is
    // deliberately left for a later material pass; no misleading ALPHA=1.
}
