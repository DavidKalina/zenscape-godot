# Review

Baseline: c2d2863. Spec: SPEC.md in this directory.

Standards: no hard violations. Clarified that walk_step selects its gait on
entry to WALKING. Follow-up review identified that applying a third IK iteration
unconditionally could strengthen all legacy partial-weight reaches. Fixed:
legacy callers keep two passes, explicitly oriented palms receive three.

Spec: no confirmed missing requirements. Review noted that translation-only
continuity tests would miss prop rotation and elbow errors; added angular and
elbow-side checks, continuous carry palm contact, and toss interruption/pause.

No ownership blockers found. Visual review remains separate from numeric
checks, and the pass remains open to subjective animation feedback.
