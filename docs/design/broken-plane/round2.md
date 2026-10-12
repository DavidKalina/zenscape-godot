# Broken plane, round 2: look study

Branch `look/broken-plane-2` (from `look/broken-plane`). This is a look study only. Nothing is wired into gameplay, and the ledger is unchanged.

## The main change: a mended plane looks new

Round 1 painted every plane "lacquered and a little weathered" (`WEAR := Vector2(0.55,0.3)`), so even the mended one had pale blotches. Now the paint has a wear amount, and the broken state sets it.

### Wear API (`scripts/plane_figure.gd`)

- `set_wear(t, over := 0.0)`: `t` runs from 0 (new) to 1 (worn), easing over `over` seconds (0 applies it at once). `get_wear()` returns the current value.
- **The broken state sets it.** `set_missing(ids)` sets the wear from the number of missing parts (`BROKEN_WEAR`): 1.0 with all six missing, then down in steps to 0.3 with one missing, and 0 when mended. `set_found(id)` with `seat` eases the paint one step cleaner over 1.2 s (`WEAR_EASE`) after the snap. Without `seat`, it applies at once.
- **The last part home:** the wear eases to new, and a gleam runs over the whole plane from nose to tail (`GLEAM`, `GLEAM_TIME` 1.5 s). The gleam is a slanted band of warm light drawn by the paint shader (`gleam`, `gleam_dir`, `gleam_at`, `gleam_width` in `shaders/folk_surface.gdshaderinc`).
- **Livery wear:** `livery.wear` sets the plane's floor. Broken wear never drops below it. The static `paints(livery)` builds the materials at that wear.

### What new (wear 0) looks like

Same shapes and palette as before. Only the finish changes (`FINISH` table, applied by `_finish`):

- **Lacquer (body, dark, trim):** roughness 0.3 under a sharp clear coat (0.55, coat roughness 0.03). There is no mottle. The folk shader's cool sky rim drops to 0.22 (`RIM_NEW`), so the terracotta keeps its own colour in shade.
- **Varnish (propeller):** a hard clear coat (0.7, roughness 0.03) over 0.22.
- **Doped cloth:** satin, roughness 0.45 with a light coat.
- **Brass:** polished, roughness 0.22 with a light coat. It is less metallic (0.42), so it reads as warm gold in shade. In round 1 it was khaki-olive, because at full metal it only mirrored the ground.
- **Glass:** clear, as before.

Worn (1): the colour fades about 28% toward its own grey. Pale sun-faded patches show (the old mottle). Fine scuffs run through the coat. Dust settles on faces that look up. The roughness rises, the coat goes dull, the brass tarnishes toward a dull brown, and the glass films over. All of this is in the shader's `wear` branch. Only the plane sets `wear` above 0, so the folk, airship and other users of the include are unchanged.

### The game's plane and the geometry check

The default figure (`PlaneFigure.new()`, nothing missing) is now new (wear 0). That is the plane the player flies once it's mended. **The identity check now covers geometry only:** every MeshInstance's path, transform, visibility, and vertex and normal bytes. Materials and wear are expected to change. Re-run against `look/broken-plane`: all 41 MeshInstances are identical (`/tmp/bp2/geom_dump.gd`: dump, then diff).

### Ambient planes

`scripts/sky_traffic.gd` LIVERIES now carry `"wear":0.25`. They are working planes, a little dusty and less glossy, beside the wanderer's well-kept one. The contrast makes the player's mended plane feel special. The snag study's NPC (`study/snag`, `scripts/snag_plane.gd`) builds from `SkyTraffic.LIVERIES[1]`, so it gets the same wear when the branches meet, with no edit needed. Dropping the key makes any of them new.

## Round 1's weak points

- **Windscreen damage** (`damage("windscreen")`): the frame is bent open. The left post stands, the right post is bent out, and the top rail hangs off the left post. A big shard of crazed glass is left in the frame, with a star of cracks in it. It uses a new milky `crazed` paint, which reads from across the field, unlike the faint clear glass. The right half of the frame is an open gap, and three splinters lie on the deck in front of it.
- **Lean on a missing wheel:** the right gear now folds up. Both legs buckle outward at a knee, the axle snaps short of the middle, and the bare stub axle with its collar and nut sticks out of the folded foot. The plane slumps over until the lower right wingtip is 1.2 cm (unscaled) off the grass (`LOW_TIP`, `WING_CLEAR`, `_tip`). That's about twice round 1's lean, and clear from the row. To make this work, the right legs and the axle are tagged `"gear"`. `_split` cuts them out like a found part and rebuilds them straight as the wheel's `base`, so the gear straightens when the wheel snaps home. The tagging records spans only, so the default geometry is unchanged.
- **Snap flash:** `FLASH` went from (1.9, 0.5) to (0.95, 0.09). The part now catches a warm tan glint at the snap, with the ring and puff as before, instead of turning nearly white.
- **Which side is lost (optional):** not done. The found wingtip piece, the seats and the joined-mesh tags are all right-side. Mirroring means mirroring each part's holder and the lean, which isn't simple. Left for a later round if wanted.

## Coordination

The only `plane_figure.gd` edits are to paint, wear, damage pieces and the lean. `_strut` now returns its MeshInstance3D (for the tag). No sizes, scale or ground-scale handling were touched.

## Captures (local only; `captures/` is gitignored)

In `captures/broken_plane_2/`:

- `before_row.png`, `after_row.png`: the four planes in a row
- `before_mended.png`, `after_mended.png`: the mended plane close, three-quarter front, in daylight
- `before_broken.png`, `after_broken.png`: the fully broken plane close
- `before_mended_night.png`, `after_mended_night.png`: the mended plane at night
- `after_windscreen.png`: the new windscreen damage close up
- `after_snap.png`: the wheel snapping home (warm glint)
- `after_gleam.png`: the gleam crossing the plane as its last part seats

Fixes made after looking at the captures:

- The clear coat at 1.0 mirrored the gallery's blue sky as a mauve haze, so it is now 0.55.
- The brass was khaki, so it is now less metallic.
- The scuffs read as white flecks and striped the struts, so they are toned down and the dark paint weathers less.
- The gleam was a milky haze, so it is now narrower and golden.

## Checks

- Headless import: exit 0, no errors.
- Headless load, `--quit-after 300`:
  - `broken_plane_gallery.tscn`: exit 0, clean.
  - `plane_parts_gallery.tscn`: exit 0, clean.
  - `zenscape.tscn -- --no-title`: exit 0, with "19 ObjectDB instances leaked" and "1 resources still in use" at exit. The same two lines appear on `look/broken-plane` without these changes.
- Geometry identity: 41 of 41 MeshInstances identical.
- The full suite was not run.

## Open questions

- **Gloss in the gallery light:** the sun sits roughly behind the gallery camera, so the clear coat shows few highlights. "Pristine" reads mostly as clean, saturated colour and gold brass. A view toward the sun, or the game's own light, should show more glint. That is unverified here.
- **Lilac tint:** a faint lilac on the up- and down-facing facets is the gallery sky reflecting in the paint. It was there in round 1 too.
- **Ambient wear:** is 0.25 right, or should the sky's planes be new too?
- **Found pieces in `scripts/plane_parts.gd`:** they use `paints()`, so they're new and glossy. Should a found piece look as dusty as the plane it came off, and get cleaned when it seats?
- **The flight study's `_wreck`:** `studies/flight_study.gd` builds its wreck as a plain new `PlaneFigure`. It may want `set_wear(1.0)`.
