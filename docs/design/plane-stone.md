# The stone plane (concept round 2)

Branch `look/plane-stone`, based on `look/plane-ruin` (round 1, `docs/design/plane-redesign.md`). This round is concept only: Blender models and renders. Nothing in the game has changed.

The brief: a stone plane that can actually fly. It's an ancient sky-builders' craft carved from the ruins' weathered basalt, with no engine and no propeller. A lodestone heart is why it flies. The wings and hull are carved slabs held apart by thin glowing gaps. A carved rune ring at the nose replaces the propeller. The wing seams are the compass. There is no cradle on the top wing.

## What to look at

The renders are in `art/blender/plane/renders/stone/`. They are gitignored and not committed.

| Shot | A Swift (monoplane) | B Lintel (biplane) | C Feather (strangest) |
|---|---|---|---|
| 3/4 hero, beside the ruin island | `A_hero.png` | `B_hero.png` | `C_hero.png` |
| Side profile (orthographic) | `A_side.png` | `B_side.png` | `C_side.png` |
| Chase at cruise, target ahead and slightly left | `A_chase.png` | `B_chase.png` | `C_chase.png` |

- `lineup.png` shows the three side by side.
- `crops/` holds 3× pixel crops of every chase shot. These are for inspection only: the same pixels, enlarged with nearest-neighbour scaling.

Extras for the recommended variant (A):
- **Directions:** `A_chase_left`, `A_chase_right`, `A_chase_up` and `A_chase_behind`.
- **Empty state:** `A_chase_empty` (no stone seated: seams and gaps dark) and `A_needle_empty` (the chamber empty).
- **Light:** `A_chase_bright` (a bright white overcast sky, round 1's worst case) and `A_chase_dusk`.
- **The hovering needle:** `A_needle`, a close-up of the heart chamber with the needle floating over the stone.
- **Honesty check:** `A_chase_raw` is the chase view without the soft glow ribbons, so you can see what the seams alone do.
- **Optional wisp:** `A_chase_wisp` adds the wisp toward the target.

The ruin in the shots is the game's own kit, exported headless by `ruin_export.gd` (see Rebuilding). The chase camera is round 1's, using the game's maths (`glide_camera.gd`, `sky_plane.gd`) at cruise (14 m/s): 5.2 m back, 1.4 m up, a vertical FOV of about 73°. At 1080p the plane is about 190 px wide.

## The three variants

All three:
- are 1.4 m in span and about 1.5 m nose to tail, the current plane's size;
- use the ruin kit's basalt (`59534d`, worn faces toward `8e887e`, an occasional lichen face), coloured face by face as `ruin_kit.gd` does;
- have a pale-gold glow (`ffd896`) on the seams and a warm white glow on the gaps;
- show only the pilot's head and scarf over a carved stone coaming. The pilot is round 1's stand-in and is not redesigned.

### A Swift: monoplane, an ancient glider (most plane-like)

- **Wing.** A long tapering shoulder wing with a little dihedral and swept, pointed tips. It is three slabs a side, and each wing root floats off the hull on its own gap.
- **Hull.** A sailplane's pod and boom, carved like a sky-boat: a flat deck, chined sides, a keel, and a raised prow. It breaks at three places: either side of the heart chamber, and where the boom leaves the pod. The breaks are slanted, so they read as broken stone rather than sawn segments.
- **Tail.** A cruciform tail: a tailplane in two floating slabs, a dorsal fin and a small ventral fin.

### B Lintel: biplane, a sundered gateway

- **Wings.** The upper wing is a lintel and the lower wing a threshold. There are no struts or wires.
- **Broken columns.** On each side, a broken column stub hangs from the lintel over a stub rising from the threshold, with a soft column of light in the break.
- **Hull and tail.** A deeper sky-boat hull, and a lancet (pointed-arch) fin.

### C Feather (strangest)

- **Wings.** Five stone feathers a side, fanned like a gliding bird's primaries. The long ones are split once by a gap of light.
- **Hull.** A spine of carved vertebrae with gaps of light between them. The heart hangs in an open cage of two stone ribs.
- **Tail.** A floating ring tail in four arcs, plus small tail feathers.

## Recommendation: A, Swift

1. **It reads as a plane at a glance.** It also reads as a light glider: thin wings, a slim boom and visible air between the slabs. It looks nimble and compact, not heavy. It is the only one of the three that has no hint of a World War II biplane: no struts, no wires, no cowl, no propeller.
2. **Its compass reads best for the least clutter.** Two long wing seams, a dorsal fin seam and a ventral fin seam. Every chase shot below reads at the game's real size.
3. **It is the cheapest to port.** It has about 900 stone triangles, against 1350 for B and 2000 for C.

C is the most striking compass, because a whole fan of feathers lights up. But up close it reads more like a rake of planks than a bird. If the user wants stranger, the best mix is A's body with C's ring tail: the tail ring, seen face-on from the chase camera, is a very clear up and down dial. B is the clearest "it shouldn't fly", because of the floating lintel. But it is still a biplane silhouette, and the user's complaint was about the biplane.

## The seam compass

The rule is in `compass()` in `stone_render.py`, written to port as is. Take the target direction in the plane's frame (+X right, +Y up, −Z ahead). Its bearing b is positive to the right, and its elevation is e.

| Channel | Where (A) | Level |
|---|---|---|
| L, R | The left and right wing seams: a carved glyph channel on top (dash, dot, dash) and a glowing band along the blunt trailing edge | 0.3 each when on course. The side toward the target rises to 1 by 30° off; the other side falls toward 0.05. When the target is behind (\|b\| > 90°), the turn side is full and the other side dark. |
| UP | The trailing edge of the dorsal fin | 0 to 1 over 0 to 30° above |
| DN | The trailing edge of the ventral fin | 0 to 1 over 0 to 30° below |
| BK | The tailplane's trailing edges | 0 at 90° off, 1 at 135° and beyond: "it's behind you" |
| RING | The nose ring's glyphs | 0.35, flaring to 1 within 12° of dead ahead |
| GAP | All gaps between slabs | A steady 0.6 while a stone is seated; dark when empty |

How the shots read:
- **On course:** both wings glow equally, faintly gold.
- **Turn left or right:** one wing is bright, the other almost dark. This is the main read, and it is clear at chase size, including against the white sky.
- **Up or down:** the fin above or below the tail lights. From behind, the fins are seen edge-on, as thin vertical lines of light above and below the boom.
- **Behind:** the turn-side wing is full, and the tailplane lights too.

**Brightness curve.** Emission is 0.15 + 9 × level^2.5, so the two sides separate clearly rather than both reading as "gold".

**Why trailing edges.** The chase camera looks along the wings from slightly above, so their top surfaces are seen at a grazing angle. The trailing-edge faces point straight at it. That is why the seams are on the trailing edges and the fin edges, not only on top.

**Glow ribbons.** Each seam also has a soft ribbon facing the camera, about 4–5 cm wide, just behind its trailing edge. Its strength scales with the distance to the eye: 2.6 at chase distance, 0.12 up close. This is round 1's lesson ("distance-scaled glow is needed"), made part of the design.

Compare `A_chase.png` with `A_chase_raw.png`. Without the ribbons, the left/right difference is still visible but much weaker. The game's glow (look_pass: intensity 0.12–0.3, no bloom) will add a little, but not as much as the ribbons.

**Pitch encoding.** I tried leading-edge against trailing-edge seams first and rejected it. From the chase camera, the chord is about 12 px deep, so the two rows would be about 8 px apart. The tail fins are far clearer.

**The needle** (`A_needle.png`) is the up-close magic. It is a slim, four-sided basalt spindle with a glowing north tip and a gold band at its balance point. It floats about 7 cm over the heart stone, in an open-topped trough between two breaks in the hull, just in front of the pilot, and points at the target in 3D.

At cruise it is hidden by the pilot's head, which is fine. It's for boarding, seating the stone, parked shots and landing.

**The empty state** (`A_chase_empty`, `A_needle_empty`): no stone and no needle, every seam and gap dark. The plane is just carved stone and reads as dormant.

**The wisp** (`A_chase_wisp`) is optional. A thin ribbon runs from the nose toward the target. At cruise it is faint, a pale thread past the left wing. The seams don't need it, so leave it out or keep it for boost.

## Triangle counts (`stone_build.py` prints `STONE_TRIS`)

| | A | B | C |
|---|---|---|---|
| Stone (hull, wings, tail, coaming) | 900 | 1348 | 1996 |
| Seams (glyph cores, trailing-edge bands, gap plates) | 1176 | 1872 | 3608 |
| Glow ribbons | 86 | 154 | 208 |
| Rune ring (8 voussoirs, 24 glyphs, blur annulus) | 800 | 800 | 800 |
| Heart, halo, needle | 560 | 560 | 560 |
| Wisp (optional) | 56 | 56 | 56 |
| Pilot stand-in (not shipped) | 536 | 536 | 536 |

A comes to about 3.6k without the pilot, below round 1's A (about 7.7k). The seam glyphs are the biggest single item.
- C's feathers are heavy because every feather carries glyph runs.
- The glyph dots are icospheres; flat quads would halve the seam count.

## Porting notes for `scripts/plane_figure.gd`

Port it procedurally, as now. The build script mirrors the figure's conventions: the game frame, sections lofted through stations, and parts joined per material. Recommended approach: a new `StoneFigure` beside `PlaneFigure`, behind a flag, rather than branching inside `_init`. The silhouette is different enough. Sky traffic keeps the wooden biplane liveries.

- **Stone.** Most parts of `stone_build.py` map onto `FacetMesh`/`_hull`-style lofts of short point lists:
  - `keel_section`, a 7-point section;
  - `section`, a 6-point faceted slab airfoil;
  - `keel_trough`, a U section;
  - the slab `wing()`, which lofts through the stations.

  Join all basalt into one mesh. Colour it face by face like `ruin_kit.gd` `_face`, so it shares the ruins' palette.
- **Seams.** One surface per channel (L, R, UP, DN, BK, RING, GAP), each an unshaded or emissive material. Each frame:
  1. Compute the levels from the target in the plane's local frame. This is a straight copy of `compass()`.
  2. Smooth them with a spring (as `PersonKit.Spring`), so the light flows from wing to wing rather than snapping.
  3. Set `emission_energy` to 0.15 + 9 × level^2.5.

  Seven materials means about seven extra draw calls, which is fine for one hero plane.
- **Glow ribbons.** Use camera-facing ribbons like `folk_ribbon`, along the trailing edges, with additive blending. Scale their alpha with the camera distance: off below about 1.5 m, full at 5 m. Don't use an OmniLight.
- **The rune ring.** Use a `Node3D` at the nose, spinning about Z at `PROP_TURNS`/`PROP_PER`-like rates. Above about 9 turns/s, fade in the blur annulus (as the prop blur does) and dim the glyphs. Make the RING glyphs flare when on course.
- **Gaps.** Thin emissive plates inset 0.82 in each gap, on the GAP material. When unseated, ramp the energy to 0. Optionally close the gaps by a centimetre when the stone is removed: the plane "settles". This is not modelled.
- **Heart and needle.**
  - Heart: a jittered icosphere with a halo billboard.
  - `Needle`: a `Node3D` aimed with yaw = atan2(−d.x, −d.z) and pitch = asin(d.y), on a spring.

  Show both only when a stone is seated.
- **Collision and feel.** The span (1.4 m), length (about 1.5 m) and seat height match the current plane, so `sky_plane.gd`'s collision and flight feel should hold unchanged.
- **The pilot.** The pilot is lowered so only the head and scarf show: the seat is 0.13 m lower and 0.05 m forward of round 1's.

## Weaknesses (honest)

- **Is it nimble or heavy?** A reads as light and nimble in the chase and hero shots: thin tapered wings, a slim boom, air between the slabs. Its side profile is the weakest view: the pod is still a smooth spindle and can read as a torpedo. B is heavier, with a deep boat hull and thick lintel. C reads light but fussy.
- **Is it a plane or a rock?**
  - A and B are clearly planes.
  - C is a plane from behind, but a "fan" or "rake" from the 3/4 view.
  - None reads as a brick.
  - None yet has much "shouldn't fly" mystery up close. The gaps are crisp lines rather than a felt levitation. The strangeness would grow with a slight bob or drift of the slabs in the game (each slab floating a few millimetres out of step), which a still render can't show.
- **The nose ring haloes the pilot.** Seen from the chase camera, the nose ring sits exactly behind the pilot's head. The head projects onto the ring's centre (see any chase crop), so it reads like a halo.
  - Bigger (0.22 m, the prop's size) dominated the hero shots as a cartwheel; smaller hides behind the head.
  - Possible fixes: let the blur annulus take over at speed (in the game the ring spins, which helps), or move the pilot back so the head sits low in the ring.
  - This is unresolved.
- **The ring is crisp, not spinning.** The blur annulus is too faint in these renders to read as spin. Speed is not shown convincingly.
- **Bright sky.** Left and right still part in `A_chase_bright`, but with less contrast than in daylight. The dark basalt silhouette helps (round 1's cream wing didn't), but the dim wing's grey and the white sky make the bright side's pale gold less punchy. A warmer, more saturated seam colour at distance might help.
- **The glow ribbons do much of the work at cruise.** `A_chase_raw` shows that the seams alone are weaker. The ribbons need to be built and tuned in the game.
- **Up versus down from behind** relies on thin fin edges, about 25 px tall. That is clear in `A_chase_up`, but a quick glance may miss it. C's ring-tail arcs are a stronger pitch dial.
- **Close-up issues.**
  - The gap plates read as flat cream panels in tight shots (`A_needle`), even though their glow is reduced when near.
  - The glyph dots are tiny.
  - The heart stone is a plain faceted lump: the "tiny world inside" is not modelled.
- **Rendering differences.** These are EEVEE renders with the Standard view transform and no bloom, using Principled materials rather than the game's shaders. The game's ACES will roll the seams off more softly.

## Rebuilding

In a fresh worktree:
1. Copy `native/terrain_kernels/bin/`, `zenscape_kernels.gdextension` and its `.uid` from the main checkout.
2. Run `Godot --headless --path . --import`.

Then:

```
Godot --headless --path . --script art/blender/plane/ruin_export.gd -- /tmp/ruin_vignette_stone.glb
/opt/homebrew/bin/blender -b --python art/blender/plane/stone_build.py
/opt/homebrew/bin/blender -b art/blender/plane/stone.blend --python art/blender/plane/stone_render.py -- [OUT_DIR/] [A B C] [hero side chase lineup best]
```

- `stone_build.py` reuses round 1's helpers by importing `plane_build.py` (its `main()` now runs only as a script).
- `stone.blend` is committed (300 KB). The ruin glb (about 20 MB) is not.
- The crops in `renders/stone/crops/` came from a throwaway pixel-crop helper and are not part of the tools.

## Next steps

1. The user picks a variant, or a mix (A's body with C's ring tail is the strongest candidate).
2. Port it behind a flag as `StoneFigure`. Do the seam compass, ribbons and needle first, so the read can be judged in motion, with spin, a slab bob and the game's glow.
3. Resolve the halo-ring problem in motion.
