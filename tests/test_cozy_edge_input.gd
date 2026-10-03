extends "res://tests/test_cozy_worlds.gd"
## NEEDS REWRITE (2026-10-02): written for the old cozy opening, with a cozy
## resident, a populated world and carry-drag of the resident. The game now
## opens on a bare Genesis plain with Bigfoot hidden, so this test (it extends test_cozy_worlds) fails and
## times out on expectations that no longer hold. Rewrite it for the
## bare-plain opening; kept rather than deleted because it is the main
## scene's integration test.
## The continuous-world integration now includes full input dispatch, edge
## crossing, release, persistence and returning to the adjacent region.
