# Bigfoot temper

Repeated stumbling, wind tumbles and dunking each add 0.45 heat. Heat fades
at 0.025 per second; reaching 1 starts a 24-second rage. Further provocation
extends it, capped at 30 seconds. The playground's **Rile him up** button
starts the same state directly. Pause freezes the timer and reset clears it.

Rage replaces the actual eye meshes' materials with emissive red and emits
steam from both sides of the animated head. Sixteen reusable mesh puffs bound
allocation cost. Cooling restores the original eye materials and normal tempo.

Actions run at 1.4 times normal tempo, with the same action clock controlling
the animation, hand targets and release. Approaches use 1.65 instead of 0.85
m/s; log carry uses 1.15 instead of 0.65 m/s, retaining navigation checks.
Autonomous rage actions bypass the ordinary attention delay but retain target
eligibility and interruption checks. Failed requests are limited to one search
every 1.2 seconds. Throw velocity is multiplied by 2.8; an explicit bounded
release-strength argument raises the prop speed cap only for these throws.
Player throws retain their existing limits.

Validation: `test_bigfoot_rage.gd` checks buildup, red eyes, steam, pause,
cooldown, reset and both strong throws. The existing mischief and log animation
regressions also pass. The full suite was not rerun for this pass; its previous
baseline is documented in `../log-animation`. Known renderer cleanup warnings
remain at capture shutdown. The preview is `enraged.mp4`.
