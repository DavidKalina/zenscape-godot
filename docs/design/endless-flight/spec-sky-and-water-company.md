# Spec: company in the air and the water

Slug: `company`. Trail prefix: `ITER(company):`. Branch: `claude/game-feel-animation-3a7809`. Cap: the skill's default.

The rule for both lanes comes from play: life is a rare surprise, placed where the player will see it. Set rarity first, in seconds flown in the right place, randomised so no rhythm shows. Motion comes before polish. Sizes and speeds are knobs. Visual only: nothing collides or touches the flight. Medium weight, with and without Boost, seed 1.

There's no trunk: the two lanes need nothing from each other. When both land they're merged here, smoke checked and flown by the user.

## Lane `escort`: birds that join you in the air

Done: flying clear of the ground, every minute or so a small flock comes in from off screen, flies round the plane, keeps it company for several seconds, then leaves.

- The player sees it arrive: from off stage, overtaking or crossing, not fading in.
- They settle round the plane where the chase camera shows them, loose and shifting, not a rigid formation. Some ahead and to the sides, against the sky.
- They stay for about 6-10 s, then break off and leave the frame.
- Works at cruise and on Boost, and in gentle turns. They cheat their speed to keep up; that's fine as long as it reads.
- Same dark starling plumage as the other birds (`scripts/endless/endless_birds.gd`), unless a bigger bird reads better up high; say so if so.
- A knob, `--escort-gap=S`, and an off switch, `--escort=0`.

Files: a new script beside `scripts/endless/grass_birds.gd` plus a flock state in `endless_birds.gd`. The existing RIDING state is a starting point.

## Lane `swimmers`: bigger leaps, and a fish you can see beside you

Done: the existing hero leaps gain larger fish that jump higher, and a new rare moment where a big fish swims next to the plane, visibly.

- Big leaps: a new, rarer size among the hero leaps, longer and clearing clearly higher than today's. Weight shows: a heavier splash and a slower-looking arc.
- The swimmer: over a lake, flying low, a large fish or a small group comes up beside the plane and paces it just under the surface. It's a visible shape in the water, with a bow wave or a fin cutting the surface, a real presence alongside you, like the burrower (`scripts/burrower/`) except that you can see the thing itself. It stays several seconds, may breach once, then dives away.
- It's seen from the chase camera on both cruise and Boost. The water must show it: find out how the sea shader treats things under the surface, and fake it with a shape drawn into or on the water if need be.
- Knobs: `--swim-gap=S`, `--swimmer=0`, `--leap-big=X` for the big fish's share and size.

Files: `scripts/endless/wake_fish.gd` for the leaps; a new script for the swimmer.

## Checks

Smoke check on `studies/endless_flight.tscn`. A throwaway driver through the real play loop, with a wobble in the line, reporting gaps over several minutes. Rendered frame sequences from the chase camera, at cruise and Boost, midday and evening. No committed tests.
