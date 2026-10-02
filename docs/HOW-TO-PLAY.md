# How to play

Launch with `run-cozy-flow.command`, or press F5 in Godot. The game opens on
the title: a generated world the camera orbits, under the menu. **Continue
your world** picks up your last place; **Create a new world** starts a blank
Genesis plate. In a world, **Esc** brings the menu back. There is no toolbar, palette or
button column: the hand is the only way to touch the world. There are no tool modes: the **left button is the hand**,
and what it does depends on where you press. The **right button is the eye**.
The hand's pose shows what a press will do before you press, and **Cmd+Z**
takes back any shaping.

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

| Do | Result |
|---|---|
| Tap | a small poke; nearby creatures look round |
| Drag slowly | the **thumb** digs a groove about 1 m deep; water will run along it |
| Rub fast, back and forth | smooths the ground |
| Press, **hold still a beat**, then drag up or down | the hand closes into a **pinch**: up raises a peak, down sinks a hollow |
| Shift + drag | the **palm** levels a flat pan that a pond can fill |
| Shift + hold, then drag | a smaller, gentler pinch |
| Thumb a groove **out through the edge** | notches the rim into a spillway; water pours off the chunk into the void |
| Press a **tree** and drag | bends it; let go and it whips back |
| Bend it all the way over | its spores shake loose into your hand; sweep and let go, and its own kind grows. It then rests for a while |

Props and creatures under a press keep their own grab.

## The Paddle (tool roll)

The Paddle's modes fan out beside its pocket: **Swell** (press and drag up or
down), **Sweep** (drag a soft valley), **Pat** (tap to flatten bumps) and
**Plane**. Q and E step through them, and Shift narrows the blade.

**Plane** is for a quick change of ground: drag, and the ground under the
blade levels to the height where you pressed. It is also laid afresh as the
surface picked on the swatches under the fan: grass (the default), earth,
rock or sand. Rock, from a mountain or the Brush, planes back to grass.
Each stroke is one Cmd+Z.

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

Along the bottom edge sits a field case, a long, low case of smoked glass
with one specimen in each compartment. The seeds are **acorn** (oak), **pine
cone**, **willow catkin**, **birch samara**, **wildflower seed head** and
**reed**. Then come **water** and a **river stone**. The case stays faint
until the pointer comes near. Hover a specimen to read its name. Faint
outlines are kinds you haven't found yet, and pressing one gives nothing.

| Do | Result |
|---|---|
| Press a specimen | the hand takes some: a pinch of seeds or a stone, a cupped hand of water. Its compartment stays faintly outlined while you hold it |
| Tree seeds: drag over the land | sprinkles seeds along the way, and the wind carries them down. What comes up leans to that tree, as far as the ground there allows |
| Wildflower: tap, or drag | sows a drift of meadow flowers; a drag scatters more drifts |
| Reed: tap, or drag | sets a clump of reeds; a drag scatters more clumps |
| Water: press and hold over the land | a water ball fills while you hold; let go and it drops, a pool or, up high, a spring |
| Stone: tap | sets a stone down, bigger the longer you press |
| Stone: drag | scatters a few pebbles |
| Click the sky, the case or the same specimen | puts the material back; it glides home to its compartment |

The trees' spores and the cloud still work as before. `--no-tray` hides the
tray.

## Trees

Every new plain has one wild tree. Water splashing on the land grows trees too.

| Do | Result |
|---|---|
| Press a tree and drag | it bends after your hand |
| Let go | it whips back. Bent far enough, it flicks its spores out the way it whips, further the more you bent it; they drift down in the wind and grow mostly the same kind of tree. The land bends it: an oak's seeds come up willow by water and pine up high, and now and then something new |

A tree that has just thrown its spores only bends for about 45 seconds.

## Keys

| Key | Does |
|---|---|
| M | mood drawer |
| P | photo mode |
| Esc | close the moods, otherwise the menu |
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

## Not reachable in the hand scheme yet

The palette's grass brush has no hand verb yet (forest comes from flicking
trees and from water; wind from the sky). Life arrives on the land you make by itself. Use
`--classic-controls` to paint with the brushes.
