# Cave integration status

The user approved the Blender cave design, then requested placement in Fidelity
and entry/exit routines. Their latest direction is a fully black doorway:
Bigfoot walks behind it, disappears during rest, and reappears before walking out.

That sequence is implemented and visually captured in native Metal rendering.
Cave lifecycle and main-game save/reload tests pass. The prepared world is
`Fidelity cave.json`; `run-bigfoot-cave.command` opens the study directly.
See README.md and verification.json for scope and regression limitations.

The work remains isolated on `codex/bigfoot-cave`. The unrelated project.godot
change copied during worktree setup is excluded from the cave commit. Interior
inspection and carrying possessions into the cave remain future work.
