shader_type sky;
// March in the final pass: intermediate sky passes also receive native fog.
#include "res://shaders/reference_cloud_march.gdshaderinc"
#define ZS_NIGHT_LIGHTS_APART
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
        // Star colour by temperature, t in 0..1: hot blue-white through white
        // and yellow to orange and a rare ember red. Weighted toward white.
        vec3 star_tint(float t) {
          vec3 c = vec3(0.66, 0.77, 1.0);
          c = mix(c, vec3(0.94, 0.96, 1.0), smoothstep(0.14, 0.3, t));
          c = mix(c, vec3(1.0, 0.91, 0.76), smoothstep(0.55, 0.7, t));
          c = mix(c, vec3(1.0, 0.72, 0.46), smoothstep(0.84, 0.92, t));
          c = mix(c, vec3(1.0, 0.55, 0.34), smoothstep(0.97, 0.995, t));
          return c;
        }
        // One lattice of stars. At most one star per cell, kept when its hash
        // clears `keep`. The core is a Gaussian at least a pixel wide
        // (`pixel` is radians per screen pixel), so a star is a sharp point at
        // any field of view rather than a blob that grows as the camera zooms.
        // Brightness is a power law (`spread`): many faint, a few brilliant.
        // The brilliant ones carry a faint halo that the glow picks up.
        vec3 star_layer(vec3 room, float scale, float seed, float keep, float gain, float spread, float pixel, float y) {
          vec3 sp = room * scale;
          vec3 cell = floor(sp);
          float h = hash(cell + seed);
          if (h < keep) return vec3(0.0);
          vec3 pos = cell + 0.2
            + 0.6 * vec3(hash(cell + seed + 17.0), hash(cell + seed + 43.0), hash(cell + seed + 71.0));
          vec3 off = sp - pos;
          float d2 = dot(off, off);
          float sig = max(pixel * scale * 1.4, 0.003);
          float mag = pow(fract(h * 91.7 + seed), spread);
          float b = gain * (0.1 + 2.0 * mag);
          // Scintillation: slow and small overhead, stronger where the air
          // is thick near the horizon line.
          float scint = mix(0.1, 0.4, 1.0 - smoothstep(0.0, 0.6, abs(y)));
          float tw = 1.0 + scint * sin(zs_motion_time * (0.7 + h * 2.3) + h * 40.0)
            * sin(zs_motion_time * (0.45 + h) + h * 9.0);
          float core = exp(-d2 / (2.0 * sig * sig));
          // The halo stays inside the star's cell (a star sits at least 0.2 of a
          // cell from its edge), or the cell's polygon shows round it.
          float halo = exp(-sqrt(d2) / min(sig * 3.0, 0.045)) * 0.22 * smoothstep(0.35, 0.85, mag);
          return star_tint(fract(h * 7.31 + seed * 0.37)) * (core + halo) * b * tw;
        }
        // Four octaves of value noise, for the nebulae. Only ever run inside a
        // nebula's footprint on night pixels.
        float fbm(vec3 p) {
          float sum = 0.0;
          float amp = 0.5;
          for (int i = 0; i < 4; i++) {
            sum += amp * vnoise(p);
            p = p * 2.03 + vec3(1.7, 9.2, 3.1);
            amp *= 0.5;
          }
          return sum;
        }
        // One nebula: a cloud of warped noise inside a soft footprint round
        // `centre` (`radius` in radians). Lit from one side by a star buried in
        // it, so the edges facing the star glow and the far side falls into
        // shadow; its colour drifts from `inner` to `outer` across the cloud,
        // with `rim` where the light catches it. Returns the glow in rgb and
        // the dust that dims whatever lies behind in a.
        vec4 nebula(vec3 room, vec3 centre, float radius, float seed, vec3 inner, vec3 outer, vec3 rim) {
          float away = sqrt(max(2.0 * (1.0 - dot(room, centre)), 0.0));
          float foot = 1.0 - smoothstep(radius * 0.35, radius, away);
          if (foot <= 0.0) return vec4(0.0);
          vec3 p = room * 3.2 + seed;
          vec3 warp = vec3(vnoise(p * 0.8), vnoise(p * 0.8 + 5.3), vnoise(p * 0.8 + 9.1)) - 0.5;
          p += warp * 1.4;
          float d = fbm(p);
          // Toward the buried star, a little way along the sky from the centre.
          vec3 toward = normalize(cross(centre, vec3(0.3, 1.0, 0.2)));
          float ahead = fbm(p + toward * 0.18);
          float lit = clamp((d - ahead) * 5.0 + 0.5, 0.0, 1.0);
          float density = smoothstep(0.38, 0.78, d) * foot;
          vec3 tint = mix(inner, outer, smoothstep(0.1, 0.9, away / radius + (d - 0.5)));
          vec3 glow = mix(tint * (0.35 + 0.65 * lit), rim, pow(lit, 3.0) * 0.6) * density;
          float dust = smoothstep(0.55, 0.75, vnoise(p * 2.6 + 4.0)) * density;
          return vec4(glow, dust);
        }
        // A brilliant star, as true HDR light: a pixel-sharp core, a soft halo
        // and faint four-point glints, twinkling with a slight shift of
        // colour. Returns zero outside a small radius so it costs little.
        vec3 hero_star(vec3 dir, vec3 at, vec3 tint, float power, float seed, float pixel) {
          float away = sqrt(max(2.0 * (1.0 - dot(dir, at)), 0.0));
          if (away > 0.05) return vec3(0.0);
          vec3 side = normalize(cross(at, vec3(0.0, 1.0, 0.0)));
          vec3 up = cross(side, at);
          vec2 o = vec2(dot(dir, side), dot(dir, up));
          float sig = max(pixel * 1.3, 0.0004);
          float core = exp(-away * away / (2.0 * sig * sig));
          float halo = exp(-away / (sig * 5.0)) * 0.12;
          float thin = sig * 0.6;
          float spikes = (exp(-abs(o.y) / thin) * exp(-abs(o.x) / 0.014)
            + exp(-abs(o.x) / thin) * exp(-abs(o.y) / 0.014)) * 0.07;
          float t = zs_motion_time;
          vec3 tw = 1.0 + 0.3 * sin(t * (1.3 + seed) + seed * 17.0 + vec3(0.0, 0.8, 1.6))
            * sin(t * (0.37 + seed * 0.2) + seed * 5.0);
          return tint * tw * (core + halo + spikes) * power;
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
          // Radians per screen pixel, taken before any branch so the
          // derivative is defined.
          float pixel = max(length(fwidth(dir)), 1e-5);
          // Night light that must bloom (hero stars, the meteor's head) is
          // gathered here and added as HDR after the display conversion.
          vec3 skyHdr = vec3(0.0);
          // Deep night: the dome sinks toward true black, keeping a breath of
          // indigo overhead and a faint airglow along the horizon, so the
          // stars and nebulae sit on black rather than navy.
          float deep = zs_night * zs_celestial_clear;
          if (deep > 0.001) {
            float keep = mix(0.22, 0.5, exp(-abs(y) / 0.07));
            vec3 night = col * keep * mix(vec3(1.0), vec3(0.85, 0.9, 1.25), smoothstep(0.1, 0.8, y));
            night += vec3(0.02, 0.05, 0.035) * exp(-abs(y) / 0.035) * 0.35;
            col = mix(col, night, deep);
          }
          col += zsNightLights(dir);
          if (starK > 0.001) {
            // The Milky Way: a tilted great-circle band, clumped by smooth
            // noise so it reads as spilled light, not an airbrushed stripe.
            // One side of it swells warm toward the galactic centre, and a
            // dark rift of dust runs down its spine.
            vec3 mwN = normalize(vec3(0.6, 0.25, 0.75));
            float mwD = dot(room, mwN);
            float mwBand = exp(-mwD * mwD / 0.045);
            float mwSpine = exp(-mwD * mwD / 0.009);
            vec3 mwC = normalize(cross(mwN, vec3(0.0, 1.0, 0.0)));
            float bulge = pow(max(dot(room, mwC), 0.0), 3.0);
            float mwClump = vnoise(room * 9.0) * 0.65 + vnoise(room * 23.0) * 0.35;
            float mw = mwBand * (0.3 + 0.7 * smoothstep(0.32, 0.8, mwClump));
            float rift = smoothstep(0.42, 0.72, vnoise(room * 13.0 + 3.1)) * mwSpine;
            vec3 mwCol = mix(vec3(0.4, 0.52, 1.0), vec3(1.0, 0.78, 0.5), bulge * (0.4 + 0.6 * mwSpine));
            col += mwCol * mw * (1.0 - 0.85 * rift) * (0.09 + 0.1 * bulge) * starK;
            // Faint nebular colour caught in the band: rose and teal.
            float neb = smoothstep(0.55, 0.9, vnoise(room * 5.0 + 11.0));
            vec3 nebCol = mix(vec3(0.55, 0.14, 0.38), vec3(0.08, 0.34, 0.42), smoothstep(0.3, 0.7, vnoise(room * 3.0)));
            col += nebCol * neb * mwBand * 0.035 * starK;

            // Nebulae: three placed clouds, each softly shaded by a star
            // inside it. Their dust dims the stars behind.
            vec4 nebA = nebula(room, normalize(vec3(-0.55, 0.42, 0.72)), 0.42, 3.7,
              vec3(0.55, 0.12, 0.4), vec3(0.1, 0.22, 0.5), vec3(1.0, 0.62, 0.55));
            vec4 nebB = nebula(room, normalize(vec3(0.74, 0.18, -0.62)), 0.34, 11.2,
              vec3(0.05, 0.4, 0.45), vec3(0.12, 0.14, 0.45), vec3(0.95, 0.85, 0.55));
            vec4 nebC = nebula(room, normalize(mwC + mwN * 0.08), 0.3, 21.5,
              vec3(0.6, 0.3, 0.12), vec3(0.4, 0.1, 0.25), vec3(1.0, 0.8, 0.5));
            float dust = clamp(nebA.a + nebB.a + nebC.a, 0.0, 1.0);
            col *= 1.0 - 0.45 * dust * starK;
            col += (nebA.rgb + nebB.rgb + nebC.rgb) * 0.3 * starK;
            float veil = 1.0 - 0.6 * dust;

            // Three lattices: a sparse one for the named-feeling bright stars,
            // a middle one, and a fine dust that fills the Milky Way's band,
            // which is what the band actually IS.
            col += star_layer(room, 46.0, 0.0, 0.7, 1.3, 5.0, pixel, y) * starK * veil;
            col += star_layer(room, 97.0, 5.0, mix(0.74, 0.45, mwBand), 0.55, 4.0, pixel, y) * starK * veil;
            col += star_layer(room, 190.0, 9.0, mix(0.86, 0.5, mwBand), 0.22, 3.0, pixel, y) * starK * veil;

            // A handful of brilliant stars, placed, not hashed: the few
            // points the eye lands on first.
            float heroK = starK * veil;
            skyHdr += hero_star(room, normalize(vec3(-0.32, 0.55, 0.77)), vec3(0.75, 0.85, 1.0), 2.6, 0.13, pixel) * heroK;
            skyHdr += hero_star(room, normalize(vec3(0.61, 0.35, 0.71)), vec3(1.0, 0.8, 0.55), 2.0, 0.41, pixel) * heroK;
            skyHdr += hero_star(room, normalize(vec3(0.12, 0.82, -0.56)), vec3(0.95, 0.97, 1.0), 2.3, 0.77, pixel) * heroK;
            skyHdr += hero_star(room, normalize(vec3(-0.83, 0.12, -0.54)), vec3(1.0, 0.62, 0.42), 1.6, 0.29, pixel) * heroK;
            skyHdr += hero_star(room, normalize(vec3(0.9, -0.1, 0.42)), vec3(0.7, 0.8, 1.0), 1.8, 0.93, pixel) * heroK;
            skyHdr += hero_star(room, normalize(vec3(-0.4, -0.15, -0.9)), vec3(1.0, 0.95, 0.85), 1.5, 0.57, pixel) * heroK;

            // The shooting star. The resident follows this same CPU-owned
            // head position. A tapered trail, teal-green as meteors burn,
            // flickering as it breaks up, behind a head that blooms.
            if (zs_meteor_head.w > 0.0) {
              vec3 mHead = zs_meteor_head.xyz;
              vec3 mTail = zs_meteor_tail;
              vec3 seg = mHead - mTail;
              float u = clamp(dot(dir - mTail, seg) / (dot(seg, seg) + 1e-6), 0.0, 1.0);
              // Back onto the sphere: the chord sags inside it, by more than
              // the trail is wide, which blanked the middle of the trail.
              vec3 cp = normalize(mTail + seg * u);
              float dd = length(dir - cp);
              float width = max(mix(0.0006, 0.0024, u), pixel * 0.9);
              float streak = exp(-dd * dd / (2.0 * width * width));
              float env = zs_meteor_head.w;
              float flicker = 0.75 + 0.25 * sin(u * 110.0 - zs_motion_time * 45.0);
              vec3 trail = mix(vec3(0.25, 0.9, 0.55), vec3(0.85, 0.95, 1.0), smoothstep(0.6, 1.0, u));
              float along = smoothstep(0.0, 0.5, u) * (0.4 + 0.6 * u) * flicker * env * starK;
              col += trail * streak * along * 0.7;
              skyHdr += trail * streak * along * 2.2;
              float headAway = length(dir - mHead);
              float headSig = max(pixel * 1.4, 0.0009);
              skyHdr += vec3(0.9, 0.97, 1.0) * (exp(-headAway * headAway / (2.0 * headSig * headSig)) * 6.0
                + exp(-headAway / 0.005) * 0.5) * env * starK;
            }
          }

          // The sun: a limb-darkened disc, white-gold at its heart and deeper
          // at its edge, in a tight corona and a warm aureole that grows as it
          // sinks. The glow is display colour; the disc's own light is HDR
          // (sunHdr, below). Fades once it is genuinely under the horizon.
          float sE = zs_sun_direction.y;
          float sd = dot(dir, zs_sun_direction);
          float sunVis = zs_celestial_clear * smoothstep(-0.06, 0.01, sE);
          float high = smoothstep(0.02, 0.4, sE);
          float sunAng = sqrt(max(2.0 * (1.0 - sd), 0.0));
          const float SUN_R = 0.032;
          float disc = 1.0 - smoothstep(SUN_R - pixel, SUN_R + pixel, sunAng);
          float mu = sqrt(max(1.0 - (sunAng / SUN_R) * (sunAng / SUN_R), 0.0));
          vec3 coreCol = mix(vec3(1.0, 0.92, 0.72), vec3(1.0, 0.98, 0.92), high);
          vec3 limbCol = mix(vec3(1.0, 0.66, 0.32), vec3(1.0, 0.9, 0.72), high);
          vec3 discCol = mix(limbCol, coreCol, pow(mu, 0.55)) * 0.98;
          vec3 glowCol = mix(vec3(1.0, 0.42, 0.12), vec3(1.0, 0.8, 0.52), high);
          float beyond = max(sunAng - SUN_R, 0.0);
          float corona = exp(-beyond / 0.006) * 0.9 + exp(-beyond / 0.035) * 0.3;
          float aureole = exp(-sunAng / 0.16) * mix(0.16, 0.07, high);
          col += glowCol * (corona + aureole) * (1.0 - disc) * sunVis;
          col = mix(col, discCol * 0.9, disc * sunVis);
          // The disc's own light, added as true HDR after the display
          // conversion below: the round trip through the inverse tonemap tops
          // out short of white, which left the disc a flat grey inside a
          // brighter rim. This tonemaps to a white-hot heart with a warm limb
          // and gives the glow something to bloom.
          vec3 sunHdr = (discCol * disc * mix(mix(1.1, 8.0, high), mix(2.4, 30.0, high), pow(mu, 0.7))
            + glowCol * exp(-beyond / 0.004) * (1.0 - disc) * 2.5) * sunVis;

          // The moon: smaller and cooler, in phase. The disc is shaded as a
          // sphere lit by the sun, so its terminator follows the month
          // (studies/celestial.gd moon_age) with a faint earthshine on the dark
          // side and soft grey seas. Its glow and HDR light follow the lit
          // share. Faintly there by day, full presence at night.
          float md = dot(dir, zs_moon_direction);
          float moonAng = sqrt(max(2.0 * (1.0 - md), 0.0));
          float moonVis = zs_celestial_clear * smoothstep(-0.04, 0.03, zs_moon_direction.y) * mix(0.15, 1.0, zs_night);
          float moonLit = 0.5 - 0.5 * dot(zs_moon_direction, zs_sun_direction);
          const float MOON_R = 0.024;
          float moonEdge = max(pixel * 1.5, 0.002);
          float moon = 1.0 - smoothstep(MOON_R - moonEdge, MOON_R + moonEdge, moonAng);
          if (moon > 0.0 && moonVis > 0.0) {
            vec3 mSide = normalize(cross(zs_moon_direction, vec3(0.0, 1.0, 0.0)));
            vec3 mUp = cross(mSide, zs_moon_direction);
            vec2 mo = vec2(dot(dir, mSide), dot(dir, mUp)) / MOON_R;
            vec3 mN = mSide * mo.x + mUp * mo.y - zs_moon_direction * sqrt(max(1.0 - dot(mo, mo), 0.0));
            float lit = smoothstep(-0.06, 0.1, dot(mN, zs_sun_direction));
            float seas = 1.0 - 0.3 * smoothstep(0.45, 0.75, vnoise(vec3(mo * 2.6, 3.7)));
            float face = mix(0.035, seas, lit);
            // Kept under the display ceiling so the seas survive; only a
            // breath of HDR on the lit part, for the glow.
            col += vec3(0.86, 0.92, 1.0) * moon * face * 0.9 * moonVis;
            skyHdr += vec3(0.86, 0.92, 1.0) * moon * lit * seas * 0.12 * moonVis * zs_night;
          }
          col += vec3(0.5, 0.6, 0.8) * 0.06 * pow(max(md, 0.0), 160.0) * moonVis * zs_night * moonLit;
          // A thin silver corona hugging the disc.
          col += vec3(0.7, 0.8, 1.0) * exp(-max(moonAng - 0.019, 0.0) / 0.006) * 0.22 * (1.0 - moon) * moonVis * zs_night * moonLit;

          // Horizon ridges, far to near, each a step deeper into the haze and
          // pale at its feet where valley mist would lie. Painted over the sun
          // and moon so they set behind the hills; faded out below the horizon
          // so the void under the floating plate stays sky.
          if (horizon_ridges > 0.0 && y > -0.14 && y < 0.12) {
            vec2 around = normalize(room.xz + 1e-5);
            vec2 seen = normalize(dir.xz + 1e-5);
            // Hills sink into the night with the dome, or they stand as a navy band.
            vec3 horizon = zsSkyGradient(normalize(vec3(seen.x, 0.0, seen.y))) * mix(1.0, 0.4, deep);
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
          // Keep the hue where light overflows: scale the colour down to fit
          // rather than clipping each channel, which bleached the sun white.
          col = max(col, vec3(0.0));
          col *= 0.98 / max(max(max(col.r, col.g), col.b), 0.98);
          COLOR = scene_linear_for_display(col) + (sunHdr + skyHdr) * (1.0 - cloud.a) / zs_exposure;
}
