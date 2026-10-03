# Footbridges

Started 2026-10-03 on `feature/bridges`.

A timber footbridge from the case: take it, drag across a stream or a narrow water, let go. The terrain decides. The drag only says roughly where to cross; the bridge snaps from bank to bank over the water it finds, both ends resting on the ground. Where the land will not carry one, nothing is laid.

## The rule

- **Water decides where.** The planner (`scripts/footbridge.gd` `plan`) walks the drag's line in 0.1 m steps, and up to 1.5 m past each end. Water is live water at least 3 cm deep (`scripts/water_flow.gd`), a pond's surface, or a stream bed's course (the same three sources `scripts/life_survey.gd` reads). From the wet sample nearest the drag's middle it walks out both ways to the water's edges, then 0.45 m further onto each bank. Those are the ends. A rill narrower than that still gets a 1 m bridge.
- **Refusals.** Nothing is laid when there is no water near the drag (`dry`), when the span bank to bank would be over 6 m (`too_long`), when the banks differ in height by more than 0.35 of the span (`too_steep`), when an end is off the land or in water (`edge`, `no_bank`), or when the water stands as high as the deck's underside (`flooded`). The hint line names the reason in a few words.
- **Feedback stays quiet.** While dragging, a ghost of the bridge shows: warm and faint where it would go, dull red along the drag where it would not. There is no snapping cursor, no outline and no popup. On a refusal the clump sheds, the case's refusal tick sounds, and the hint line says why.

## The look

Faceted low-poly timber, matching the props: a gentle arch (rise 0.08 x span + 0.1 m, at most 0.6 m) of planks laid across two stringers, a sill log half-sunk under each end, and posts. A span shorter than 2.5 m has only short corner posts. A longer one has posts and a hand rail each side: posts at the ends and middle, plus quarter posts from 4.5 m. Each plank is cut a little differently (seeded by the record id), and every face is flat-shaded in its own tone of weathered brown (deck `8a6a4a`, stringers `5a4330`, sills `4c3a2a`, rails `6f5238`). The tray icon is a timber arch with its posts and rail over a ripple. In hand, the cursor is a little stack of planks.

## How it fits

- **A record.** `NativeTerrainData.add_bridge` stores `{"asset": "bridge", x/z, end_x/end_z}`, marked hand-made, as waterfalls store their two ends. Undo, redo, saving and loading (the document validates both ends) work as they do for any record. `place`, `update_object` and `replace_object_asset` refuse bridges; they have their own two-ended tool.
- **Drawn apart from the instance batches.** `GardenView` draws no "bridge" part. `scripts/footbridge.gd` is a node under the terrain, in plate metres. It redraws when the records change (`objects_revision`) and on every editor refresh. Each end sits on the ground wherever that is now: shaping a bank moves its end with it, and a bridge whose ends have not moved keeps its mesh.
- **Water passes under.** A bridge changes no height and adds nothing to the water grid, so the live water runs under it untouched.
- **Trash can.** The can takes a bridge when any part of its span is in reach, not only its first end (`Trash.reach_of`), and the mesh flies into the can. Shift spares it, as it spares trees and boulders. Explosions, fire, the selection tool and the creation brushes leave it alone.
- **Editor entry point.** `NativeChunkEditor.place_bridge(from, to)` plans, lays the bridge as one undo step and returns the plan. The command palette lists it under Elements.

## Probe

`tools/probe_bridges.gd` (headless) digs a trench in the cozy world, fills it with live water and drags the footbridge across it through real input. It checks the valid ghost, a bank-to-bank snap with dry ends, one undo step, unchanged ground, and that water still stands under the bridge. It then checks:

- the refusals over dry land, a basin 8 m across and banks 2 m apart in height;
- Cmd+Z;
- a trash-can stroke over the middle of the span, and its undo;
- a JSON save and load round trip, plus rejection of a bridge saved without its far end.

```sh
perl -e 'alarm 600; exec @ARGV' Godot --headless --fixed-fps 60 --path . \
  --script res://tools/probe_bridges.gd -- --modeless --no-title --no-rain-runoff
```

## Not yet

- The look is not verified on screen. Headless renders nothing, so the arch, the plank tones, the ghost's colours and how it sits among the props have not been seen.
- Creatures (`scripts/creature_navigation.gd`) do not walk over bridges yet.
- A bridge over a live stream that later dries stays where it is. The land moves its ends, but water drying up does not take a bridge away.
