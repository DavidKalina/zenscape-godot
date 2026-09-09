# Rock face treatments

Run `./run-valley-rock.command`. Compare Clean, Lightly layered, and Weathered on the same valley, using the upper control bar or T. The detail slider ranges from 0 (baseline) to 1.5 (exaggerated). R frames a cliff; C restores the overview. The existing nine moods and atmosphere sliders remain available below.

The baseline is the accepted valley palette shader. The two treatments add world-space color variation before weather and snow: gently folded, broken strata; then intermittent vertical stains and restrained damp coloration near lower faces. Geometry, normals, river, planting, and silhouettes are unchanged. This is a surface-color experiment; it does not add actual ledges, fractures, or cave entrances.

Initial regular bands read too evenly, so layer spacing and visibility were varied and contrast reduced. The default is intentionally restrained; increasing strength helps inspect the effect. Keep clean rock as a valid family. Caves remain a separate possible landmark study.

Native Godot Forward+ captures compare three treatments in Alpine morning, Copper autumn, and First snow, at overview and cliff cameras. The harness checks unchanged terrain snapshots. Snow is applied after the rock treatment so exposed stone retains detail while snowy areas cover it. No performance claim is made; the inherited shutdown ObjectDB warnings remain outside this study.

[Comparison gallery](index.html). Generated images are local and excluded from Git; regenerate with `tools/prototype_capture_valley_rock.gd` in native Godot.

User verdict pending.
