// Source lake-ice.js stationary fracture, clear-ice, snow and bubble fields.

      float zsIceFracture(vec2 p) {
        vec2 cell = floor(p), local = fract(p);
        float first = 20.0, second = 20.0;
        for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) {
          vec2 offset = vec2(float(i), float(j));
          vec2 id = cell + offset;
          vec2 point = vec2(zs_noise_hash(id + 3.7), zs_noise_hash(id + 17.2));
          float d = length(offset + point - local);
          if (d < first) { second = first; first = d; }
          else second = min(second, d);
        }
        return second - first;
      }
    
void zs_ice_surface(inout vec3 body, inout float alpha, vec3 worldP, float depth, float cut, out vec3 ice_state) {

      float zsIceCover = 0.0, zsIceClear = 0.0, zsIceSnow = 0.0;
      if (zs_ice > 0.02) {
        float icN = zs_noise(worldP.xz * 1.4);
        float icF = zs_ice * 1.6 - depth * 0.55 + (icN - 0.5) * 0.35 - 0.28;
        float icM = smoothstep(0.0, 0.30, icF) * smoothstep(0.02, 0.10, zs_ice);
        // At full freeze the deep centre is ice too, without turning white.
        zsIceCover = max(icM, smoothstep(0.75, 1.0, zs_ice));
        if (1.0 < 0.5) {
          body = mix(body, vec3(0.78, 0.85, 0.90) * (0.88 + 0.20 * icN), icM);
        } else if (cut > 0.5) {
          body = mix(body, vec3(0.16, 0.29, 0.36), zsIceCover);
        } else {
          vec2 p = worldP.xz;
          vec2 warp = vec2(zs_noise(p * 0.21 + 2.3), zs_noise(p * 0.21 + 8.1)) - 0.5;
          float cloud = zs_noise(p * 0.19 + warp * 1.3);
          zsIceClear = smoothstep(0.38, 0.7, cloud);
          vec2 direction = normalize(zs_wind_direction + vec2(0.0001));
          vec2 across = vec2(-direction.y, direction.x);
          vec2 snowP = vec2(dot(p, direction) * 0.075, dot(p, across) * 0.27);
          float snowNoise = zs_noise(snowP + warp * 1.7);
          zsIceSnow = smoothstep(0.68, 0.87, snowNoise) * (0.6 + 0.4 * zs_noise(p * 1.8));
          float fracture = zsIceFracture(p * 0.16 + warp * 0.12);
          float width = max(fwidth(fracture), 0.004);
          float crack = (1.0 - smoothstep(0.006, 0.014 + width, fracture))
            * smoothstep(0.32, 0.61, zs_noise(p * 0.11 + 17.0));
          float branch = zsIceFracture(p * 0.43 + warp * 0.4 + 7.0);
          float fine = (1.0 - smoothstep(0.002, 0.006 + fwidth(branch), branch))
            * smoothstep(0.56, 0.78, zs_noise(p * 0.32 + 13.0)) * 0.5;
          // Small enclosed circles, broken into clusters beneath clear ice.
          vec2 bubbleCell = floor(p * 2.2), bubbleP = fract(p * 2.2);
          vec2 bubbleAt = vec2(zs_noise_hash(bubbleCell + 1.3), zs_noise_hash(bubbleCell + 4.9)) * 0.6 + 0.2;
          float radius = 0.035 + zs_noise_hash(bubbleCell + 2.7) * 0.08;
          float bubbleD = abs(length(bubbleP - bubbleAt) - radius);
          float bubble = (1.0 - smoothstep(0.008, 0.018 + fwidth(bubbleD), bubbleD))
            * step(0.8, zs_noise(p * 0.34 + 9.3)) * zsIceClear;
          vec3 iceColor = mix(vec3(0.19, 0.30, 0.38), vec3(0.055, 0.12, 0.20), zsIceClear);
          iceColor *= 0.88 + icN * 0.16;
          iceColor = mix(iceColor, vec3(0.54, 0.68, 0.73), max(crack, fine) * 0.72);
          iceColor = mix(iceColor, vec3(0.61, 0.74, 0.76), bubble * 0.5);
          iceColor = mix(iceColor, vec3(0.68, 0.74, 0.76), zsIceSnow);
          body = mix(body, iceColor, zsIceCover);
          float iceAlpha = mix(0.95, 0.68, zsIceClear) + zsIceSnow * 0.3 + max(crack, fine) * 0.1;
          alpha = mix(alpha, min(1.0, iceAlpha), zsIceCover);
        }
      }
    
 ice_state = vec3(zsIceCover, zsIceClear, zsIceSnow);
}
