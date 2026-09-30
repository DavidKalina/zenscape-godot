# HUD 4c: linen materials bar and tool roll

The in-game build of Claude Design's "ZenScape HUD 4c" (project
`a0f03cdb-c2ea-4ac8-acf0-0b4614cdee5f`, folder
`design_handoff_lowpoly_linen_hud_4c/`; its README and `lowpoly.js` are the
spec). It replaces the naturalist's field case on `experiment/field-case-play`.

- **Bottom bar, materials:** what you add. Acorn, cone, sprig, clover, dandelion
  clock and cattail; water and river stone (plus crystal, not found yet); frost
  (not found yet).
- **Tool roll, left edge:** how you shape. Hand, paddle, chisel, wire and
  hammer in stitched pockets, with three size pips under a double stitch.
- **One thing in hand:** the bare Hand is the default. Taking a material
  clears the roll and stitches a faint "put this down" cue round the Hand.
  To put it down, click the Hand, click the material again, or press Esc.
- **Size:** use the pips, `1` `2` `3`, or `[` `]`. The levels are 0.6×, 1× and
  1.5× the clay's groove, rub, palm and pinch spread
  (scripts/land_clay.gd `size_scale`), or of a scatter's spread and spacing.

## Files

| File | What |
|---|---|
| `scripts/hud_icons.gd` | `lowpoly.js` ported: icon data, the facet generator, SVG text rasterised at draw size (no baked files) |
| `scripts/hud_linen.gd` | tokens, the linen `Cloth` strip, drawing helpers (patches, stitches, icons, tags) |
| `shaders/hud_linen.gdshader` | the cloth: weave, grain, top highlight, dashed hem, soft shadow |
| `scripts/materials_tray.gd` | the bottom bar (API unchanged from the field case) |
| `scripts/tool_roll.gd` | the tool roll |
| `tools/probe_hud_icons.gd` | writes every icon's icon/lit/locked forms to /tmp/zs-hud/icons.png, and checks the clip and the facets |
| `tools/probe_hud_bars.gd` | layout, hit tests, rest and reach, and the "quiet while dragging" rule, headless |

## Where the build departs from the design

- **River stone is back** as "River stone · Place", using `RESERVE.stone`.
  That makes 10 slots and a bar 678 px wide.
- **Birch has no slot.** 4c's seeds don't include it. Dandelion has no species
  of its own: for now it scatters button and daisy flowers.
- **Chisel, wire and hammer show as undiscovered** until they have verbs
  (`tool_roll.gd` `UNBUILT`). The paddle has its verbs
  (docs/design/tools/PLAN.md).
- **The small caps are faked:** capitals at 10 px with 0.22 em tracking. The
  shipped Newsreader has no `smcp` feature.
- **The roll's tag fades out with the roll**, so "HAND · MOULD" isn't
  printed on screen all the time. The bottom bar's tag stays while a material
  is held.
- **A drag never wakes either bar.** That covers edge pulls, clay and
  sowing, so pulling the near rim down doesn't raise the bar under the hand.
- **The inset shadows are approximated** by stacked top bands. The noise
  overlay is a hash grain.
- **Not built yet:** keyboard focus and Tab between slots (the hand scheme
  swallows Tab), and the per-tool cursor marks.
