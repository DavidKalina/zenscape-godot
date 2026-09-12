# A home for Bigfoot — flow prototype

## Question

Does **boot → make a landscape → play with its inhabitant → carry him into a
neighboring biome** feel like one continuous cozy toy?

The new direction is a cozy Bigfoot diorama game. Character selection is deferred.
The player starts with one Bigfoot already living in the scene. Building is part
of play, and moving him to a new place preserves the home he left behind.

## Try it

Open `studies/cozy_flow_prototype.tscn` in Godot and press F6 to revisit this
lightweight study. F5 and `./run-cozy-flow.command` now open the
[full native-world version](REAL-WORLDS.md).

1. Keep the opening clearing, choose Gentle hills or Empty patch, or Roll another.
2. Choose Tree, Flowers, Pond, Log, or Little hill, then click an open spot. The
   preview ring turns green where placement is available. Bigfoot can investigate
   additions in his current habitat while you keep building.
3. Home starts centered, with Snow already available on the wheel. No setup button is needed.
4. Pick Bigfoot up and move toward either side of the screen. The neighboring
   landscape peeks in within the outer 16%. Hold within the outer 6% for 0.55 seconds
   to turn it into view. Bigfoot stays in your hand while the landscapes slide along
   a shallow arc beneath him.
5. Move inward and drop on a green landing ring. He investigates snow on arrival.
   Pick him up and use either edge again to bring home around, with your edits intact.
6. Undo reverses generation and placement. It restores the
   resident to the saved safe location associated with that edit.

Right-drag orbits. Scroll zooms when Bigfoot is not held. Center this place resets
framing. Escape cancels a carry, restores the chunk and safe feet where pickup
began, and selects Hand. Cmd/Ctrl-Z undoes. Losing focus also cancels.

Pull away before the dwell completes to retract the peek. Each turn takes 0.8
seconds. Holding still at the edge never advances again: move into the middle 60%
of the screen to rearm, then approach an edge for another turn. With two chunks,
either direction wraps to the other place. Top/bottom controls do not trigger travel.

Release during a turn waits for it to settle, then attempts placement at the release
position. Invalid drops (including the outer edge, controls, off-screen, steep ground,
or occupied ground) return to the original chunk and safe spot. Arrival belongs to
the successful drop; simply browsing the wheel does not move his residency.

## Deliberate limits

This is a disposable native Godot study, with simple procedural scenery and the
existing animated Bigfoot asset. The two chunks are session-only and never touch
existing diorama saves. There is no character creator, camper simulation, needs
management, biome unlocking, full terrain brush suite, audio pass, or production
landscape-editor integration. Ponds and resting logs are visual placements rather
than the existing physical water/prop simulation.

Bigfoot takes short unobstructed walks, looks around, rests, and reacts to nearby
building. This is a small behavior sketch, not a relationship or memory system.
The snow visit is remembered only during this session. His original chunk and its
edits persist when he travels back and forth during that session.

## Validation — September 12, 2026

Godot 4.7.2 loads and runs the scene headlessly. A temporary scripted exercise
passed 20 checks covering inhabited boot, viewport fit, empty-patch crafting,
tree/flower placement, successive undo, generated hills, preserving home when
expanding, fast cross-chunk drops, the snow reaction and visible snowball, safe
roaming, returning home, gap/off-world release, cancel, expansion undo, and minimum
window layout. Headless startup also logs a macOS system-certificate diagnostic;
no GDScript errors occurred in the passing run.

The Forward+ Metal window was inspected directly. Both chunks and the full control
tray are visible. A real fast mouse drag moved Bigfoot from home into the snowy
patch and triggered his arrival reaction. This exposed and fixed a release bug:
the destination now follows the cursor preview rather than the still-interpolating
body. Rendering checks also corrected Retina UI scaling, clipped bottom controls,
vertex-color conversion for terrain, and the coat's imported vertex colors.

## Wheel pass validation

A temporary Godot exercise passed 22 checks covering the single visible chunk,
neighbor creation, peek and retreat, dwell threshold, held travel, stable screen
position, no repeat while held at the edge, rearming, arrival, preserved home,
return travel, queued release, cancellation during/after a turn, controls exclusion,
undoing expansion, and the one-chunk case. Forward+ Metal renders of the home,
peek, turn, and snowy arrival were inspected. Simple terrain remains intentional:
full-detail world integration follows the interaction playtest.

## Playtest verdict — pending

The user liked the first prototype and requested the edge-driven wheel interaction.
The wheel now needs a playtest for its timing, preview, and sense of turning places
beneath the held character. Try building something, visiting snow, and coming
home without treating this as a checklist. Notice whether carrying feels natural,
whether arrival is rewarding enough, and whether another chunk feels like an
appealing extension of the home.

After that verdict, absorb the accepted interaction and flow into the main diorama
or delete this study. Do not treat these primitive landscapes or this small behavior
controller as a production architecture decision.

## Peek startup fix

The original wheel required adding Snow before either edge could do anything. This
was invisible to someone simply picking Bigfoot up and following the carry hint.
Both destinations now exist on boot, with only Home visible. The preview also
travels farther inward so it appears before reaching the turn threshold. A revised
22-check exercise covers fresh-boot travel and asserts projected terrain corners
actually enter the viewport, alongside retreat, dwell, rearming, arrival, and cancel.
