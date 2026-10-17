# Kit caches: handoff

A find hidden inside a breakable kit piece. One small spot on the piece
glints now and then, like light catching a gem lodged in a joint. A hit too
weak for it makes that spot flare. When it breaks, the find comes up out of
it.

Round 2 (this one) replaced round 1's whole-piece glow (edge glow, sheen,
specks and a cloud of motes) with that one spot, after the user found the
glow far too loud.

## Play it

```
godot --path . res://studies/aqueduct_isle.tscn -- --no-title --kit-caches --ledger=/tmp/caches.json
```

`studies/zenscape.tscn -- --no-title --kit-caches` works too. The flag is
off by default. Use a throwaway `--ledger=` file: a rune taken is saved to
the ledger, and in a later run its piece holds nothing.

On the near island's west turf, beside the aqueduct (start at the rubble
slope's foot and look left):

| Piece | Where | How it opens |
|---|---|---|
| tomb chest (toughness 1.6) | by the rubble slope, about z 5.5 | never by the slam. Jump off the slope's side and slam beside it: the spot flares and dust puffs off it |
| pier | below the deck, by the castellum (z -5) | climb onto the deck, walk off its west side, slam on the way down |
| buttress | below the deck (z -17) | the same |
| wall | below the deck (z -28) | the same |

The slam only fires with 1.8 m of air under him, and its strength grows
with the drop. Off the slope's side it is about 0.45. Off the 10 m deck it
is about 0.9, which beats pier, buttress and wall (0.5 / 0.5 / 0.6). Each
of the three is more than a full slam's reach from the next, so one slam
opens one. The runes are the isle's tokens (`cache_*` in
`studies/aqueduct_isle_tokens.gd`), so the readout counts them.

## What was built

- **The tag.** Meta `holds` on any kit piece, e.g. `"rune"` (any
  GlyphPickup glyph). If absent, nothing changes. A piece that holds
  something but isn't breakable is left plain, with a warning.
  `holds_name` (optional) names the cache. If not set, the piece's node
  name is used.
- **`scripts/kit_isle/kit_caches.gd`**: `watch(kit_breaks)`, then
  `adopt(root, kit_breaks)`. It puts a glint on each tagged target
  (`scripts/kit_isle/kit_cache_glint.gd`), flares it on
  `withstood`, opens on `broke`, and owns or hands off the find. If
  `tokens` (an isle's kit_tokens) has a waiting token with the cache's name,
  the find is `lay`'d there once it settles: ledger, readout and telescope.
  Otherwise the cache takes the find itself when `motor` reaches it.
  Hidden caches glint through the telescope (`Telescope.spottable` on the
  piece).
- **`kit_breaks.gd`** has two new signals: `broke(node, at)` (in `_break`)
  and `withstood(node, at, strength, source)` (in `hit`, a piece in reach
  that is too tough). `hit` checks the radius first, then the toughness.
  Results are the same as before.
- **`buried_find.gd`** has two opt-in options. `bare` gives no mound, no
  shimmer, no clods and no slam group. `from` sets where the rise starts
  (the piece's middle). The rise and the overshoot are its own.
- **The find's path.** It rises from the glint's spot (from the piece's
  middle when the spot faces away from the hit, so it never passes back
  through the stone) to a point
  `STEP_OUT` m past the footprint, toward where the hit came from, and
  hovers `HOVER` m over the ground. For the first `SETTLE` s it lifts over
  any rubble that lands under it. Then it is laid as a token, or becomes
  takeable.
- **The isle.** `studies/aqueduct_isle_caches.gd` (`--kit-caches`) stands
  the four pieces, a breakables hub of the isle's own, a kit breakable and
  the caches. It first asks for `plane_home()`, so the parked plane and its
  take-off run come out the same as without the flag. The pieces sit west
  of the aqueduct, off the plane's run (east of it).
- **The motif yard** gets caches for any authored motif with `holds`
  pieces. They are taken by the yard's own motor.

## Tag a piece in the editor

Select a piece in `studies/motif_editor.tscn` and press **I**. It holds a
rune, shows its glint in the editor and is saved as `"holds": "rune"` in the recipe.
Press I again to clear it. The status line shows "holds a rune" and warns
if the piece is unbreakable (B). `KitCaches.HOLDS` is the list the key
cycles through. The rebuild key adds `|holds=` only when a piece holds
something, so saved motifs keep their keys. Play it in the yard:
`studies/motif_yard.tscn -- --motif=<editor slug>`.

## The glint

`scripts/kit_isle/kit_cache_glint.gd` is a Sprite3D named `CacheGlint`,
placed as a child of the piece at its spot. It is a Sprite3D, not a
MeshInstance3D, so the code that measures a piece by its meshes (kit_breaks'
box, the authored seat) doesn't see it. It is drawn by
`shaders/kit_cache_glint.gdshader`, one shared material on a quad that faces
the camera. The quad is pulled `pull` m toward the camera so the stone
doesn't cut it, and it isn't drawn when seen from behind its face. Each
glint keeps its own time in `_process` (a handful per isle).

- **Quiet:** a faint point in the find's tint. Only someone close by sees
  it. It fades out between 9 and 18 m.
- **A catch:** every 2.5 to 7 s, with the gaps seeded per piece so caches
  don't keep time with each other. A quick star with four long arms, four
  short diagonal arms and a hot white core. It rises in 0.05 s and fades in
  about 0.3 s. Two tiny motes lift off the spot.
- **A weak hit:** `flare()` makes the same catch, brighter, with longer arms
  and a fatter core, fading over 0.8 s. A small dust puff
  (`KitCaches.PUFF`) comes off the spot, outward.
- **Distance:** the arms, core and motes are held at least about a pixel
  wide (`least`), and the arms grow by the root of the distance past
  `grow_from`, so the star still reads at walking distance. The whole tell
  fades out between 28 and 50 m, so from the air it is gone.

### How the spot is chosen (`KitCacheGlint.spot`)

1. If the piece has meta **`holds_at`** (a Vector3 in the piece's own
   frame), the glint goes there. It faces out along the normal of the
   nearest mesh face.
2. Otherwise it takes every triangle of the piece's own meshes, in the
   piece's frame, and samples a point (area-weighted, seeded by the piece's
   `kit_piece` recipe seed, else its name). The point must meet three
   rules, tried in this order:
   - a **side face** (|normal.y| < `SIDE` 0.4) at **hand to head height**:
     `BAND` (0.45 to 1.0) times `WorldScale.wanderer_tall`, over the
     piece's lowest point;
   - else a side face at any height;
   - else any face but an underside.
3. A sample is kept only if nothing of the piece itself is within 1.6 m
   out along its normal (`_open`: not a buried face between blocks, not
   under an overhang). In the game (`world_clear`), nothing else in the
   world may be within `CLEAR` (2.5 m) either: no slope or wall it stands
   against. This world check is dropped only if no spot passes it. The
   editor has no world check.
4. It sits `PROUD` (0.03 m) off the face, with its +Z along the normal.

On the isle's four pieces it picks points 0.7 to 1.0 m up, on open sides.
On the kit pieces probed (pier, buttress, wall, tomb_chest and arch, three
seeds each) it picked an outward-facing side point 0.5 to 1.2 m up. It takes
about 2 ms per piece, and about 14 ms for an arch (18k triangles), once at
adopt.

**Authoring `holds_at`:** none of the tools set it this round. To add it,
give the recipe an optional `"holds_at": [x, y, z]` in the piece's frame.
Then have `motif_authored.gd` set it as a Vector3 meta beside `holds`, and
let the editor set it from a click on the selected piece:
`piece.global_transform.affine_inverse() * hit.position`. Only add the key
when it is set, so saved motifs keep their keys.

## Knobs

`scripts/kit_isle/kit_cache_glint.gd` (consts):

| Knob | Now | What |
|---|---|---|
| `EVERY` | (2.5, 7.0) s | the gap between catches, least and most |
| `GLINT_IN`, `GLINT_OUT` | 0.05, 0.3 s | a catch's rise and fall |
| `FLARE_TIME` | 0.8 s | a weak hit's flare fades over this |
| `PROUD` | 0.03 m | how far it sits off the face |
| `BAND` | (0.45, 1.0) x wanderer height | the height band it prefers |
| `SIDE` | 0.4 | the most \|normal.y\| a side face may have |
| `CLEAR` | 2.5 m | the world clear out of the spot (game only) |
| `TRIES` | 48 | samples per rule before falling back |
| `QUAD` | 2.0 m | the quad it's drawn on (fits the flare and motes) |

`shaders/kit_cache_glint.gdshader` (uniforms; loudness lives here):

| Uniform | Now | What |
|---|---|---|
| `idle`, `idle_size`, `idle_fade` | 0.55, 0.022 m, 9 to 18 m | the quiet point |
| `core`, `core_size` | 3.0, 0.03 m | the catch's hot core |
| `star_len`, `star_width`, `star_gain`, `diagonal` | 0.2 m, 0.0045 m, 2.2, 0.4 | the star |
| `white` | 0.5 | how much whiter than the tint the core burns |
| `least`, `grow_from` | 0.0013 rad, 5 m | the far-off floors (see above) |
| `flare_gain`, `flare_len` | 1.6, 1.2 | a weak hit's flare: brighter, longer |
| `mote_gain`, `mote_size`, `mote_rise`, `mote_life` | 1.4, 0.013 m, 0.2 m/s, 1.5 s | the two motes |
| `fade` | 28 to 50 m | the whole tell fades out |
| `pull` | 0.14 m | drawn this far toward the camera |
| `face_cut` | 0.0 | seen this edge-on or less, it is gone |

`kit_caches.gd`: `PUFF` sets the weak hit's dust. The colour is the find's
HUD tint, lightened by 0.15 (`tint_of`); a rune's is pale cyan. `HOVER`,
`STEP_OUT`, `SETTLE` and `LIFT` set where the find settles, as before.
`flared_at` (the last flare's spot) is for checks.

## Stills (rendered, Forward+)

All are in `captures/shots/`, which git ignores. The `_crop` files are the
480x300 middle of each. Made with `scratch/caches_look.gd`
(`python tools/drive.py --rendered scratch/caches_look.gd -- [--cache=cache_chest --tag=kcc] --scene-args --no-title --kit-caches --ledger=/tmp/x.json`).

- The wall (in shade): `kc_glint_10m`, `kc_quiet_10m`, `kc_glint_25m`,
  `kc_quiet_25m`, `kc_flare_10m`, `kc_glint_close`.
- The tomb chest: `kcc_glint_10m`, `kcc_quiet_10m`, `kcc_glint_25m`,
  `kcc_flare_10m`.

At 10 m a catch is a small sharp star, about 15 px across in a 1440-wide
frame. Between catches there is a faint cyan pixel or two. At 25 m a catch
is a tiny twinkle and the quiet point is gone. Close up (2.5 m) it is a
clean four-point star with short diagonals.

## Proof

- Smoke passes, 0 errors: aqueduct isle with and without `--kit-caches`,
  `zenscape.tscn -- --no-title --kit-caches`, motif yard `sundered_gorge`
  and `editor_hill`, and the motif editor.
- Round 2 smoke passes, 0 errors: aqueduct isle with and without
  `--kit-caches`, `zenscape.tscn -- --no-title --kit-caches`, motif yard
  `sundered_gorge` and `editor_hill`, and the motif editor.
- Round 2 drivers (`scratch/caches_play.gd`, `caches_yard.gd`,
  `caches_editor.gd`) pass. On the isle, a real slam off the slope flares
  the chest at its spot (`flared_at` is the glint's position), and a slam
  off the deck opens the pier and the rune is taken. The yard run used a
  throwaway copy of `editor_hill` with `holds` on its pier and arch
  (deleted after). The editor places a glint on I and removes it on I again.
- Round 1: throwaway drivers in `scratch/`, through the real input. On the isle, a
  slam off the slope flares the chest and it holds. A slam off the deck
  opens the pier, the rune rises, is laid as `cache_pier` and is taken by
  walking into it. In the yard, an authored recipe with `holds` on two
  pieces gives two caches: a weak hit flares the arch, a strong hit opens
  the pier, and he walks into the rune. In the editor, I tags, glows, saves
  and clears.

## Limits

- **Fitted aqueduct pieces** (`fit`) aren't breakable yet, so a `holds` on
  one does nothing (see kit-breaks-handoff.md).
- **Only the slam opens a cache from the wanderer.** From flat ground a
  jump gives no slam (it needs 1.8 m of air), so caches want a height
  nearby. The Olmec and the other hub breakers also open caches, but the
  Olmec's bulk (`met`) never flares a tough piece. Only `hit` reports
  `withstood`.
- **Glyph finds only.** `holds` makes a GlyphPickup. Plane parts or other
  finds need a maker hook in `_on_broke`.
- **One spot can face away from you.** A glint sits on one side. Walking
  around a piece always finds it, but from the far side there is nothing.
  For a piece seen from one way, set `holds_at`.
- **Not captured:** a low pass in the plane at about 30 m, and the editor's
  own viewport. The editor glint is the same node and shader, checked
  headless only.
- **Bright sun.** The star is additive, so on a sunlit pale face it reads
  less than on shaded stone. Both isle stills here are on shaded or mid-lit
  stone.
- **The editor's own play mode** has no breaks, so caches are played in the
  motif yard.
- **The yard's R** doesn't rebuild broken pieces, as before.

## Tests

No new tests (prototype). `test_ledger.gd` passes. `test_slam.gd` fails 2
updraft checks ("The updraft spends the charge", "Updraft then slam in one
airtime"). They fail the same way on main at c415abd6 (checked in a
clean worktree), so they are not this branch's.

## What the harness lacked

There is no helper to press a key event in a driver (the editor's keys). The
driver built `InputEventKey`s by hand. `shot.py --frame` frames a whole
isle when the pattern matches several nodes; use `--at/--look` or a
driver's `shot_at`.
