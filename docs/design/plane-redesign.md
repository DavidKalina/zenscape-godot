# Plane redesign: ruins and the lodestone cradle (concept round)

Branch `look/plane-ruin`. This round is concept only: Blender models and renders. Nothing in the game has changed.

## What to look at

All renders are in `art/blender/plane/renders/`.

| Shot | A Salvager | B Builders' craft | C Belfry |
|---|---|---|---|
| 3/4 hero, by a ruin island | `A_hero.png` | `B_hero.png` | `C_hero.png` |
| Side profile (orthographic) | `A_side.png` | `B_side.png` | `C_side.png` |
| Chase camera at cruise, stone seated | `A_chase.png` | `B_chase.png` | `C_chase.png` |
| Chase crop, 2x (inspection only) | `A_chase_crop.png` | `B_chase_crop.png` | `C_chase_crop.png` |

The three side by side are in `lineup.png`.

Extras for the recommended direction (A):
- `A_cradle_empty.png` and `A_cradle_seated.png`: close-ups of the cradle.
- `A_chase_empty.png`: the chase view with the socket empty.
- `A_chase_dusk.png`: the chase view at dusk.
- `A_chase_boost.png`: the chase view at full boost.

The ruin in the shots is the game's own kit (`scripts/ruin_kit.gd`: rose gable, lancet walls, arch, piers, weathered 0.6), not a stand-in. It is exported headless by `art/blender/plane/ruin_export.gd`. The plane and the stone are judged against the real stone.

### Chase camera

The chase shots use the game's maths (`scripts/glide_camera.gd`, `scripts/sky_plane.gd`). At cruise (14 m/s) the camera is 5.2 m back and 1.4 m up, looks 4.2 m ahead and 0.35 m up, with a vertical FOV of about 73°. The figure hangs 0.2 m below the flight. The plane is at its real size (1.4 m span), so it fills about 15% of the frame width. That is the honest test of readability.

## The three directions

All three keep the current proportions from `plane_figure.gd`: body hull rings, 1.4/1.26 m spans, 0.28 m chord, wing heights and stagger, tail, undercarriage, seat. The silhouette class, collision and flight feel are unchanged. The pilot is a stand-in (head and shoulders, from `person_kit.gd`) and is not redesigned.

- **A, Salvager.** The pilot's own warm wood, cream and terracotta biplane, patched with what the ruins gave:
  - The cowl ring is twelve carved basalt voussoirs, a rose-window rim, bolted on with brass.
  - Quatrefoils replace the roundels.
  - Pointed-arch tracery laths sit in the upper wing's rib bays.
  - A riveted bronze patch covers each side.
  - A cream lancet is painted on the fin.
  - The cradle stands on a salvaged column capital.

  It reads as the same plane the user already likes, now visibly part of the ruin world.
- **B, Builders' craft.** Made by the ancient sky-builders, in bronze and pale stone:
  - A bronze hull with verdigris bands and a pale stone spine.
  - The cowl is a rose window: stone rim, twelve bronze tracery spokes, the spinner as its boss.
  - The wings' trailing edges are cut into an arcade of pointed arches, with bronze rib caps as the piers.
  - A lancet-window fin with a mullion, and millstone wheels.
  - The cradle sits in a low tracery corona on a stone cone.

  It is the most "ruin" of the three, but the least cozy. The bronze and verdigris drift toward steampunk, and it loses the warm toy feel.
- **C, Belfry.** The abbey's own plane:
  - Dark oak, with vellum wings painted with red and slate-blue manuscript bands at the tips.
  - A bronze bell for a cowl, and slate tiles down the turtle deck.
  - A red swallow-tailed banner for a fin.
  - The stone hangs in a little oak bell-cote: two posts and a pointed arch.

  It is charming and very distinct. The bell-cote gives the most readable cradle from behind (see below), but the plane as a whole is a bigger departure.

## Recommendation: A, Salvager

- **It keeps the look the user already likes.** The user likes the current look and the warm Porco-Rosso feel; A keeps that intact and adds the ruin identity as story ("I fixed my plane with what I dug up"). That fits the dig-up-a-lodestone loop.
- **It sits best in the world.** The basalt cowl ring and the capital plinth use the kit's own stone colours (`59534d`, `8e887e`), so the plane shares material with the ruins without becoming a ruin itself.
- **It is cheap.** It is closest to the current code, so porting is mostly additive (see below).

One idea worth borrowing from C, if the cradle needs more read at distance: a fixed frame around the hoop. C's lancet frame gives a vertical and horizontal reference to read the stone's tilt against. A's horizon ring already plays that role for pitch.

## The cradle (all three share the gimbal; A's mount described)

**Position.** The stone's middle sits at (0, 0.455, -0.07) in the figure's frame, on the upper wing's centre.

**Height.** It stands about 0.13 m over the wing, so it clears the pilot's head as seen from the chase camera. The head top is about 0.39 at z 0.24. A line from the camera over the head meets the wing's centre at about y 0.32, so anything lower is hidden by the head. This is the main constraint on the cradle.

**Mount (A).** The mount is a salvaged column capital set upside down:
- A square abacus bolted to the wing with brass.
- An octagonal bell with a ring of carved leaf lumps.
- A brass yaw pin rising from it.
- A fixed brass horizon ring (an armillary circle) at the stone's height, on two arms. It has four compass studs, the front one terracotta.

**Hoop (yaw).** A brass hoop (radius 0.082 m) stands across the wing. From the chase camera it is seen face-on, as a gold ring around the stone. It turns about the wing's up axis, on the pin. It has:
- a terracotta pointer stud on top;
- small inward cusps;
- a brass socket cup on each side pin.

**Stone (pitch).** The stone tips between the two pins. It is a hand-hewn basalt spindle, 0.19 m long and about 0.07 m thick, made of six jittered facets. A brass collar round its waist has two trunnions that click into the hoop's sockets. That collar is the "click in" moment.
- Body: dark basalt with a faint warm inner glow.
- Two glowing seams round the waist, pale gold.
- A glowing point at the tip. The tip is the pointer.

**Glow.** The glow is soft, pale gold and warm white. It is additive, so it never covers the stone:
- a faint halo shell;
- a small point light that warms the hoop and wing;
- two thin twisting wisps (1.1 m) streaming from the tip toward the target, fading along their length.

**Reading the direction.**
- From behind, a stone pointing ahead shows its tail end centred in the ring, like a gunsight: "on course."
- Turned left or right, the hoop becomes an ellipse and the spindle shows its length.
- Up or down, the tip rises over or drops under the horizon ring.
- The wisp extends the cue well past the plane.

**Empty state** (`A_cradle_empty.png`, `A_chase_empty.png`). The hoop rests square, the two socket cups face each other across an empty ring, and there is no glow.

**Distance-scaled glow.** The renders use a gentle glow for the close-ups and a bolder one for the chase shots: halo ×5, wisp ×7 strength and 3.6× width (`glow` in `plane_render.py`). In the game this should scale with the distance to the eye. One fixed strength either blows out the stone up close or vanishes at 5 m.

## Triangle counts (`plane_build.py` prints PLANE_TRIS)

| | A | B | C |
|---|---|---|---|
| Plane, fixed parts (incl. mount) | ~7.0k | ~14.1k | ~6.1k |
| Hoop, sockets and collar | 552 | 552 | 552 |
| Stone | 116 | 116 | 116 |
| Glow (halo sphere + 2 wisps) | 720 | 720 | 720 |
| Pilot stand-in (not shipped) | 536 | 536 | 536 |

- B is heavy because of the scalloped trailing edges: 8 stations per rib bay on four wing surfaces. Fewer stations per bay (3 to 4) would bring it to about 8k.
- The glow sphere is 24×14 for smoothness. In the game it would be a billboard quad, and the wisps a ribbon such as `folk_ribbon`.
- The current game plane is roughly 5 to 6k (not measured this round). So A adds about 1.5k for the cowl voussoirs, tracery laths, quatrefoils and capital, plus about 0.7k for the gimbal.

## Porting notes: procedural (`plane_figure.gd`) or imported mesh

**Recommendation: procedural, as now.** The build script was written to mirror `plane_figure.gd`: the same hull rings, airfoil tables, wing stations, constants and game frame. Porting A is therefore additive.

- **Cowl.** Replace the terracotta cowl lip with 12 voussoir prisms. Each is a 4-point section lofted over an arc, so a `_hull`-style helper or `FacetMesh.shell` triangles will do. Add 12 brass `_gem` bolts.
- **Wing marks and tracery.**
  - The quatrefoils are four `_decal` discs plus a centre.
  - The tracery laths are thin strips laid along `_on_top` points, following a pointed arch between `RIBS` stations.
  - All of it joins into the existing per-material meshes (`_join`), so the draw count barely moves.
- **Mount.** The capital is a box, a short `_hull` and 8 gems. The horizon ring needs a small new `hoop` helper: a closed loft of a rectangle round a circle.
- **Gimbal.** These must be live nodes, not joined:
  - a `Hoop` Node3D at the cradle point, turned about the plane's up axis (yaw);
  - a `Stone` Node3D under it, turned about X (pitch).

  Aim them from the target in the plane's local frame: yaw = atan2(-d.x, -d.z), pitch = asin(d.y) (`aim` in `plane_render.py` has the maths in Blender axes). Spring them like the pilot's springs (`PersonKit.Spring`), so the stone swings and settles. That will feel alive and hide jitter.
- **Glow.** Use an unshaded additive billboard for the halo. Use two `ImmediateMesh` ribbons for the wisps, drawn like the scarf (`_draw_tail`), streaming toward the target and fluttering. Use an OmniLight3D with a small range, or none if it costs too much. Scale the strength and width with the camera distance.
- **Liveries.** Sky traffic (`sky_traffic.gd` liveries) should not get the cradle or the lodestone. Keep it to the wanderer's plane (`livery.is_empty()`), and possibly keep the ruin patches.
- **Importing a mesh instead** would only make sense for B (its arcade wings and rose cowl are the fiddliest procedurally). It would lose the livery recolouring, the cloth sag tied to `RIBS`, and the per-material join. Even then, the gimbal must stay live nodes.

## Checks and weaknesses (honest)

- **The cradle is small in the frame at cruise.**
  - The plane is about 270 px wide at 1080p, and the hoop about 30 px.
  - In daylight the ring and halo read as "the gold thing above the pilot's head", and the wisp gives the direction.
  - The stone's own tilt is hard to read at that size without the wisp. In `A_chase.png` the stone points down-left at the ruin, and only the wisp shows it clearly.
  - At dusk (`A_chase_dusk.png`) it reads as a beacon at once.
  - Against a bright white sky the cream upper wing is as bright as the glow. This is the weakest case.
  - Full boost (`A_chase_boost.png`) brings the camera in by only about 20%.
  - A distance-scaled glow (above) is needed, not optional. If more is needed: a slightly larger hoop (radius 0.1), or C's fixed frame.
- **Straight ahead versus up is somewhat ambiguous from behind.** The camera is above, so a forward wisp also climbs on screen. The stone's tip against the horizon ring disambiguates up close, but at chase distance it is subtle.
- **The plane against the ruins.** A and C share the warm wood and cream with the kit's charcoal stone. A's basalt cowl ring and capital use the kit's palette. They look like one world in `A_hero.png` and `C_hero.png`. B's bronze and verdigris are the most "of the ruins", but the least cozy.
- **The lodestone close up** reads as a dark faceted shard with gold seams. In the closest shots the sun's sheen makes its lit facets taupe rather than near-black.
  - Blender's Standard view transform clips the seams toward white; the game's ACES will roll them off more softly.
  - The close-up wisp is still a fairly solid ribbon. In the game it should flutter and thin.
- **Rendering differences.** These are Blender EEVEE renders with Principled materials, not the game's `folk_surface` shader.
  - The wood looks more salmon than in the game, because of the sun strength and the view transform.
  - There is no bloom. In the game, glow and bloom will help the stone read.
- **Not modelled.** The ailerons and elevator are not separate parts, and the prop blur disc is missing. Neither is needed for the concept.
- **Mount and shading.** C's bell-cote posts are plain boxes; a ported version should chamfer them. B's corona arches are thin and alias at chase distance.
- **The pilot is a stand-in.** It is the head, scarf and arms only, from `person_kit.gd` numbers.

## Rebuilding

```
/opt/homebrew/bin/blender -b --python art/blender/plane/plane_build.py
Godot --headless --path . --script art/blender/plane/ruin_export.gd -- /tmp/ruin_vignette.glb
/opt/homebrew/bin/blender -b art/blender/plane/plane.blend --python art/blender/plane/plane_render.py -- [OUT_DIR] [A|B|C] [hero side chase lineup cradle cradleall extra]
```

- `plane.blend` has the three planes (`Plane_A`, `Plane_B`, `Plane_C`, each posed by its `Root_<D>` empty), the gimbal objects (`Hoop_<D>`, `Stone_<D>`, `Glow_<D>`) and the island.
- The kit ruin (about 114k tris, a 20 MB glb) is not committed. The render script imports it from `/tmp/ruin_vignette.glb` if present.
- A new worktree needs the native kernels lib copied in and a headless import before `ruin_export.gd` will run.

## Next steps

1. The user picks a direction, or mixes them (for example, A's plane with C's fixed frame).
2. Port it into `plane_figure.gd` behind a flag. The cradle and gimbal come first, so the stone can be judged in motion at real speed with bloom.
3. Tune the glow scaling and wisp flutter in the game, and check it against bright skies, cloud sea and night.
