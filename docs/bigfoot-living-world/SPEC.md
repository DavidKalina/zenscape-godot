# Bigfoot living-world first iteration

Build from cave branch a15b607 in an isolated worktree. Preserve original study
behavior unless the living controller is enabled. Add a launchable living-world
study using the existing two-story cave chunk, with controls to inspect decisions
and disturb supplies. No campers, bridges, climbing or arbitrary body scaling.

1. Home comfort: gathering returns a visible branch; tending consumes a stored
   material and improves persistent visible bedding through three stages.
2. Food: existing real fish catches become finite stored meals; eating consumes
   one item and reduces hunger. Prefer fruit when provided; new fruit flora is
   outside this initial slice. Never duplicate or lose interrupted fish catches.
3. Curiosity: perceive nearby visible interests, approach/hesitate/inspect;
   repeated successful inspections build familiarity and reduce novelty.
4. Rituals: remember a successfully visited quiet surface resting place and
   return for a short seated ritual. Revalidate terrain before use.
5. Home awareness: compare last observed supplies/bed with reality on visiting;
   unseen edits do not immediately become knowledge. Show a reaction and perform
   a home check. Respect player edits rather than undoing them silently.
6. Play: a comfortable, fed Bigfoot arranges existing loose stones near his bed;
   progression is visible and persistent, with a bounded finished arrangement.

Use needs-based scores with reasons, bounded memory, success-only effects,
commitment to activities, failure backoff, safe navigation, explicit cancellation,
pause semantics and JSON save validation/legacy migration. Reuse existing authored
movement clips; add small procedural hand/gaze gestures for new performances.
Verify actual native-rendered cave movement and food ownership, unit-test scoring
and state validation, run regression suite once, and visually inspect renders.
