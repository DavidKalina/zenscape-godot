# Lighting edits while paused

Pausing previously returned from the celestial update before publishing current
settings. Cloud-cover edits updated the cloud geometry but left sunlight,
reflections and celestial visibility stale; aurora strength edits did not reach
the sky shader until motion resumed.

The paused branch now refreshes the lighting rig from its current parameters.
It does not advance the hour, shared motion clock, rainbow formation or weather
transition. This lets a paused landscape remain useful for lighting exploration
without changing the frozen animation pose.

`tests/test_paused_lighting.gd` reproduced three failures before the fix: stale
direct light, stale celestial cloud clearance and stale aurora strength. It
drives the actual cloud and aurora sliders, checks restoration after clearing
clouds, and verifies clocks and an animated storm transition remain paused.
