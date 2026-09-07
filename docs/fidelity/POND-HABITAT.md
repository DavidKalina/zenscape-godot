# Pond wildlife and environmental transitions

The imported frog subsystem contains two groups: `mesh-39` is its twelve-slot
contact-ring pool, and `mesh-40` contains two frogs. The previous growth
classification treated only the rings as water details; frogs were static
terrain details and remained visible when the pond was emptied or frozen.

Both groups now require completed terrain, water filling above 0.92, cold below
0.7 and ice below 0.6. These are the original frog habitat thresholds. Weather
publishes current cold and ice after its update, so warming air alone does not
bring frogs back while the pond is still frozen. Manual growth scrubbing updates
visibility even when motion is paused.

`tests/test_pond_habitat.gd` exercises the integrated scene through empty,
partially filled, refilled, cold, warming-but-frozen, thawed and unfinished-land
states with motion paused. It checks both imported groups. Native hopping, paddling and contact-ring animation are now implemented in
`frog_motion.gd`; see FROG-MOTION.md for the motion pass and its limits.
