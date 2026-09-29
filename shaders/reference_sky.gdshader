shader_type sky;
// March in the final pass: intermediate sky passes also receive native fog.
#include "res://shaders/reference_cloud_march.gdshaderinc"
#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"

        
        
        
        
        
        
        
        float hash(vec3 p) {
          return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
        }
        // one octave of smooth value noise — only ever run on night-sky pixels,
        // where it clumps the Milky Way; 8 hashes is nothing next to the fog march
        float vnoise(vec3 p) {
          vec3 i = floor(p), f = fract(p);
          f = f * f * (3.0 - 2.0 * f);
          return mix(
            mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
                mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
            mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
                mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y),
            f.z);
        }
        // Look pass (scripts/look_pass.gd): hazed ridges ringing the horizon,
        // so the plate sits in a landscape instead of an empty band of sky.
        // Zero strength paints nothing; the seed and relief follow the world.
        uniform float horizon_ridges = 0.0;
        uniform float horizon_seed = 0.0;
        uniform float horizon_relief = 1.0;
        // Ridged value noise round the circle of azimuths, so the line wraps
        // with no seam. Nearer layers are busier and lower.
        float ridge_line(vec2 around, float layer) {
          float freq = 2.2 + layer * 1.6;
          float amp = 0.5;
          float h = 0.0;
          for (int o = 0; o < 3; o++) {
            vec3 p = vec3(around * freq, 0.0) + vec3(horizon_seed * 0.137 + layer * 17.3, layer * 5.1, horizon_seed * 0.071 + float(o) * 3.7);
            h += (1.0 - abs(vnoise(p) * 2.0 - 1.0)) * amp;
            freq *= 2.1;
            amp *= 0.45;
          }
          return h;
        }
        void sky() {
          // Re-normalize per fragment: the dome's facets span ~15 degrees, and
          // the interpolated varying shrinks to ~0.991 mid-facet — under the
          // sun disc's own dot() threshold, which silently erases it.
          vec3 dir = normalize(EYEDIR);
          float y = dir.y;
          // The stars and the horizon hills are the room's: they stay put while
          // the diorama turns. The sun, moon, meteor, glow and bow already
          // arrive turned (studies/celestial.gd room_yaw).
          vec3 room = zsRoomDir(dir);
          // The gradient itself is zsSkyGradient (above): the dome is a caller
          // of it like anything else that has to know what colour the sky is.
          vec3 col = zsSkyGradient(dir);

          // Stars: candidates on 3D lattices the dome slices through — round
          // dots, per-star brightness and a slow twinkle. Two lattices: a
          // coarse one for the named-feeling bright stars (a few of them warm —
          // real skies aren't monochrome) and a fine one for the dust that
          // makes a dark sky read FULL. Faded at the horizon the way air fades
          // them, and everything in here is gated to night-sky pixels only.
          // No horizon cutoff: the diorama FLOATS, and the default camera looks
          // down on it, so almost all the visible "sky" is the dome below y=0 —
          // a fade at the horizon line blanks the stars from the only band the
          // player ever sees. Stars run deep below the horizon and only thin
          // out toward the void under the slab.
          float starK = zs_night * zs_celestial_clear * smoothstep(-0.55, -0.2, y);
          if (starK > 0.001) {
            // The Milky Way: a tilted great-circle band, clumped by smooth
            // noise so it reads as spilled light, not an airbrushed stripe.
            vec3 mwN = normalize(vec3(0.6, 0.25, 0.75));
            float mwD = dot(room, mwN);
            float mwBand = exp(-mwD * mwD / 0.045);
            float mwClump = vnoise(room * 9.0) * 0.65 + vnoise(room * 23.0) * 0.35;
            float mw = mwBand * (0.3 + 0.7 * smoothstep(0.32, 0.8, mwClump));
            col += vec3(0.55, 0.62, 0.85) * mw * 0.05 * starK;

            // bright stars
            vec3 sp = room * 46.0;
            vec3 cell = floor(sp);
            float h = hash(cell);
            vec3 pos = cell + 0.15
              + 0.7 * vec3(hash(cell + 17.0), hash(cell + 43.0), hash(cell + 71.0));
            float star = smoothstep(0.3, 0.0, length(sp - pos)) * step(0.66, h);
            float tw = 0.7 + 0.3 * sin(zs_motion_time * (0.6 + h * 2.4) + h * 40.0);
            vec3 starTint = mix(vec3(1.0, 0.86, 0.7), vec3(0.75, 0.82, 1.0),
                                smoothstep(0.1, 0.35, fract(h * 7.31)));
            col += starTint * star * star * (0.3 + 0.8 * h) * tw * starK;

            // star dust — smaller, dimmer, denser, and denser still inside the
            // Milky Way's band, which is what the band actually IS
            vec3 sp2 = room * 92.0;
            vec3 cell2 = floor(sp2);
            float h2 = hash(cell2 + 5.0);
            vec3 pos2 = cell2 + 0.2
              + 0.6 * vec3(hash(cell2 + 11.0), hash(cell2 + 29.0), hash(cell2 + 57.0));
            float dust = smoothstep(0.24, 0.0, length(sp2 - pos2))
              * step(mix(0.62, 0.42, mwBand), h2);
            col += vec3(0.7, 0.78, 1.0) * dust * dust * (0.12 + 0.3 * h2) * starK;

            // The resident follows this same CPU-owned head position.
            if (zs_meteor_head.w > 0.0) {
              vec3 mHead = zs_meteor_head.xyz;
              vec3 mTail = zs_meteor_tail;
              vec3 seg = mHead - mTail;
              float u = clamp(dot(dir - mTail, seg) / (dot(seg, seg) + 1e-6), 0.0, 1.0);
              vec3 cp = mTail + seg * u;
              float dd = length(dir - cp);
              float streak = exp(-dd * dd / 2.0e-5);
              float env = zs_meteor_head.w;
              col += vec3(0.9, 0.95, 1.0) * streak * mix(0.08, 1.0, u) * env * 1.5 * starK;
            }
          }

          // The sun: a disc hot enough to bloom through ACES, plus a soft halo.
          // Reddens as it drops; fades once it is genuinely under the horizon.
          float sE = zs_sun_direction.y;
          float sd = dot(dir, zs_sun_direction);
          float sunVis = zs_celestial_clear * smoothstep(-0.06, 0.01, sE);
          vec3 sunCol = mix(vec3(1.3, 0.38, 0.10), vec3(1.4, 1.2, 0.95), smoothstep(0.02, 0.4, sE));
          col += sunCol * 4.0 * smoothstep(0.9992, 0.99965, sd) * sunVis;
          col += sunCol * 0.18 * pow(max(sd, 0.0), 90.0) * sunVis;

          // The moon: smaller and cooler, gibbous by construction — a second
          // disc offset anti-sunward (daynight.js computes it) eats the dark
          // limb. Faintly there by day, full presence at night.
          float md = dot(dir, zs_moon_direction);
          float moon = smoothstep(0.99958, 0.99982, md);
          float bite = smoothstep(0.99958, 0.99982, dot(dir, zs_moon_shadow_direction));
          float moonVis = zs_celestial_clear * smoothstep(-0.04, 0.03, zs_moon_direction.y) * mix(0.15, 1.0, zs_night);
          col += vec3(0.86, 0.92, 1.0) * moon * (1.0 - 0.72 * bite) * 1.6 * moonVis;
          col += vec3(0.5, 0.6, 0.8) * 0.06 * pow(max(md, 0.0), 160.0) * moonVis * zs_night;

          // Horizon ridges, far to near, each a step deeper into the haze and
          // pale at its feet where valley mist would lie. Painted over the sun
          // and moon so they set behind the hills; faded out below the horizon
          // so the void under the floating plate stays sky.
          if (horizon_ridges > 0.0 && y > -0.14 && y < 0.12) {
            vec2 around = normalize(room.xz + 1e-5);
            vec2 seen = normalize(dir.xz + 1e-5);
            vec3 horizon = zsSkyGradient(normalize(vec3(seen.x, 0.0, seen.y)));
            float below = smoothstep(-0.14, -0.04, y);
            for (int k = 0; k < 3; k++) {
              float layer = float(k);
              float top = mix(0.012, -0.015, layer * 0.5) + ridge_line(around, layer) * mix(0.07, 0.04, layer * 0.5) * horizon_relief;
              float cover = smoothstep(top + 0.0015, top - 0.0015, y) * below;
              float haze = mix(0.28, 0.62, layer * 0.5) * mix(0.55, 1.0, smoothstep(top - 0.05, top, y));
              col = mix(col, mix(horizon, horizon * vec3(0.58, 0.64, 0.76), haze), cover * horizon_ridges);
            }
          }

          vec4 cloud = zs_cloud_march(POSITION, dir, FRAGCOORD.xy);
          col = col * (1.0 - cloud.a) + cloud.rgb;
          COLOR = scene_linear_for_display(clamp(col, vec3(0.0), vec3(0.98)));
}
