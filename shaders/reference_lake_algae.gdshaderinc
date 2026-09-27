// Generated from lake-algae.js by tools/export_lake_algae.py.
uniform float lake_algae_amount = 1.0;
uniform float lake_algae_richness = 0.18;
uniform float lake_algae_seed = 0.0;
uniform vec3 lake_algae_anchors[12];
void zs_lake_algae(inout vec3 body, inout float alpha, vec3 world_p, vec2 local_p, float depth, float cut) {

      if (lake_algae_amount > 0.0 && cut < 0.5 && zs_ice < 0.85 && zs_water_growth_now() > 0.97) {
        vec2 algaeDir = normalize(zs_wind_direction + vec2(0.0001));
        vec2 algaeAcross = vec2(-algaeDir.y, algaeDir.x);
        // Slow surface drift, with elongated, warped streaks along the wind.
        vec2 algaeDrift = world_p.xz - algaeDir * zs_flow_time * 0.035;
        vec2 algaeP = vec2(dot(algaeDrift, algaeDir) * 0.11,
                            dot(algaeDrift, algaeAcross) * 0.25) + lake_algae_seed;
        vec2 algaeWarp = vec2(zs_noise(algaeP * 0.8 + 2.7), zs_noise(algaeP * 0.8 + 8.3)) - 0.5;
        float algaeBank = zs_noise(algaeP + algaeWarp * 1.7);
        float algaeCurl = zs_noise(algaeP * 2.8 + algaeWarp * 2.0);
        float algaeGrain = zs_noise(algaeP * vec2(9.0, 16.0) + algaeWarp * 3.0);
        float algaeCatch = 0.0;
        // Debris and floating vegetation hold a ragged film in their lee.
        for (int algaeI = 0; algaeI < 12; algaeI++) {
          vec3 anchor = lake_algae_anchors[algaeI];
          vec2 offset = local_p - anchor.xy - algaeDir * anchor.z * 0.8;
          vec2 stretch = vec2(dot(offset, algaeDir) * 0.6, dot(offset, algaeAcross));
          algaeCatch = max(algaeCatch, (1.0 - smoothstep(anchor.z * 0.5, anchor.z * 2.2 + 0.001, length(stretch))) * step(0.01, anchor.z));
        }
        float algaeField = algaeBank * 0.74 + algaeCurl * 0.26 + algaeCatch * 0.18;
        float algaeCover = smoothstep(0.64 - lake_algae_richness * 0.13, 0.79, algaeField);
        algaeCover *= smoothstep(0.25, 0.63, algaeGrain) * 0.65
          * mix(0.6, 1.0, zs_noise(world_p.xz * 4.0 + lake_algae_seed));
        algaeCover *= lake_algae_amount * (1.0 - smoothstep(0.15, 0.85, zs_ice))
          * (1.0 - 0.65 * smoothstep(1.0, 3.5, zs_wind_strength))
          * smoothstep(0.04, 0.25, depth);
        vec3 algaeColor = mix(vec3(0.045, 0.10, 0.085), vec3(0.18, 0.24, 0.06), algaeCurl);
        body = mix(body, algaeColor, algaeCover);
        alpha = mix(alpha, 1.0, algaeCover * 0.7);
      }
    
}
