Refine "Low-poly on Linen" (option 4a, attached) and add a tool side bar.
Keep 4a's faceted icon system (lowpoly.js: the 4×4 jittered grid, the
diagonal light, the per-tool seeds); it matches the terrain and is the best
part. Change the surface around it so it sits back and matches the game's
quieter tone.

CONTEXT
ZenScape is a quiet diorama builder: a small slab of faceted land floating in
a dusky grey-violet void, shaped by a ghost hand. The title screen sets the
taste: a refined serif, widely spaced small caps, cream type printed on dusk,
hairline rules, nothing bounces. The UI must never compete with the diorama.

WHAT TO CHANGE IN 4a
1. Quieter surface. The cream linen is the brightest thing on screen and pulls
   the eye off the plate. Make it linen in shadow: a dim warm grey-brown that
   sits between the void (#5d6873 to #7a828c) and cream, at about 70–80%
   opacity, so the weave and hem stitch still read. Softer drop shadow. It
   should look like a cloth lying on the maker's bench at dusk.
2. At rest vs. reached for. Most of the time the bar is receded: lower
   opacity, slid slightly down. When the pointer comes near the bottom edge
   it brightens and rises over about 250 ms, with no overshoot. Show both.
3. Type. Replace Nunito 800 with the game's fonts: Newsreader in small caps,
   wide tracking, for tags (for example ACORN · OAK); Spectral 400 if any body
   text is needed. Ink: warm cream #e3d7bd on the dim cloth, or dark ink
   #4a3d2c if the tag stays on light paper; choose whichever reads better
   against the new surface.
4. The name tag. Centre it exactly over the selected slot, not over the slot's
   left end. Make it smaller and quieter: no paper badge, or a very slim one,
   ideally the small caps printed straight onto the linen above the slot with
   a hairline beneath, like the title's rules.
5. No bob. Selection is the slot pressed into the cloth (4a's inset patch)
   plus the icon lit 10%. Nothing loops or bounces. Hover is the pressed
   patch at half strength.
6. Narrower. "Stone · Raise" moves to the side bar (below), which leaves nine
   materials. Aim for 60 px slots and about 600 px total width, so the bar
   stops covering the plate's front edge.
7. Redraw the weak icons, keeping the facet algorithm:
   - Meadow: a wildflower seed head (a small clustered dome on a stem), not
     two red dots, which read as berries.
   - Dandelion: a round clock with visible seed parachutes, not an asterisk.
   - Cattail: a thick brown spike head on a stem with one leaf, not an
     anchor.
   - Stone: a solid, rounded river pebble, not a donut or ring.
   - Frost: a real snowflake silhouette that facets like the rest; drop the
     boxed hexagon fallback so it matches the other icons.
   - Thin icons (willow, dandelion, cattail): thicken the silhouettes enough
     that the facets show at 60 px.

ADD: THE TOOL ROLL (left side bar)
Bottom bar = what you ADD to the world (materials). Side bar = how you SHAPE it
(tools). Design the side bar as a canvas tool roll: the same dim linen, hem
stitch and pressed-slot selection, with tools tucked into stitched pockets.
Vertical, left edge, vertically centred, receded at rest like the bottom bar.
- Tools, top to bottom, each a faceted icon (seeds continuing from 10) with a
  small-caps tag shown to the RIGHT of its pocket:
  1. HAND · MOULD: the default bare hand, a warm translucent hand in three-quarter view.
  2. PADDLE · MASS: a wide wooden paddle for broad sweeps and long ridges.
  3. CHISEL · CUT: chisel and mallet together, for flat faces, cliffs, terraces.
  4. WIRE · SLICE: a taut wire between two wooden toggles, for gorges.
  5. HAMMER · BREAK (optional): cracks rock into scree.
- Below a 4a-style double dashed divider, a SIZE control for the held tool:
  three stitched pips (small / medium / large) or a short stitched slider.
  Tactile, no numbers. Show all three sizes.

ONE THING IN HAND
The player holds exactly one thing across both bars; the bare Hand is the
default. Show: (a) Hand held, nothing pressed in the bottom bar; (b) a seed
held: its slot pressed, the tool roll at rest, and the Hand pocket faintly
outlined ("put this down to go back"); (c) Chisel held at large size, nothing
pressed in the bottom bar.

ALSO DESIGN
- Keyboard focus: a stitched outline.
- Undiscovered slot: the silhouette only, no facets, in a pale linen tone.

DELIVERABLES
Mockups at 1440×810 over the attached game-bg.png: at rest; bottom bar
reached for; states (a), (b) and (c). An updated lowpoly.js with all tool and
material data, and a README in 4a's handoff format, including the new tokens.
