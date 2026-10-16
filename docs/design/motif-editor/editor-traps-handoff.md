# Handoff: loop `editor-traps` (traps in the motif editor)

Spec: [spec-editor-traps.md](spec-editor-traps.md). Branch `iter/editor-traps`
(worktree `.claude/worktrees/iter-editor-traps`), 20 iterations, not merged
to main. The trail: `git log --grep='^ITER(editor-traps)' --format='%B'`.

## Play it

```
./run-editor-trap-demo.command                       # the demo: three traps, spawn to far rim
godot --path . res://studies/motif_editor.tscn -- --no-title --load-base=colonnade_spine   # build on a coded isle
```

| Key | What |
|---|---|
| Cmd/Ctrl K, "trap" | the Traps pocket (13 traps); "Base: <id>" opens a coded isle as a base |
| drag a trap | snaps its way in to a cliff lip, then a piece top, then the grid; Alt skips the lip; Z / X turn |
| click a trap | its knobs panel (every knob from the trap's defaults; Reset) |
| P / Shift+P | play from the spawn / under the camera, traps live; P back resets them |
| G | full look on and off (editing is grey by default) |
| H | the pilot grid (1 cell = one plain jump at a run); hold T for ledge steps |
| F / V | frame and orbit the selection / eye view at the pilot's height (WASD walks) |
| 9 | the slope tool: drag top to foot for a slide ramp; drag again for steps |
| Ctrl+S | save (traps saved as recipes in the motif JSON) |

## What's built (one commit each, see the trail)

- Shared trap registry `scripts/traps/trap_registry.gd` (the trap yard reads it).
- Placing, lip snap, clay tint in grey, save/load (`"traps"` in the motif
  JSON, changed knobs only), authored motifs run their traps in the motif
  yard and generator, live play and reset, knobs panel, pilot grid (ground,
  T for ledges), close views, the demo `motifs/authored/editor_trap_demo.json`.
- Grey editing look (8.3 → 4.1 ms a frame) and snappy edits (worst frame
  ~46 ms, coarse land at once, full detail from a worker, freed in slices;
  quit mid-rebuild exits cleanly in ~7 s).
- Coded pool motifs as read-only bases (`scripts/kit_isle/motif_based.gd`,
  `{"base": id, ...}` saves); spawn and markers seated on the base's ground.
- From the user's playtest: the ravine webbing fixed (underside stitching
  and keel depth), the slope tool (with a solid wedge under each ramp so he
  surfs it), rope bridge anchors seated on level ground at the real edge.
- Whole undersides on every isle: `KitLand` `whole_sides` now on by
  default; 75 greybox isles had holes and now have none; isles at a
  multiple of 16 build the same; colonnade spine's open keel closed.

## Open

- **Rope bridge anchor drag** (item 15's second half): select a bridge,
  grab an end, re-snap with `lip_near`, rebuild, one undo step. Also one
  bridge (1.6 m drop over 15 m on editor_trap_demo) got the pilot stuck
  once near an end; not looked into.
- **Steep ground fall-through** outside editor ramps: the pilot can't surf
  (and can walk up) 44-60° land without prisms; a reader-level fix is
  planned in a separate session (handoff outside the repo). Once it lands,
  the editor ramps' wedge (`solid_more`) is redundant but harmless.
- Aqueduct isle as a base: parked by the user (spec, Out of scope).
- Slider ranges are 0 to 3x the default (traps declare no ranges).
- The base's own pieces can't be moved (kit motifs don't name them).
- felled_colonnade FarIsle: 6 underside faces over open air inside its
  outline, unchanged by the stitching; not looked into.
- Tests: none committed (prototype round); the full suite wasn't run.
  `whole_sides` on by default changes undersides of non-multiple-of-16
  isles, and the editor's grey look changes what loads first; a lock-in
  round should run the suite and reconcile.

## Next

The enemies loop, spec [spec-editor-enemies.md](spec-editor-enemies.md),
branches from this one; the user starts it. The parked idea (the editor as
a tool agents use, the registry contract): [idea-editor-api.md](idea-editor-api.md).
