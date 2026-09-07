// Extracted from weather.js AUTUMN_FRAG by tools/export_autumn.py.
void zs_autumn_paint(inout vec3 color, vec3 world_position, float amount) {

        
        if (amount > 0.004) {
          vec3 lfC = color;
          float lfGrn = clamp((lfC.g - max(lfC.r, lfC.b)) * 6.0, 0.0, 1.0);
          float lfWarm = smoothstep(0.20, 0.50, lfC.r / max(lfC.g, 1e-4));
          float lfNz = zs_noise(world_position.xz * 0.33 + 17.0);
          float lfT = clamp(amount * 1.55 - lfNz * 0.5, 0.0, 1.0) * lfGrn * lfWarm;
          if (lfT > 0.003) {
            // luminance-keyed, so the shading baked into vertex colors (dark
            // grass roots, bright tips) survives the turn
            float lfLum = dot(lfC, vec3(0.30, 0.55, 0.15));
            vec3 lfHue = mix(vec3(1.00, 0.52, 0.10), vec3(0.50, 0.16, 0.05),
                             smoothstep(0.35, 1.0, amount * (0.55 + 0.6 * lfNz)));
            color = mix(lfC, lfHue * (lfLum * 2.9), smoothstep(0.0, 0.55, lfT));
          }
        }
        
}
