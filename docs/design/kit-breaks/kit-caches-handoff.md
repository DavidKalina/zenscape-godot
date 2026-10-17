# Kit caches: handoff

A find hidden inside a breakable kit piece. The piece glows and sparkles
faintly. A hit too weak for it makes the glow flare. When it breaks, the
find comes up out of it.

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
| tomb chest (toughness 1.6) | by the rubble slope, about z 5.5 | never by the slam. Jump off the slope's side and slam beside it: the glow flares and dust puffs |
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
  `adopt(root, kit_breaks)`. It dresses each tagged target, flares on
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
- **The find's path.** It rises from the piece's middle to a point
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
rune, glows in the editor and is saved as `"holds": "rune"` in the recipe.
Press I again to clear it. The status line shows "holds a rune" and warns
if the piece is unbreakable (B). `KitCaches.HOLDS` is the list the key
cycles through. The rebuild key adds `|holds=` only when a piece holds
something, so saved motifs keep their keys. Play it in the yard:
`studies/motif_yard.tscn -- --motif=<editor slug>`.

## The glow's knobs

`shaders/kit_cache_glow.gdshader` is one shared material, set as
`material_overlay` on the piece's own meshes. Its colour, flare and phase
are per-instance uniforms.

- `edge` (least, most over a breath) and `edge_power`: the fresnel edge,
  which catches the block chamfers. This is the main loudness knob, now
  (0.1, 0.27).
- `body`: a faint fill over the whole face at the breath's top.
- `breath_time`: seconds per breath.
- `band`, `band_density`, `band_speed`: a thin sheen climbing the stone.
- `speck_cells`, `speck_share`, `speck`, `speck_size`: twinkling specks
  (cells per metre, share of cells, brightness, radius).
- `flare_gain`, `flare_fill`: a weak hit's flare. Brighter edges, plus a
  pulse that fills the faces.

`kit_caches.gd` holds the rest. The colour is the find's HUD tint (a
rune's is pale cyan), lightened 0.15 (`tint_of`). `MOTES`, `MOTE_LIFE`,
`MOTE_RISE`, `MOTE_SIZE` set the drifting motes. `FLARE_TIME` is the
flare's fade. `HOVER`, `STEP_OUT`, `SETTLE`, `LIFT` set where the find
settles.

## Stills (rendered, Forward+)

All in `captures/shots/`, which git ignores:

- `kc_walk3.png`: wall, buttress and pier from about 12 m, at the final
  loudness
- `kc_flare.png`: the tomb chest flaring after a slam off the slope
- `kc_rune.png`: the pier broken, the rune hovering beside him

## Proof

- Smoke passes, 0 errors: aqueduct isle with and without `--kit-caches`,
  `zenscape.tscn -- --no-title --kit-caches`, motif yard `sundered_gorge`
  and `editor_hill`, and the motif editor.
- Throwaway drivers in `scratch/`, through the real input. On the isle, a
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
- **Specks are small.** They barely show past about 10 m. The edge glow and
  the motes carry the look at walking distance. From a high fly-past (about
  100 m) the glow is not visible, which seems right for semi-loud. A low
  pass at about 30 m was not captured.
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
