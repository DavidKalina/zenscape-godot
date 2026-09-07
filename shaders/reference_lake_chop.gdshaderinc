// Generated from water.js by tools/export_lake_chop.py.
uniform float lake_swell = 1.0;
uniform vec2 lake_effects = vec2(1.0);
float zsGale(float wind, float g) { return wind * (0.45 + 1.1 * g); }

  uniform float lake_marine_chop;
  uniform float lake_marine_ripples;
  vec2 zsLakeWave(vec2 p, vec2 wind, float t) {
    vec2 across = vec2(-wind.y, wind.x);
    float along = dot(p, wind), side = dot(p, across);
    // Slow phase warps change both spacing and heading without introducing
    // wavelengths too short for the mesh. The same phase still carries foam.
    float phase = along * 1.45 - t * 1.85
      + sin(side * 0.31 + along * 0.12 - t * 0.17) * 1.05
      + sin(side * 0.73 - along * 0.19 + t * 0.11) * 0.38;
    float wave = sin(phase);
    vec2 lake = vec2(wave + 0.22 * sin(2.0 * phase - 0.7), wave);
    // Crossing wind waves interrupt a crest along its length. Both the mesh
    // displacement and foam sample this same field, so white stays on crests.
    float crossWave = sin(along * 0.83 + side * 1.12 - t * 1.43 + sin(side * 0.25 - t * 0.13));
    float envelope = 0.78 + 0.22 * sin(side * 0.39 + along * 0.18 - t * 0.21);
    vec2 sea = vec2((lake.x + 0.35 * crossWave) * envelope, (wave + 0.35 * crossWave) / 1.35);
    return mix(lake, sea, lake_marine_chop);
  }
      float zsFetch(vec4 a, vec4 b, vec2 w) {
        vec2 u = -w;                    // the water upwind is the water behind
        const float S = 0.70710678;
        vec4 na = vec4(u.x, (u.x + u.y) * S, u.y, (-u.x + u.y) * S);
        vec4 nb = vec4(-u.x, (-u.x - u.y) * S, -u.y, (u.x - u.y) * S);
        na = max(na, vec4(0.0)); na = na * na; na = na * na;
        nb = max(nb, vec4(0.0)); nb = nb * nb; nb = nb * nb;
        float den = dot(na, vec4(1.0)) + dot(nb, vec4(1.0));
        return (dot(na, a) + dot(nb, b)) / max(den, 1e-4);
      }
float zs_lake_chop(vec3 position, vec3 world_p, float depth, vec4 aFetchA, vec4 aFetchB, out vec3 state) {
float vFetch, vCrest, vGust;
vec3 transformed = position;

      vFetch = clamp(zsFetch(aFetchA, aFetchB, zs_wind_direction) / 9.0, 0.0, 1.0);
      // Fetch-limited: linear in the wind, root in the run. A STILL body
      // (lake_swell) resists it the way it resists the swell, and ice holds
      // whatever it froze.
      // CAT'S PAWS. The wind is not one number over the whole sheet: the
      // World's gust field (wind.js) walks over the water as it walks over
      // the grass, and the chop stands up where the hard air is - dark
      // patches racing downwind across a lake, in step with the trees on
      // its shore going over. Read in WORLD xz, so a paw crosses a seam
      // between two Chunks' sheets whole.
      vGust = zs_gust_field(world_p.xz);
      float zsAmp = 0.021 * zsGale(zs_wind_strength, vGust) * sqrt(vFetch)
        * mix(lake_swell, min(lake_swell, 2.5), lake_marine_chop) * (1.0 - zs_ice);
      // Two trains, travelling DOWNWIND. The long one is a wave the mesh can
      // actually hold — a lake vertex is about half a metre, so anything under
      // a metre of wavelength is under the sheet's own Nyquist and comes out
      // as per-vertex jitter rather than as water. The short one sits right at
      // that limit ON PURPOSE: it is not there to be seen as a wave, it is
      // there to break the facet normals, which is what the fresnel (5c) turns
      // into moving light.
      float zsPh = dot(position.xz, zs_wind_direction);
      vCrest = sin(zsPh * 4.1 - zs_flow_time * 3.1) * 0.6
             + sin(zsPh * 6.6 - zs_flow_time * 4.6 + 1.7) * 0.4;
      transformed.y += vCrest * zsAmp;
      if (lake_effects.x > 0.0) {
        vec2 lakeP = world_p.xz;
        float shore = smoothstep(0.04, 0.7, depth);
        float roll = zsLakeWave(lakeP, zs_wind_direction, zs_flow_time).x;
        transformed.y += roll * zsAmp * 4.8 * shore * lake_effects.x;
      }
    
state = vec3(vFetch, vCrest, vGust);
return transformed.y - position.y;
}
void zs_lake_foam(inout vec3 body, inout float alpha, vec3 world_p, float water_depth, vec3 state) {
float vFetch = state.x, vCrest = state.y, vGust = state.z;

      // A wave does not break because it is tall, it breaks because it is
      // tall for its length — which at one wavelength is: hard wind, long
      // run, at the crest. The three gates multiply, so all three have to be
      // true at once, and a breeze over a pond stays a breeze over a pond.
      float zsCap = smoothstep(0.55, 1.0, vCrest)
                  * smoothstep(1.0, 1.0 + 0.9, zsGale(zs_wind_strength, vGust))
                  * smoothstep(0.12, 0.55, vFetch)
                  * (1.0 - zs_ice);
      if (lake_effects.x > 0.0) {
        float crest = zsLakeWave(world_p.xz, zs_wind_direction, zs_flow_time).y;
        // Foam happens in patches of hard air, not on every wave. Two scales
        // interrupt different parts of successive crests, leaving open water
        // between them; both drift continuously in the world's wind frame.
        vec2 across = vec2(-zs_wind_direction.y, zs_wind_direction.x);
        vec2 foamP = vec2(dot(world_p.xz, zs_wind_direction), dot(world_p.xz, across));
        foamP.x -= zs_flow_time * 0.36;
        float foamPatch = zs_noise(foamP * vec2(0.16, 0.23));
        float torn = zs_noise(foamP * vec2(0.43, 0.32) + vec2(7.3, 2.8));
        float breakingAir = smoothstep(0.46, 0.72, foamPatch * 0.68 + torn * 0.32)
          * smoothstep(0.28, 0.65, vGust);
        float lace = zs_noise(foamP * 1.8);
        float breaking = smoothstep(mix(0.90, 0.78, lake_marine_chop), mix(0.995, 0.95, lake_marine_chop), crest + (lace - 0.5) * 0.08)
          * smoothstep(0.28, 0.62, lace);
        float wake = smoothstep(0.45, 0.92, crest) * smoothstep(0.56, 0.80, lace) * 0.16;
        float cap = (breaking + wake) * breakingAir * 0.72
          * smoothstep(mix(0.65, 0.3, lake_marine_chop), mix(1.9, 1.3, lake_marine_chop), zsGale(zs_wind_strength, vGust))
          * smoothstep(0.1, 0.55, vFetch) * smoothstep(0.06, 0.65, water_depth)
          * lake_swell * (1.0 - zs_ice);
        zsCap = mix(zsCap, cap, lake_effects.x);
      }
      // water.js FOAM (#f2f7f8), spelled out for the same reason the ice
      // colour above is: this is a shader constant, not a shared object.
      zsCap = clamp(zsCap, 0.0, 1.0);
      body = mix(body, vec3(0.949, 0.969, 0.973), zsCap * 0.85);
      // and broken water is not a window
      alpha = mix(alpha, 1.0, zsCap);
    
}
vec3 zs_lake_fine_normal(vec3 normal, vec3 world_p, float water_depth, vec3 state) {
float vFetch = state.x, vCrest = state.y, vGust = state.z;

      if (lake_effects.y > 0.0 && zs_ice < 0.99) {
        vec2 across = vec2(-zs_wind_direction.y, zs_wind_direction.x);
        float along = dot(world_p.xz, zs_wind_direction);
        float crosswind = dot(world_p.xz, across);
        vec2 slope = zs_wind_direction * cos(along * 8.1 + crosswind * 1.2 - zs_flow_time * 3.8)
                   + across * cos(crosswind * 10.3 - along * 1.7 - zs_flow_time * 2.9) * 0.55;
        // Fine ocean roughness has its own scale: broad swell strength must
        // not turn short waves into a tiled field of steep reflecting facets.
        float warp = sin(crosswind * 0.67 + along * 0.29 - zs_flow_time * 0.43);
        float warp2 = sin(along * 0.91 - crosswind * 0.38 + zs_flow_time * 0.31);
        vec2 seaSlope = zs_wind_direction * cos(along * 6.7 + crosswind * 0.8 - zs_flow_time * 3.8 + warp * 2.1)
          + across * cos(crosswind * 9.3 - along * 2.3 - zs_flow_time * 2.9 + warp2 * 1.6) * 0.35
          + (zs_wind_direction + across * 0.6) * cos(along * 12.7 + crosswind * 4.1 - zs_flow_time * 5.3 + warp) * 0.2;
        seaSlope *= 0.75 + 0.25 * sin(along * 0.73 + crosswind * 0.57 - zs_flow_time * 0.37);
        slope = mix(slope, seaSlope, lake_marine_ripples);
        float ripple = (0.035 + 0.07 * zsGale(zs_wind_strength, vGust) * sqrt(vFetch))
          * mix(lake_swell, min(lake_swell, 2.0), lake_marine_ripples) * (1.0 - zs_ice) * smoothstep(0.02, 0.35, water_depth) * lake_effects.y;
        normal = normalize(normal - vec3(slope.x, 0.0, slope.y) * ripple);
      }

return normal;
}
