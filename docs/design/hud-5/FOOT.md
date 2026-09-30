# HUD 5: the tool roll's foot (Undo, Photo)

The in-game build of section F of Claude Design's "ZenScape HUD 5 Air"
(project `a0f03cdb-c2ea-4ac8-acf0-0b4614cdee5f`, folder
`design_handoff_lowpoly_linen_hud_5_air/`). This folder keeps a verbatim copy of
the handoff's `README.md` and `lowpoly.js`; `lowpoly.js` is the source of
truth. The 4c pieces it hangs from are in
docs/design/materials-tray/HUD-4c.md.

- **What it is:** a separate small piece of the roll's linen, 8 px under the
  roll and as wide (80 px), radius 10, hem inset 4 and radius 7. Two 32 px
  slots with 24 px faceted icons: **Undo** (seed 21, the curled arrow sampled
  in code) and **Photo** (seed 22, the camera). No badges and no counts.
- **Undo** calls NativeChunkEditor `undo`, the path Cmd Z takes. With nothing
  to undo, it does nothing and doesn't look disabled.
- **Photo** calls the scene's `enter_photo`, the same as P. The Lantern shell's
  Photo button is going away, so under the hand scheme the foot is where Photo
  lives.
- **Rest and reach:** it takes the roll's `shown` and `awake` and doesn't keep
  its own, so it rests, wakes and stays quiet during a drag exactly as the
  roll does. It is placed from the roll's `rect()` each frame, so it follows
  the roll's tuck and its height; the Feather will make the roll about 80×480.
- **Tag:** a hovered slot shows the 4c side tag to the right of the foot (4 px
  out, as the roll's tag sits 4 px right of the roll), with its whisper on a
  second line in Spectral 13 px `#d6cbb2`: "or Cmd Z" and "the cloth steps
  out of the shot". Hover and press take 150 ms, linear.

## The hud-hidden switch

`scripts/hand_materials.gd` `hud_hidden`. While it is true, every HUD piece in
the group `HUD_GROUP` ("hud_piece") gets `want(false)` and fades out; setting it
back brings them in. The materials bar and the tool roll are in the group, and
the foot follows the roll. **To add a piece** (the almanac), put it in
`HUD_GROUP` and give it `want(on: bool)`.

Photo mode throws the switch through its `entered` and `left` signals, which the
foot connects (`tool_foot.gd` `_link_photo`), so it works whether photo mode was
entered from the foot, by P, or from the Lantern shell. Photo mode's own
`_hide_chrome` still hides every CanvasLayer as well, so on screen the pieces
go at once rather than fading.

## Files

| File | What |
|---|---|
| `scripts/tool_foot.gd` | the foot: layout, hover, tag and whisper, presses |
| `scripts/hud_icons.gd` | the "HUD 5 foot icons" block: `undo` and `photo` |
| `scripts/tool_roll.gd` | hook: `rect()`, the roll's cloth rect |
| `scripts/hand_materials.gd` | hooks: makes the foot, `tray_under`, `press`, `hud_hidden`, `HUD_GROUP` |
| `tools/probe_tool_foot.gd` | headless probe on the real scene |

## Where the build departs from the design

The `.dc.html` reference wasn't available when this was built. These calls were
made from the README and `lowpoly.js` alone:

- **The slots sit side by side:** 6 + 32 + 4 + 32 + 6 = 80, so the foot is 44
  px tall. The README doesn't say whether they sit side by side or stacked.
- **Slot patch radius 7** (the foot's hem radius), not 4c's 9, on the smaller
  slots.
- **The tag reads "UNDO · BACK" and "CAMERA · PHOTO"**, the entries' name ·
  sub, as 4c tags do.
- **The whispers never retire.** Section D retires the almanac's whispers once
  you've done the gesture; section F doesn't say that for the foot.
- **Hover is half the pressed patch, and a press flashes the full patch** and
  fades over 150 ms. Nothing is held, so the slots are never shown pressed.
