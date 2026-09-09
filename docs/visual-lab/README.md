# ZenScape visual lab

This is a long-lived experimental worktree on `codex/deliberate-pond`. Keep main separate. Use it to compare world appearance, scale, terrain families, mountains, vegetation, and atmosphere until the direction is clear. Long-lived workspace does not mean every experiment becomes production code.

## Decisions so far

- The user likes the pond treatment and considers the layered canopy a cleaner image.
- Keep the original tree designs. New tree families add variety rather than replacing every existing asset.
- Build variety through distinct silhouettes, within-family variation, age/condition, and believable placement.
- World scale remains open. The user likes the existing diorama but finds mountains small relative to Bigfoot and trees.
- The user likes the mountain/cloud experiment and also likes the earlier mountains. Preserve both as a mixed repertoire; the new tall forms add variety rather than replacing the existing mountain styles.
- Keep compact worlds viable while allowing very tall peaks. Larger plots may support a more expansive world style later; world size and mountain height are separate choices.

## Studies

- Pond and canopy: `./run-deliberate-pond.command`. K switches trees; 1/2/3 switch materials. Captures: [pond](../fidelity/deliberate-pond/index.html), [canopy](../fidelity/deliberate-pond/canopy/index.html).
- Mountain proportions: `./run-mountain-scale.command`. Separate disposable scene; no gameplay or saved-world scale changes. Findings live beside its captures.

- Mountain variety and clouds: `./run-mountain-clouds.command`. Three silhouettes, independent height, and a drifting cloud band. [Study notes](mountain-clouds/README.md).

Preserve useful comparisons and short findings. Promote reviewed changes deliberately; retire superseded prototype code. Do not infer real-world meters from engine coordinates before choosing a scale model. Navigation, interaction reach, movement speed, camera behavior, water, shadows, and saved worlds need separate review before any scale change becomes production behavior.

- Nahanni-inspired valleys: `./run-nahanni-valley.command`. Open valley, canyon, and valley-to-gorge compositions with independent floor width and wall height. [Notes](nahanni-valley/README.md).

- Valley palettes: `./run-valley-palettes.command`. The same valley with nine existing moods and live hour, mist, and cloud-altitude controls. [Notes](valley-palettes/README.md).
