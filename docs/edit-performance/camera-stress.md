# Redwood rapid-camera investigation

User narrowed the remaining Windows hitch to rapid diorama rotation, with zoom
and pan also possible triggers. No runtime rendering fix is established yet.

Reproduction harness:

```sh
godot --path . --script tools/profile_interaction_stalls.gd -- --preset=redwood_grove --camera-stress --orbit-seconds=1 --out=/tmp/zs-fast-camera.json
```

The optional stress mode runs two passes each of rapid rotation, alternating
zoom, and alternating pan through the real input handlers in inspection mode.
Existing placement/slow-orbit behavior remains available without that option.

Exploratory native Metal run on Apple M5 Pro: fast rotation peak gaps were
16.487 and 21.019 ms, with no pipeline counter increases or object revision
changes during either pass. Pan had one 34.971 ms gap; no massive freeze was
reproduced. A headless trace test overlapped part of this exploratory run, so
these timings are not an isolated performance baseline. Windows behavior is
still unverified.

F9 captures now include camera target coordinates and orbit/pan gesture flags,
alongside existing yaw, pitch, distance, frame timings and pipeline counters.
`tests/test_performance_trace.gd` verifies the saved camera fields and passes.
Capture rapid rotation on the affected Windows machine to distinguish the
remaining hitch before choosing another fix.
