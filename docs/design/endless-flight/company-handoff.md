# Handoff: company in the air and the water

Loop `ITER(company)`, spec `spec-sky-and-water-company.md`. Two lanes, merged on `claude/game-feel-animation-3a7809`; not on main.

## What's built

- **Escort** (`scripts/endless/sky_escort.gd`, ESCORT state in `endless_birds.gd`): about once a minute flying clear of the ground, 7-12 starlings come in from off screen (overtaking past a wing, crossing from the far edge, or dropping in from above), settle loosely round the plane against the sky for about 8 s, swap places and cross the nose, then break away out of frame. Spots are placed relative to the chase camera, so turns keep them in shot. Birds are 1.5x the far flocks (about 1.3 m). Knobs: `--escort-gap=S`, `--escort=0`, `--escort-size=X`.
- **Big leaps** (`wake_fish.gd`, moment `big`): about a fifth of hero leaps; 2.6-4.6 m fish rising 4.6-8 m, about 2.5 s in the air, heavier splash and a second burst as the hole closes. Knob: `--leap-big=S[,X]`.
- **Swimmer** (`scripts/endless/swim_fish.gd`, `zs_swim_one`/`zs_swim_hit` in `shaders/endless_sea.gdshader`): about once a minute flying low over a lake, a 4.2-5.4 m fish (sometimes a pair) rises beside the plane, paces it 0.9 m down as a soft dark shape for 5-9 s, breaches about half the time, then dives. Its own water: a low hump, smoothed chop, darkened sea over its body. Knobs: `--swim-gap=S`, `--swimmer=0`, `--swim-size=X`.

## Where to fly

- Escort: `.\run-endless-flight.cmd --escort-gap=15`
- Swimmer and big leaps: `.\run-endless-flight.cmd --at=2334,-1534 --heading=90 --alt=3 --swim-gap=8 --leap-gap=6`

## Open

- The swimmer's fin was a grown stalk 0.9 m over a body painted by the sea, and read detached when the camera panned. Now the fish rides 0.5 m down and its own dorsal (barely lifted) cuts the surface; judged in free-camera stills (side, ahead, behind, high, low, 8-25 m, noon and 18:00) and the chase film; not yet played. Its back now breaks the surface as a dark wet shape in troughs (a sheen added). The gap driver wasn't rerun and the droplets' frame cost wasn't measured. No foam collar was added: the existing spray and bow wave mark the waterline.
- Off Boost at evening (24 m from the eye) the fin is a small dark mark.
- With a hill ahead, some escort birds end up against land instead of sky.
- The escort's timing is seeded by the land, so the same flight repeats the same sequence.
- No sound for either; nothing was flown by hand. Proof is autopilot drives and rendered films (paths in the trail).
