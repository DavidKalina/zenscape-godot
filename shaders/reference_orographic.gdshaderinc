// Original weather.js summit cap and lee-side spill. groundAt is provided by the host.
      float wxCapEnv(vec3 p) {
        vec2 r = p.xz - zs_summit.xyz.xz;
        float s = dot(r, zs_wind_direction) - 1.0;
        float c = dot(r, vec2(-zs_wind_direction.y, zs_wind_direction.x));
        float rr = s * s * 0.048 + c * c * 0.10;   // ~4.6 along the wind, ~3.2 across
        if (rr > 1.0) return 0.0;
        float thick = 1.3 * (1.0 - rr) + 0.15;
        float dy = p.y - (zs_summit.xyz.y + 1.1 + 0.3 * rr);
        float v = 1.0 - clamp(dy * dy / (thick * thick), 0.0, 1.0);
        return (1.0 - rr) * v;
      }
      float wxSpillEnv(vec3 p, float gh) {
        float crest = max(groundAt(p.xz - zs_wind_direction * 2.0), groundAt(p.xz - zs_wind_direction * 4.0));
        float src = smoothstep(zs_condensation - 1.2, zs_condensation + 0.8, crest);
        float lee = smoothstep(0.5, 2.2, crest - gh);
        float below = crest - p.y;
        float tongue = smoothstep(-0.7, 0.3, below) * exp(-max(below, 0.0) * 0.25);
        // …and it EVAPORATES as it sinks: descending air warms, and a couple
        // of units under the level the cloud is gone. Measured against the
        // level, not the crest — measured against the crest, every point on
        // a lee face has higher ground upwind, and the tongue was a curtain
        // to the valley floor.
        float alive = smoothstep(zs_condensation - 2.5, zs_condensation - 0.6, p.y);
        return src * lee * tongue * alive;
      }
      float orogAt(vec3 p, float gh) {
        float amt = zs_summit.w * smoothstep(0.8, 1.0, zs_growth.x);
        if (amt < 0.005) return 0.0;
        float env = wxCapEnv(p) + wxSpillEnv(p, gh);
        if (env < 0.01) return 0.0;
        // The texture streams with the wind and sinks: the pattern pours
        // down the lee while the envelope stands.
        vec3 q = p * vec3(0.42, 0.26, 0.42) + vec3(zs_cloud_drift.x * 4.5, zs_motion_time * 0.07, zs_cloud_drift.z * 4.5);
        float d = env * (0.40 + 1.2 * wxFbm(q)) - 0.28;
        return max(d, 0.0) * 2.6 * amt;
      }

