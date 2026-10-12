# Broken plane, round 1: look study

Branch `look/broken-plane` (from `look/plane-parts`). This is a look study only. Nothing is wired into gameplay: boarding, the parked plane in the game and the ledger are unchanged.

## API (`scripts/plane_figure.gd`)

- `set_missing(ids: Array)`: the parts in `ids` (any of `FOUND`: propeller, wheel, cowl, fin, wingtip, windscreen) are missing and show damage. Every other part is on. This applies at once, with no animation.
- `set_found(id, seat := true)`: puts a part back. With `seat` it plays the seating beat. Without it, the part is just there. Either way it keeps a faint glow afterwards.
- `missing()` and `is_missing(id)`.
- `afterglow` (default 40 s) sets how long the faint glow lasts. `hold_glow = true` keeps it on.
- `damage(id)` (static) returns the damage parts as `[mesh, paint, transform]`, in the same form as `piece(id)`.

**Default unchanged.** A figure that has never had a part missing is built exactly as before. Calling `set_missing([])` on it does nothing. The first time a part goes missing, `_split()` cuts that part's triangles out of the joined meshes (using vertex spans recorded in `_join`) and builds each part as its own node. Re-running last round's identity check (every MeshInstance's path, transform, material parameters, and vertex and normal bytes) found all 37 meshes of the default figure identical to `look/plane-parts`. A broken plane costs about 20 extra draws.

## Damage looks

| Part missing | Damage |
|---|---|
| Propeller (with spinner) | A bare steel shaft out of the nose, a flange with four brass bolt heads, and two splintered varnished blade stumps. |
| Cowl | The radial engine is exposed: a dark firewall and crankcase, and five finned steel cylinders with brass heads, rocker boxes and pushrods. |
| Wheel (the right one) | The axle runs on bare past the leg, with a brass collar and an end nut. The plane leans onto it, rotating about the line from the left wheel to the tail skid until the axle end touches the ground (`_tip`, about 10 degrees). |
| Tail fin | A jagged terracotta stub of the fin and the bare rudder post, bent over at the top, with its two brass hinges. |
| Wingtip | The upper wing's right end: the cloth is whole to the rib at 0.2 m, then a ragged fringe of torn cloth (top flaps lift, bottom flaps droop). Both spars run on bare to where the struts meet them, the rear one snapped and bent down, with a broken rib on them. |
| Windscreen | Bare brass mounts: the bottom rail, one post snapped short, the other bent outward, and a glass shard in the corner. |

Everything uses the plane's own paints (steel, dark, brass, trim, cream, varnish, glass), and every solid is faceted.

## Seating beat

`set_found(id)` runs this sequence:

1. **Ease in (0.6 s).** The part starts about 0.2 m off its seat (the propeller in front, the wheel out to the side, the fin above) and turns on the way: the propeller spins in, the wheel rolls. It comes in on an ease-back curve, so it goes slightly past its seat and settles back. A warm glow builds while it moves.
2. **Snap.** The damage disappears and the part flashes. It uses the found parts' own glow shader (`plane_part_glow`) at its peak, then fades over about 0.35 s. A brass ring of light (the parts' `soft_ring`) spreads out level through the part and fades. A small puff of cream dust bursts out.
3. **Afterglow.** A faint rim glow stays for `afterglow` seconds, fading over its second half, or stays for good with `hold_glow`. If the wheel came back, the plane lifts off the axle stub while the wheel moves in.

## Gallery

`studies/broken_plane_gallery.tscn` (`run-broken-plane.command`, and "Broken plane gallery" in the scene picker) shows four planes parked on grass: broken, two parts found, four parts found, and mended (the figure exactly as built). The found parts on the two partly mended planes keep their faint glow.

- **Keys:** Tab / 1–4 / 0 pick a plane or all four, Space finds the next part, S cycles the plane's state, R resets, G keeps the glow on, N switches night.
- **Flags:** `--plane=i`, `--look=x,y,z` (a close-up point in the plane's own frame), `--yaw=`, `--pitch=`, `--distance=`, `--find=n`, `--hold`, `--night`, `--capture=<png>`, `--capture-after=s`.

## Captures (local only; `captures/` is gitignored)

- `captures/broken_plane/row.png`: all four states in a row
- `captures/broken_plane/broken.png`: the fully broken plane, three-quarter front
- `captures/broken_plane/close_wing.png`: close-up of the torn wing, the fin stub and the exposed engine
- `captures/broken_plane/seating.png`: the wheel snapping home (flash and ring), with the plane partly mended

Fixes I made after looking at the captures: the crankcase was a black blob in steel, so it is now dark wood-brown and the cylinders stand out.

Also from last round's review: the found wheel piece (`scripts/plane_parts.gd`) is now tilted 0.45 rad, so its tread shows and it no longer reads as a flat plate.

## Open questions

- The windscreen damage is small and hard to read from the overview. A fallen frame or a crack-star decal on the coaming might read better.
- The lean on a missing wheel is subtle (about 10 degrees) at gallery distance. It could tip further onto a lower wingtip, but then the wing would need a scuff.
- The flash at the snap briefly turns the part nearly white. Is that too strong in daylight?
- Seating in the game: does the found part fly from the pilot's hands to the plane, or seat on its own when the pilot walks up?
- Which wheel is the lost one? Right now it's always the right one, and the wingtip is always the right upper tip.
