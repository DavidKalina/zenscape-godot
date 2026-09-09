# Milestone acceptance evidence

| Goal requirement | Evidence |
| --- | --- |
| Isolated worktree and branch | `codex/god-mode-playground`, based on `07f2335`; all implementation paths are in this worktree. |
| Beautiful preset clearing | Native ridge, falls and pool, authored woodland planting, and three lighting choices; visually inspected rendered frames. |
| Autonomous Bigfoot | Existing creature brain/navigation reused; integration test observes WALKING after recovery. |
| Discoverable tactile cursor | Bent-shape picking, terrain occlusion, hand cursor, root highlight, drag hint and tension meter; camera-based input test and rendered drag frame. |
| Bounded bend and release | Spring unit test checks root anchoring, capped tension, upright overshoot and settling. CPU and shader use the same constant-curvature centerline. |
| Physical consequences | Swept branch contacts issue one velocity-derived impulse per release; integration test observes WIND, displacement over 0.6 m, and RECOVERING. Recording shows about 2.15 m displacement. |
| Expressive responses | One-shot notice with continuous gaze, gentle-pull response, repeated-teasing brace, impact flail and post-recovery gaze; animation-age and repeated-brace assertions plus rendered sequence. |
| Camera and compatible interactions | New integration test directly checks right-drag orbit, scroll zoom, tool switching, gust and carrying; existing wind playground test also passes. |
| Pause, reset and cancellation | Tests cover spring freeze, canceled held gesture, paused carrying, reset, Escape, focus loss and release over UI. |
| Launcher and controls | Executable `run-god-mode-playground.command`; shell syntax check; controls documented in README. |
| Appropriate regressions | Full 144-test GPU suite and focused rechecks: 135 pass, nine failures reproduced on starting commit; exact results in `validation/`. |
| Review | Independent Standards and Spec reviews, resolved findings and recheck recorded in `REVIEW.md`. |
| Visual inspection and capture | Bent, impact and recovered frames inspected; local `tree-mischief.mp4`, reproducible using the committed capture script. |

The result is a first playground milestone. It does not claim articulated limb
physics, destruction of arbitrary scenery, persistent learned behavior, or a
completed human playtest. Those limits do not replace the delivered bend,
impact, reactions and autonomous exploration described above.
