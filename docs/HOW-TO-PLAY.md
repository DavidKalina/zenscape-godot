# How to play

Launch with `run-cozy-flow.command`, or press F5 in Godot. The game opens on
the title: a generated world the camera orbits, under the menu. **Continue
your world** picks up your last place; **Create a new world** starts a blank
Genesis plate. In a world, **Esc** brings the menu back. There is no toolbar, palette or
button column: the hand is the only way to touch the world. There are no tool modes: the **left button is the hand**,
and what it does depends on where you press. The **right button is the eye**.
The hand's pose shows what a press will do before you press, and **Cmd+Z**
takes back any shaping.

## First steps

A new player gets a small card that asks for six things in turn: look round,
raise a peak, thumb a groove, pour water, bend a tree and turn the world. It shows one at a time, puts the tool you need in your hand and rings its pocket, and goes away
when you finish or press **Skip**. **Esc**, then **Field notes**, lists
everything the hand can do. What you have found reads in full. What you
have not shows only a clue. "Walk me through it again" brings the card back.
Details are in [docs/scenic/first-steps.md](scenic/first-steps.md).

The design, with the numbers, is in [docs/scenic/modeless.md](scenic/modeless.md).
`--classic-controls` brings back the old shell: brushes, tool rail, Craft, the
World menu and the Cmd+K palette.

## The eye (right button)

| Do | Result |
|---|---|
| Right-drag | tilt and look round |
| Scroll or pinch | zoom |

The hand fades while the camera moves.

**V** (a first test for a person who roams the chunk) sets a small figure down
on the land under the pointer and looks out through its eyes: move the mouse
to look, **WASD** or the arrows to walk, **Shift** to run, **V** or **Esc** to
step back out. The figure stays where you walked it; V off the land steps back
into it. It is not saved with the place.

## The land (left button on the ground)

The Modeller (the tool roll's first pocket) is the fine tool, for the work
water follows: streams, notches, a pond's lip, a little dam. The big shapes
are the Mountain's, the Hills', the Ravine's and the Chisel's.

| Do | Result |
|---|---|
| Tap | a small poke; nearby creatures look round |
| Drag slowly | the **thumb** digs a stream bed about 0.6 m deep and 2 m wide; water will run along it |
| Rub fast, back and forth | smooths the ground |
| Press, **hold still a beat**, then drag up or down | the hand closes into a **pinch**: up raises a knoll (at most 1.5 m), down sinks a dip |
| Shift + drag | the **palm** levels a flat pan that a pond can fill |
| Shift + hold, then drag | a smaller, gentler pinch |
| Thumb a groove **out through the edge** | notches the rim into a spillway; water pours off the chunk into the void |
| Press a **tree** and drag | bends it; let go and it whips back |
| Bend it all the way over | its spores shake loose into your hand; sweep and let go, and its own kind grows. It then rests for a while |
| Shift + press a **tree**, shrub, fern, flower or reeds | **plucks** it: it pops out of the ground in a puff of soil and leaves. Nothing grows back on that spot; Cmd+Z puts it back |

Props and creatures under a press keep their own grab.

## The Mountain (tool roll)

With the **Mountain** (the pick in the tool roll, "Peak") a press pulls at once,
no holding still:

| Do | Result |
|---|---|
| Press and drag up | a peak pulled out of the land, its summit following the pointer |
| Press and drag up **and sideways** | the peak stretches into a **range** from the press to the ground under the pointer: several summits along a jagged crest, tapering at both ends. Up is still the height; sideways is the length, up to about 20 m |
| Shift + press and drag | a smaller peak, or a shorter range |

A pull straight up stays a single peak: a little sideways wobble on the way up
is ignored. The Mountain only builds up: a pull down does nothing. Let go and
the peak or range takes the mountains' rock. One Cmd+Z takes back the whole
pull.

## The Crater (tool roll)

The Mountain turned over. Press and drag down: a crater opens under the
press, a level floor following the pointer down and a rim of thrown-out
ground standing round it. Shift makes a smaller one. A pull up does nothing.
One Cmd+Z takes back the whole pull.

## The Ravine (tool roll)

Draw a line on the land with the Ravine and let go: the wire is drawn
through the land along your line, bends and all, from where you pressed to
where you let go, and a deep, steep ravine opens behind it. Drawn out
through the rim, it opens the plate's side, with its bed rising to the ground line over
the last few metres, so the ravine can still hold water: pour into it with the
can and it fills level to the brim, and what is poured past that spills off the
side. To lower the level, take water out with the Water compartment (below). **Draw a loop** (end where you
started) and the inside sinks to a level floor: a lake basin, the line its
shore. Shift makes it shallower. The pips widen it. Each drawing is one
Cmd+Z.

## The Chisel (tool roll)

The Chisel's modes fan out beside its pocket: **Mesa** (hold, then drag up
for a flat-topped block or down for a pit), **Shelf** (drag a terrace),
**Notch** (tap a step) and **Slice** (hold, then drag up or down: cuts a
hilltop off level). Shift makes each cut shallower.

## The Paddle (tool roll)

The Paddle tidies up. Its modes fan out beside its pocket: **Plane** and
**Pat** (tap to flatten bumps). Q and E step between them, and Shift narrows
the blade.

**Plane** is for a quick change of ground: drag, and the ground under the
blade levels to the height where you pressed. It is also laid afresh as the
surface picked on the swatches under the fan: grass (the default), earth,
rock or sand. Rock, from a mountain or the Brush, planes back to grass.
Each stroke is one Cmd+Z.

## The watering can (tool roll)

Hold to pour where the rose hangs; drag to run water along a groove; Shift
sprinkles. **Hold it still over a hollow** (a crater, a pan, a basin or ravine drawn
with the Ravine, or a pond already standing) and after a moment it builds to
a gush, nine times as strong, and fills the hollow to its brim in seconds.
Move on and it eases back. Held still on a hilltop or a slope, where the
water runs off, it stays gentle and plants a spring.

## The edge (left button on the rim or the block's walls)

The **rim** is the plate's top edge, the last metre or so of land. The
**walls** are the earth block's sides, all the way down. Aim for the edge
itself, not the land near it.

| Do | Result |
|---|---|
| Push sideways | the world turns; spin it fast and time winds on (days, then seasons) |
| Shift + push sideways | turns without winding time |
| Shake | snow-globe weather: snow in winter, rain otherwise |
| **Pull down**, let go | the block dips while you hold; on release the shapes you made spring up bigger (a blank plate gets a random range instead). Pull harder for more; the pointer won't run out of screen |
| **Keep pulling** past that, let go | the whole plate fills with height, a plateau to carve valleys and ravines into with the thumb |
| Pull up, let go **slowly** | a basin sinks |
| Pull up, **flick** | tosses the block; flick hard enough (or catch it and flick again) and it flips over into a new world |

While you pull down, the camera holds still, so you watch the block sink. The block squashes
under the load, the trees stretch up behind it, and the earth creaks louder
and higher the further you pull. Only a deep pull makes the camera follow,
and slowly. When you let go, the block shoots up past its rest and stretches,
the range bursts out of it, and a beat later the camera catches up, rises a
little too far and settles.

`--pull-cam=a` is the default described above. `--pull-cam=b` also swings
the camera low to see the block from the side and back again after,
`--pull-cam=c` swings low and stays there, and `--pull-cam=old` brings back the old camera, which leaned down
with the block. See [docs/scenic/modeless-spring.md](scenic/modeless-spring.md)
under "Pull feel (experiment)".

## The sky (left button off the diorama)

| Do | Result |
|---|---|
| Hold still in empty sky | calls the **cloud** into your hand |
| Press the **cloud** and pull | it stretches after your hand; pull far enough and a tuft tears off. Let go short and it springs back |
| Swipe empty sky | a **gust** blows across the land the way you swiped, harder the faster you flick |
| Drag from empty sky onto the land | you hold the **wind**: the plants lean under your hand. Keep swiping and let go to send a gust along the swipe, or hold still and let go for a burst |
| Press empty sky, pull and hold | the prevailing wind turns the way you pull, stronger the further you pull, and stays when you let go |
| Carry the tuft over the land | it becomes a **water ball** that fills from the cloud while you hold it; let go to drop it. On high or steep ground it becomes a spring. The water runs in a live simulation: it fills grooves, pools in palm pans and pours off notched edges |

Day and night live on the almanac, the linen strip on the right: click its
sun (or moon) for night or day, Shift-click to step dawn → midday → dusk →
night. `--void-snap` brings back the old click in the sky.

The cloud's grey belly shows how much water it holds. It shrinks as it gives
and refills in about a minute; a dry cloud won't tear.

## The tray (experiment)

Along the bottom edge sits a field case, a short, low case with a
compartment for each kind of specimen, left to right:

- **Trees**: **acorn** (oak), **pine cone**, **willow catkin**, **birch
  samara**, **redwood** and **juniper** (Joshua
  is held back with the desert)
- **Flowers & crops**: **wildflower**, **dandelion**, **poppy**, **cosmos**,
  **sunflower**, **wheat** and **reed**
- **Water & stone**: **water** and a **river stone**
- **Build**: a **stone lamp**, a **campfire**, a **cabin**, a **fence** and a
  **footbridge**
- set apart past a stitched line, one you haven't found yet

Each compartment shows one specimen, the last you took from it. Rest the
pointer on a compartment and its specimens fan out above the case on a scrap
of the same linen. Move along the fan and press the one you want; the
compartment shows it from then on, so pressing the compartment itself takes
the same thing again. The three stitches along a compartment's top mean it
fans out. The case stays faint until the pointer comes near. Hover a
specimen, on the case or the fan, to read its name. Faint outlines are kinds
you haven't found yet, and pressing one gives nothing. The command palette
(Cmd+K) still takes any of them by name.

| Do | Result |
|---|---|
| Press a compartment, or a specimen on its fan | the hand takes some: a pinch of seeds or a stone, a cupped hand of water. Its compartment shows it, pressed in, while you hold it, and the fan folds away |
| Tree seeds: tap | plants one tree of that kind where you press, if the ground takes a tree there and there is room |
| Tree seeds: drag | paints a wood of that kind under the brush; go over it again, or linger, to fill it in. Shift-drag thins the trees under the brush. Not on water, rock, snow or too near another tree |
| Flowers: press and drag over the land | paints flowers under the brush; go over them again to thicken the drift. Shift thins them |
| Wheat: press and drag over the land | paints a wheat patch in tidy rows under the brush; go over it again to fill it in. It sways with the wind as one field, and with the clock running it is green in spring, gold by late summer and stubble in winter. Shift thins it; Cmd+Z undoes a stroke |
| Reed: tap, or drag | sets a clump of reeds; a drag scatters more clumps |
| Water: press and hold over the land | a water ball fills while you hold; let go and it drops, a pool or, up high, a spring. Held over a lake, pond, crater or ravine it scoops the water standing there instead, so the level drops the longer you hold (it stops at the bed). Fill a ravine to its brim with the watering can, then scoop out what you do not want to set its level |
| Stone: tap | sets a stone down, bigger the longer you press |
| Stone: drag | scatters a few pebbles |
| Stone lamp: tap, or drag | sets a small faceted stone lamp; a drag lines a path with them, a couple of metres apart. They glow warm from dusk to dawn. Not on water, and not too close to another lamp: the hint line says why. The trash can takes them away; Shift with the trash spares them |
| Campfire: tap | sets a little campfire, a ring of stones with a fire dancing in it. It burns day and night, glows warm in the dark, smokes a little with the wind and never spreads to the land. Not on water or steep ground, not too close to another campfire, and not under a tree: the hint line says why. Cmd+Z or the trash can takes it away; Shift with the trash spares it ([campfire](scenic/campfire.md)) |
| Cabin: tap | sets a small log cabin, its door turned down the slope (or toward you on the flat). Its window glows warm from dusk and a thin smoke leans from the chimney. It needs a patch of flat, dry ground about 3 by 3.5 m, clear of trees, other cabins and anything standing there: otherwise the hint line says why. The land is never levelled for it. Cmd+Z or the trash can takes it away; Shift with the trash spares it ([cabin](scenic/cabin.md)) |
| Fence: press and drag a line | faint stakes show the way; let go and a split-rail fence follows the line. End where you began for a pen. Press or let go near a fence and the line snaps onto it, a bright ring marking the post: from a fence's end it carries that fence on, from one end round to the other it closes a pen, and anywhere else on a fence it makes a T sharing a post. Posts skip water and steep rock, leaving gaps; they ride the land when you reshape it. One Cmd+Z takes the whole fence, or the piece you just joined on; the trash can cuts it span by span, and Shift with the trash spares it ([docs/scenic/fences.md](scenic/fences.md)) |
| Footbridge: drag across a stream or narrow water | a faint ghost shows the bridge the land would take, snapped bank to bank; let go and a timber footbridge is laid, its ends resting on the banks. Over dry land, across more than 6 m of water, or between banks too uneven, the ghost turns dull red and nothing is laid. Cmd+Z takes it back; the trash can clears it; Shift with the trash spares it ([bridges](scenic/bridges.md)) |
| Click the sky, the case or the same specimen | puts the material back in its compartment |

The trees' spores and the cloud still work as before. `--no-tray` hides the
tray.

## Trees

Every new plain has one wild tree. Water splashing on the land grows trees too.

| Do | Result |
|---|---|
| Press a tree and drag | it bends after your hand |
| Let go | it whips back. Bent far enough, it flicks its spores out the way it whips, further the more you bent it; they drift down in the wind and grow mostly the same kind of tree. The land bends it: an oak's seeds come up willow by water and pine up high, and now and then something new |
| Shift + press a plant | plucks it out, a tree or the undergrowth (a shrub, fern, flower, reeds, a tuft or a mushroom). Hold Shift to see what a press would take: it is outlined. The bare spot stays clear, and Cmd+Z brings the plant back |

A tree that has just thrown its spores only bends for about 45 seconds.
Bending needs a free hand: the tool put down (**Esc**, or press the tool's
pocket on the roll again; pick it to take it back up) or the Feather, not a
shaping tool, which presses through plants to the land. With the tool down a
press on the land does nothing. Plucking works with any tool but the can (whose
Shift sprinkles). The old tree, logs, stumps and
rocks can't be plucked; a pinned plant can.

## Keys

| Key | Does |
|---|---|
| M | mood drawer |
| P | photo mode |
| Esc | close the moods; else put down a held material, else the tool in hand (a free hand bends trees); else the menu |
| R | overview |
| F | glide to what's under the pointer (Backspace goes back) |
| Arrows | pan (Shift+arrows turn and tilt) |
| Cmd+Z / Shift+Cmd+Z | undo / redo |
| Cmd+S | save now |

Every other key does nothing in the hand scheme.

## Launch flags

Pass these after the launcher, e.g. `./run-cozy-flow.command --resume`.

- `--no-title` skips the title and opens a new plain; `--resume` opens the last saved place; `--generated` or `--seed N` opens a generated world. Each of these skips the title.
- `--classic-controls` brings back the tool modes.
- `--pull-cam=a|b|c|old` sets how the camera shows the edge pull (see "The edge" above). The default is `a`.
- `--no-hand` hides the hand; `--planned-water` swaps the live water back to the one-shot plan.
- `--no-tray` hides the materials tray.
- `--square-islands` makes every new plain the 28 m square island the plate used to be, in the middle of today's 48 m plate, as before islands had outlines; places already saved keep the shape they were saved with (places saved before the plate grew open as that square, or the outline they had, in its middle).
- `--no-first-steps` leaves out the first-steps card and the field notes; `--first-steps` shows the card from the top whatever was found before, without saving.
- The lower world under the cloud sea is on by default (`--no-below` turns it off; a run with `--script` has it only with `--below`): dive the plane down into the sea and, deep in its white-out, you come out under the cloud's underside over a sea thick with islands, the mountain ranges standing down into it. Fly low between them; F brings the plane in to the nearest island, and touching down slowly on one lets the pilot out to walk it; run off its edge or press Space in the air to fly on. Climb back up through the cloud to the islands above. Nothing is claimed or built down there. `--landform=<name>[,<name>]` stands those landforms (scripts/landforms.gd: hills, forest, lake, cliffs, mountains, shore, crag) on the islands just ahead of where you come out under the cloud.

### Desert (held back for an update)

The desert is kept out of a default game for launch, to ship later as an
update. `--desert` brings it all back for development: arid title worlds, the
**Red canyon** land on the New world screen, desert compositions in generated
worlds, the **Joshua** seed in the tray and palette, and the **Desert
afternoon** mood. Worlds already made with desert still load and play as they
were. The switch is `ENABLED` in `scripts/desert_landscape.gd`;
`tools/probe_desert_gate.gd` checks both ways.

## Not reachable in the hand scheme yet

The palette's grass brush has no hand verb yet (forest comes from flicking
trees and from water; wind from the sky). Life arrives on the land you make by itself. Use
`--classic-controls` to paint with the brushes.
