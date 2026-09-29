# The hand is the interface

**The game revolves around the hand.** The God Hand (`docs/scenic/god-hand.md`) starts out showing the creation tools at work. The direction is for it to become how you touch everything: the land, the air, the sky, the time of day, the season and the diorama itself, with most of the menus gone. The user said on 2026-09-28: "the game has to revolve around this kind of animated hand ... that's what's going to really be the draw of the game, that you're really making and carving, creating this world." On the UI they said: "imagine you could reach into the atmosphere and change the color without having to go through a menu item, or you could make it snow ... maybe not remove the UI but greatly simplify it."

This is the direction, agreed in conversation on 2026-09-28. Parts are being built on `feature/hand-world` (see the slice docs `hand-sun-rim.md`, `hand-snow-globe.md`, `hand-turn.md`, `modeless.md`). **"The hand is the mode" (below) is the settled direction for all creation controls.** The clips and wiring that exist are described in `docs/scenic/god-hand.md`.

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

## Verbs on the diorama

Agreed with the user on 2026-09-28, after playing the first three slices (the sun drag, the season rim, the snow globe, the lazy Susan). Each big thing you do to the world is one physical verb you would do to a toy, so the player finds them by trying. Each verb answers a little before it commits (a faster spin starts the sky flickering), so the player feels there is more and pushes further.

- **Spin = time.** A slow turn just shows the other side. A fast spin winds the world forward: the sun races round, days flicker past, the seasons roll on, and the weather changes because time passed. As it slows you land wherever it stopped. The user: "the spin is just a more legible way to change the time". **This replaces the sun drag**, which goes, and the rim's season dial with it.
- **Shake = the snow globe.** It stays the weather verb: snow in the cold, rain otherwise. (A hard shake to regenerate was weighed and set aside.)
- **Spring = raise and sink.** The land behaves like a spring. Pull it down and let go, and mountains spring up; push it the other way and let go, and it springs down into a basin for a lake. How far you pull decides how much.
- **Flip = a new world.** Turn the diorama over, and its other side is a fresh chunk: flipping is starting over.
- **Setting the weather directly** is still wanted whenever the player likes: reach into the sky (cup a cloud and squeeze it, flick it away), and the Mood drawer (M) stays as the precise way.

## The hand is the mode

**This is the direction.** Agreed with the user on 2026-09-28. Where it and older ideas in this doc disagree (tool pots, the tool rail, brushes chosen from a palette), this section wins.

There are no tool modes in the UI. There are still modes, but **the mode is on the hand**: what the hand is doing and how it is shaped is what the player's press will do, and the player changes it by what they do with the hand, never by picking a button. The user: "we're still going to need modes, I think. It's just that the mode is on the hand. The mode is not visible in the UI. Based on a pinch or based on a pull, you can change and morph the terrain to your liking." The only mode outside the hand is the **camera mode** (the right button).

### Where you press

The first slice of this is being built behind `--modeless` (`docs/scenic/modeless.md`).

| Press (left button) | Do | Result |
|---|---|---|
| Rim | push it sideways | the world turns; a fast spin winds time |
| Rim | shake it | snow-globe weather |
| Rim | drag it up and over | flip: a new world |
| Land | pull, release | the spring (below) |
| Land, on a landform | press, hold, then drag | clay (below) |
| Right button anywhere | drag, scroll | camera: tilt, zoom, look round; time is untouched |

### Shaping the land: two layers from two primitives

Everything on the land is **pull** or **push**: the drag's direction, toward you raises and away from you lowers. From those two primitives and a few hand shapes the player can build anything the game allows. The workflow the user described: rough the chunk in with a few quick springs, flatten one into a mesa, then pinch and pull like clay to make the mountains bigger and shape them, and draw a river.

1. **Rough in: the spring.** Fast and playful. Pull and release on bare ground. How far you pull chooses the kind of landform, not only its size: a small spring makes hills, a bigger one a mountain, a massive one a single great massif. Pushing does the same downward: a dip, a pond, a lake basin. The bulge changes character visibly as the pull crosses each threshold (it firms up, a peak forms, it starts to crack), so the player sees what they will get before they let go.
2. **Shape: clay.** Slower and precise, and it works the landforms already there. Press and hold on a landform until the hand takes hold, then drag. The part of the hand doing the work decides the effect:
   - **Pinch and pull** (fingertips): stretch a peak taller, or drag it sideways to lean it or move it.
   - **Palm push** (flat hand): press the top of a mountain into a mesa, or press a hill down.
   - **Thumb drag** (a line): carve a valley or a riverbed that water then follows.
   - **Side-of-hand wipe**: smooth or soften an area.

A quick press-and-drag on bare ground is a spring; a press and hold on a landform is clay. That is how the two layers share the land without a mode switch.

### How the hand chooses its shape

- **Context, first.** The hand reads what is under it and readies the right shape before any press: a pinch over a peak, a flat palm over a broad top, a thumb along a slope, a spring-ready pinch over bare ground. The landforms made in the rough-in become the handles for shaping.
- **The scroll wheel as the override.** Scrolling opens and closes the hand (fingertip, pinch, palm, side of the hand), the old brush size shown as the hand's own shape. Zoom then lives in camera mode (right button held plus scroll).
- **The hand's shape is the only indicator.** No ring, no cursor badge, no tool name. If the player cannot tell from the hand what a press will do, the telegraphing has failed.

### Rules for this layer

- **Telegraph before commit.** Every verb shows itself before it happens: the hover shape, the pinch points on the land, the bulge that grows with the pull. The user asked for this to be polished properly ("mousing over the edge of the chunk looks different ... showing the different pinch points and how things change"); it is a later pass, but nothing here works without it.
- **A wrong guess must be cheap.** Context will sometimes read the land differently from what the player meant. The shape shows before the press, the scroll wheel overrides it, and one undo takes back any press.
- **Water, seed and pollen are things the hand carries, not shapes it makes.** How the player picks them up without a tool rail is still open.

### Open questions

- How a hold is told apart from a slow start of a drag (the hold time, and what the hand does as it takes hold).
- Whether the spring's thresholds are fixed landform kinds or a continuous scale with named bands.
- How water, seed, pollen, wind and paths are reached with no tool rail.
- Whether the camera mode is the right button only or also a held key.

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
