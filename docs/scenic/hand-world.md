# The hand is the interface

**The game revolves around the hand.** The God Hand (`docs/scenic/god-hand.md`) starts out showing the creation tools at work. The direction is for it to become how you touch everything: the land, the air, the sky, the time of day, the season and the diorama itself, with most of the menus gone. The user said on 2026-09-28: "the game has to revolve around this kind of animated hand ... that's what's going to really be the draw of the game, that you're really making and carving, creating this world." On the UI they said: "imagine you could reach into the atmosphere and change the color without having to go through a menu item, or you could make it snow ... maybe not remove the UI but greatly simplify it."

This is a direction only, agreed in conversation on 2026-09-28. None of it is built. The clips and wiring that exist are described in `docs/scenic/god-hand.md`.

## What it is

It is a cozy Black & White. Black & White (Lionhead, 2001) built its identity on the hand, and the user had been drifting towards it before they knew the game (they had a beach ball). The hand is what we borrow from it: moving the camera by grabbing the land, throwing things with weight, and the hand's shadow being noticed. The god-game structure stays behind: worship, good and evil, villagers, a pet creature. ZenScape is about tending a place. You offer something and the world decides what it becomes (`docs/scenic/handful.md`). In Black & White the world obeyed you.

Black & White's gesture system is the lesson. You drew symbols to cast miracles, misreads made the magic feel broken, and that is what people remember as frustrating.

## Rules

- **The mouse drives and the hand interprets.** The player never has to perform a gesture correctly. They drag, flick, hold and click as usual, and the hand turns that into something expressive. A fast drag over trees becomes a shoo, and a slow one becomes fingers combing the canopy. There is no gesture recognition.
- **Where you reach is what you touch.** Zones replace menus (below).
- **The hand's shape shows what it can do.** Before any click, the hand changes with what is under it: reaching open near the sun, fingers spread over trees, ready to pinch over bare ground, cupped over water. That hover shape is the affordance.
- **You release, and the world decides.** The hand offers and the world answers. A snap asks for a rainbow, and the world arches it where the sun and rain allow, or not at all. Shaking the diorama brings snow in winter and rain otherwise.
- **Feel comes first.** A hand that lags or goes vague is worse than a plain UI, so responsiveness is part of the design. The polish bar is Nintendo's, the same as the clips.

## Reach zones

| Zone | The hand there | Replaces |
|---|---|---|
| **Ground** | Pinch up, press like clay, carve with a thumb, wipe smooth | Land and path brushes |
| **Air just above** | Sweep pollen, shoo wind, cup water | The sowing tools (already handfuls) |
| **Sky** | Drag the sun, tint the air, pull clouds in and squeeze them | Time of day, the Mood drawer |
| **Rim of the diorama** | Turn it, tilt it, shake it, turn the season dial, dip into tool pots | Camera buttons, the season scrubber, the tool rail |

Camera and hand compete for drags. The rule still has to be settled. One candidate: dragging empty space or the land moves the camera, as Black & White did by grabbing the ground, and dragging something the hand can hold (the rim, the sun, a cloud, a handful) is the hand's.

## Ideas

### The diorama
- **Turn it like a lazy Susan.** Grab the rim or the land and push the world round. A flick spins it with weight, and the hand reaches in to catch it with a small settle. This is the most frequent interaction, so it sells the hand fastest.
- **Tilt it to look underneath.** Lift an edge and the world tips, which fits the cave cutaway.
- **Shake it like a snow globe.** Grab the rim and shake, and it snows (or rains, depending on the season). This could be the game's signature moment.
- **Idle.** The hand rests on the rim, drums its fingers, catches a falling leaf, or bats the beach ball across the diorama.

### Sky, time and season
- **Drag the sun** along its arc to set the time of day. Let go and it drifts on, slowing. After sunset the moon rises on the same arc.
- **Turn the rim as a season dial**, and the snow line and leaf colour follow it (`docs/scenic/mood.md`).
- **Snap** for nightfall or dawn, as a shortcut once the slow way is known.
- **The hand as night light.** Warm light at night that draws moths and creatures.

### Colour and mood
- **Colour from the world.** Pinch a colour from something in the scene (a sunset cloud, a flower, the lake) and release it into the sky, and the atmosphere takes the tint. Dropping it on the grass warms the grass towards it. This replaces the colour picker.
- **Mood orbs.** The Lantern mood drawer already shows moods as glass orbs. The hand holds one and crushes or releases it into the sky, and the new atmosphere spreads out from that point.

### Weather and small wonders
- **Clouds.** Cup mist up off the lake, carry it and squeeze for rain, or pull a cloud in from the horizon, or flick it away to clear the sky.
- **A snap for a rainbow**, only where the conditions allow.
- **A clap for thunder**, reusing the wind tool's clap ring.
- **Fire.** A snap throws a spark, and pinching a flame puts it out like a candle.

### Wind and plants
- **Shoo.** The back of the hand sweeps sideways and the gust follows it. Holding makes the hand cup and turn a swirl. The wind tool (`docs/scenic/wind-gust.md`) already makes the effect, so this needs clips.
- **Comb the trees.** This replaces the old 2D hand. Fingertips part the canopy and trees spring back with follow-through, using the tread-wake field.
- **Palm down** bends a whole grove at once, and it rebounds.

### Terrain
- **Pinch** and **press** exist.
- **Drag a thumb** to carve a valley or riverbed that water then follows.
- **Wipe** with the side of the palm to smooth ground or undo.

### Creatures
- **Hold an open palm still** and birds land on it. Lay a flat hand on the ground and a frog may hop on. Sudden movement startles them.
- **The hand's shadow** makes deer look up and step away.

### Tools and photos
- **Tool pots on the rim**: water, pollen, a wind jar, clay. The hand dips into one to take that tool, and its shape then shows what it holds, so no button needs to light up.
- **Finger frame.** Thumb and index make an L, and that enters photo mode.

## Down to the ground

From above you are the hand shaping the diorama. The other half of the game is being small inside what you made. You drop a wanderer into the world, or slip into a creature, and see it first-person. The user on 2026-09-28: "a way for you to kind of see the world unfold in a different cinematic perspective."

**It is all presentation for now.** Nothing is steered. The wanderer walks on their own and a creature follows its own mind. You watch through their eyes. Interactions may come later. This keeps "the world decides" even at ground level.

- **The wanderer** is anonymous. They are not you and not a camper, just the world's first-person camera, set down to discover the wilderness you made. They roam across the chunk atlas (`docs/chunk-atlas/DESIGN.md`), which is what makes the atlas worth walking: one 28 m chunk is about 20 s on foot.
- **Creatures.** You ride along behind a creature's eyes.
  - A bird tours the atlas from the air.
  - A fish sees the world from under the water, which needs underwater rendering.
  - Bigfoot is hidden by design (`docs/scenic/life.md`), so riding with Bigfoot could be the rare reward for having found them.
- **The hand bridges the two scales.**
  - Going down: the hand pinches a small figure out of the air and sets it down gently, and the camera goes with it. For a creature, the hand cups the bird or rests on the deer, light passes into it, and the view drops behind its eyes.
  - Coming back: you look up, the hand reaches down from the sky and lifts you out, and the camera pulls back up to the diorama.
- **The live chunk is wherever the walker is.** Only one chunk is animated and has wildlife. Crossing a seam makes the next chunk live and freezes the one behind, which is the arrow-key step triggered by walking. The handoff must not hitch mid-walk, so the next chunk is warmed as the walker nears the border. That is the first technical question. Past the frontier, the fog bank is the edge of the known world, and at the atlas's true edge the earth block drops away.
- **The look at eye level.** Deep depth of field: what you look at is sharp and everything else melts away. Volumetrics, lighting and god rays go up. The user will test this themselves later.
- **Risk.** The Fidelity look (faceted painted ground, no grass blades, diorama-scale props; `docs/fidelity/`) is tuned for viewing from above. At 1.7 m the ground may look bare and the scale may feel wrong. Test the look before building any of the machinery: put a camera at eye height in the Fidelity scene and in an atlas chunk and walk it round.

## What stays as UI

- **Undo**, always within reach.
- **A hint line** that teaches by proximity ("grab the sun" when the hand nears it). Gestures are hard to discover, and an undiscovered snow-globe shake does not exist.
- **A hidden precise drawer** for exact values (hex colours, fog density). The menu becomes the manual, not the way in.

## First slice

Move the bottom scrubber (`scripts/lantern_scrubber.gd`) into the world: drag the sun for time and turn the rim for season. These are the most literal translations, they retire a visible strip of UI, and they test the zone rule and the camera-versus-hand rule before anything else depends on them. Mood orbs and the snow globe come next, then the diorama turn, shoo and comb.

## Open questions

- Is the Lantern shell kept as a fallback (as `--classic-shell` keeps the old palette) while this is built, or does the hand replace it outright?
- Input: mouse only, or trackpad (twist to turn the world) and gamepad too?
- Is the hand always on screen as the cursor, or does it appear only when working?
- The camera-versus-hand drag rule.
