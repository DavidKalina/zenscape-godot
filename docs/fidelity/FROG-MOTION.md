# Pond frog motion

The two imported frogs now breathe while sitting, occasionally hop into the
pond, paddle briefly and hop back to their own shoreline anchors. **F** or
**Startle pond frogs** triggers staggered hops. A water entry emits a soft,
expanding contact ring from the existing twelve-slot ring mesh.

The original scene supplies the frog scale, phase and bank position/normal.
Resting height is sampled from the native terrain, correcting buried frogs
where its triangles differ from the original continuous height field.
Native terrain and lake triangles validate landing points and each paddle
position; they cannot be selected over dry ground. The hop uses a parabolic
arc and stretches the body, while swimming adds a slower kick. Habitat
visibility from `growth.gd` freezes the loop in cold/ice or an unfinished pond.
Pause freezes breathing, motion and ripple age together.

This intentionally uses a compact native loop rather than reproducing the
original bank-occupancy and alternate-exit planner. Frogs return to their own
bank after a local paddle. They do not have obstacle collision or plop audio.

`tests/test_frog_motion.gd` checks both landing points, water-only paddling,
hop/swim/return transitions, exact bank return, one ring per entry, pause and
absent-habitat freezing. `tests/test_pond_habitat.gd` checks cold, ice and growth
integration. Close capture frames were inspected; the initially thick white
ring was replaced by a thinner, softer shader profile.

`frog-motion-comparison.mp4`: active startle on the left, resting frogs on the
right, six seconds at 30 fps. Capture using `tools/film_frogs.gd` and
`--clean --cam=4.8,0.8,1.9,6.8,0.4,0.1 --film-frames=180`, with a unique
`--film-dir`. Add `--control` for the resting reel.
