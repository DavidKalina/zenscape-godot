# Tree personality worktree

Branch: `codex/tree-personality`, based on committed `main` at `cc27123`.
The main checkout's in-progress AI/navigation changes were not copied.

Run `./run-god-mode-playground.command` for an immediately grabbable foreground tree,
or `./run-diorama.command` to use the same motion on scenery in the main game.
The project uses a separate Godot user-data directory, `ZenScape Tree Personality`.

Pull and release a tree. The Tree personality panel switches Original / Supple /
Cartoony globally. Replay last pull repeats the most recent tree gesture with a
consistent pull ramp and hold. F8 hides the controls. Sliders apply to Supple and
Cartoony; Original preserves the previous dynamics.

Cartoony is the initial direction: faster trunk return, delayed crown and tip,
strong first overshoot, then a shorter recovery. Supple reduces crown deformation
and damps the trunk more. Crown/tip offsets affect both rendering and the CPU
centerline used for picking, hands, and swept impacts. Simulation substeps keep
motion consistent across update rates. Background wind is unchanged.

Tree direction accepted during the first playtest. Continue tuning at gameplay
distance; the Bigfoot pass below is the next comparison awaiting feedback.

Validation: existing spring-tree, god-mode interaction, and main-world play tests
pass; added frame-rate / previous-crown sweep / settling / cancellation coverage
passes. GPU captures via `tools/film_tree_personality.gd` inspected for all three
profiles. The broader interaction tests emit existing-style object/resource
cleanup warnings on exit; assertions pass.

## Bigfoot walk and idle

Tree direction accepted by David: "that's a lot better ... I like that."

Run `./run-bigfoot-personality.command` to open the existing playground with
Bigfoot framed and the full idle playing. The right panel now also has Original
Bigfoot / Buoyant & curious, Watch idle, Take a stroll, and Close-up controls.
The default animation replacement applies to CreatureActor instances throughout
the worktree, including the main Diorama game. Other action clips stay intact.

Walk keeps the original 3.6-second loop and stride distance so navigation speed
still matches stance contact. Contact compresses into a lower pelvis, the passing
pose rises, and the chest, arms and hands follow with different timing. The
15.6-second idle contains three 5.2-second breaths, asymmetric weight changes,
two quick looks with overshoot and holds, delayed chest turns, and a hand release.
Breath mist still follows each individual breath, not the longer idle loop.

Editable source: `art/blender/bigfoot/zenscape-bigfoot-personality.blend`.
Authoring script: `tools/animate_bigfoot_personality.py`. New clips are retargeted
onto the actor's existing skeleton; current visuals, attachments and other actions
are preserved. Original/new switches keep walk phase and speed, and do not
interrupt carrying or action clips. Imported animation optimization is disabled
to retain the planted-foot solution (default key reduction introduced drift).

Blender validation measures loop closure, stance contact and mesh floor clearance.
Runtime checks cover actor interactions, walking, breathing, asset variants, A/B
switches, and the game controls. `tools/film_bigfoot_personality.gd` renders an
original/new comparison of translating walks followed by the full idle.

Bigfoot verdict pending: tune after watching at gameplay speed and camera distance.

### Walking arms, second pass

Feedback: idle is the strongest; walk is improved, but arms still feel stiff.
Revised only the walking upper arms, forearms, hands and fingers. Shoulder swing
is slightly smaller, with outward arcs; elbow flexion now has a clear catch and
release; wrists and fingers follow at different times. Legs, pelvis, torso, head,
stride timing and the approved Idle are unchanged (verified against saved imported
animations, key by key). Blender contact/loop checks and runtime walking/actor
profile checks pass. `walking-arms-comparison.mp4` shows the first personality
walk on the left and the revised arms on the right. Throwing remains a later pass.

### Held performance

Feedback: the held flail communicates an attempt at struggling, but lacks
personality. The new 7.2-second Held loop has a tuck, two staggered kicks, a quiet
hold, an uneven protest, a single reaching hand, and a return to dangling.
Pelvis/spine motion is countertranslated below a fixed head pose, preserving the
cursor grip while freeing the body to react. Wrist/finger motion follows the
larger gestures. `held-comparison.mp4` shows previous/new side by side.

The original flail is retained as Airborne for swimming and physical tumbling;
those contexts should not inherit a performance about being held by the scalp.
Walk and Idle were compared key by key against their approved imports: unchanged.
New held checks cover pauses, silhouette contrast, asymmetric reaching, grip and
landing; existing actor, profile and wind interaction checks pass.

### Held direction revision: air-swimming

The staged held sequence was not the desired personality. David requested goofy,
continuous air-swimming: desperately paddling at nothing to get down. Replaced
the tuck/hold/reach sequence with large cycling foot arcs, faster feet than arms,
scooping arm strokes, floppy toes and wrists, and different arm stroke counts
with tempo drift. The body trails below the fixed scalp. No prolonged holds.
`air-swimming-comparison.mp4` compares the rejected staged pass to this revision.
Continuous-motion, alternating-foot, head-anchor and release checks pass; imported
Walk and Idle are unchanged key for key. David approved this direction as more legible.


### Pickup, carry, throw, and tree pull

Authored StoneHeave/StoneThrow, LogLift/LogCarry/LogToss/LogSlam, and TreeShake
on the same rig. Pickups gather into a deeper crouch, throws hold their windup
before accelerating into release, and torsos/heads follow through and recover.
The shoulder transfer now clears the head at a reachable height, with a small
receiving compression. Tree pulling starts with a tentative tug, yields slightly,
then braces into the full pull and recoils on release.

Prop paths use the same timing beats as the body clips. Release timestamps and
physical launch velocities stay intact. Original Bigfoot restores both old clips
and old prop paths. The F8 panel adds a log/stone/tree selector and Try it button.

Validation: authoring floor/loop checks; personality retarget/phase tests; held
regression; log animation, mischief, and main-world integration all pass. Imported
Walk and Idle remain identical key for key. Actual log, stone, and tree contact
poses were captured and inspected with tools/film_bigfoot_actions.gd; its screenshots
are written to /private/tmp/bigfoot-actions-{kind}. Existing scene teardown resource
warnings remain. Artistic verdict for this interaction pass is pending playtesting.


### Tree pull revision: steady brace

David accepted the interaction pass except for the tree motion reading as pelvic
thrusting. TreeShake now settles the hips back once and holds them through release;
effort comes from upper-body lean/twist, followed by a sideways shoulder recoil.
Removed the preliminary yield in the trunk path. Also removed the source rig's
existing TreeShake before authoring: Blender had suffixed the new action and the
export filter kept the old one. Binary animation payload comparison confirms this
revision changes TreeShake only; all other animation payloads are identical.


### Remaining reactions and rest

Added an authored Tremor startle with diminishing, asymmetric balance corrections;
strength still controls recovery duration and existing pause/interruption rules.
SitDown and StandUp ease into and out of the seated pose; Sit has measured head
looks and soft breathing; Sleep adds a small droop and recovery to its breath loop.
Source actions with these names are removed before export to avoid stale clips.
Tremor and routine actor checks pass. F8 comparison controls start hidden in the
main game. The temporary worktree application/user-data name is not shipped.
