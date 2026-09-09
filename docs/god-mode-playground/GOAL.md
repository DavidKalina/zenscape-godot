# God Mode playground

## Experience

A beautiful miniature world the player can reach into and cause trouble in,
with Bigfoot as a quirky, expressive resident. Presets, lighting, and watching
the world are central; building is optional. The cursor should feel present
and tactile. Cartoon resilience lets Bigfoot recover, react, and surprise us.

## First playable milestone

Build on the existing wind and Bigfoot playground systems to deliver one
polished clearing with a bend-and-release tree interaction.

- Start in a beautiful composed preset with Bigfoot occupied autonomously.
- Make an interactable tree discoverable through subtle cursor feedback.
- Press and drag to bend it with clear tension, direction, and bounded motion.
- Release to spring back, with physical consequences for nearby Bigfoot.
- Give Bigfoot readable anticipation, impact, and recovery responses, with
  several reactions that make repeated experiments entertaining.
- Preserve usable camera controls, existing gust/carry interactions where
  compatible, pause, reset, and safe cancellation of a drag.
- Provide a simple launcher and document the controls.

## Completion evidence

Validate input handling, tree spring behavior, impact, reaction/recovery,
and reset/pause using focused automated checks. Run appropriate regressions.
Launch and visually inspect the scene; capture a short demonstration of the
complete interaction. Report any remaining limits and distinguish automated
verification from hands-on feel assessment.

## Later possibilities

Rain, lightning, thrown rocks, more environmental manipulation, campers and
wildlife, distinct terrain/palette combinations, and eventually mountain
destruction. These inform the direction but are outside this milestone.

## Workspace

- Branch: `codex/god-mode-playground`
- Worktree: `.claude/worktrees/god-mode-playground`
- Starting point: `main` at `07f2335`
- Existing foundations: `docs/wind-playground/README.md` and
  `docs/bigfoot-playground/README.md`.
- The separate campsite experiment remains available for later integration.
