"""The landing find's shrine (scripts/endless/find_marks.gd): a worn plinth
step, a short fluted column stub with a slab on it, and an old bowl on the
slab. The kit's stone, joints, wear and paint (temple_lib), at about a
tenth of a temple's scale and a few hundred triangles, since up to 16 stand
at once. Two pieces: `shrine` (the stone, drawn with the kit's shader) and
`shrine_gilt` (the bowl, drawn gilt by find_marks.gd).

    python tools/blender.py run art/blender/temple_kit/shrine_build.py [-- --seed=N]

Its origin is on the ground at the find's centre; the bowl's rim is at
about 4.9 m (find_marks.gd anchors the glint above it). The plinth runs
SINK m into the ground so a slope doesn't show its underside.
"""

import sys

import temple_lib as T

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
seed = next((int(a.split("=")[1]) for a in args if a.startswith("--seed=")), 5)

SINK = 1.6          # the plinth's depth below the ground
STEP = 4.6          # the lower step's side
STEP_H = 0.7        # its height over the ground
STEP2 = 3.3         # the upper step
STEP2_H = 0.55
R_FOOT = 0.78       # the stub's radius at its foot
R_NECK = 0.72
DRUM_H = 1.2
FLUTES = 12
SLAB = 2.1          # the slab on the stub, its side
SLAB_H = 0.42


def stone():
    p = T.Piece("shrine", seed=seed)
    # The lower step: three slabs, sunk deep (their feet never seen), one
    # settled lower than the others.
    w = STEP / 3
    for i, (drop, tilt) in enumerate(((0.0, 0.0), (0.04, 0.01), (0.16, -0.035))):
        p.block(((i - 1) * w, 0.02 * i, (STEP_H - SINK) / 2 - drop), (w - T.JOINT, STEP, STEP_H + SINK),
                tilt=(tilt, 0.0), bevel=0.07, chips=2, chip_depth=(0.2, 0.55), hide=("-z",), far=False)
    # The upper step: two slabs, turned a little off the lower.
    z = STEP_H
    for i in range(2):
        p.block((0.08, (i - 0.5) * STEP2 / 2 - 0.05, z + STEP2_H / 2), (STEP2, STEP2 / 2 - T.JOINT, STEP2_H),
                yaw=0.05, bevel=0.06, chips=2, chip_depth=(0.15, 0.4), hide=("-z",), far=False)
    z += STEP2_H
    # The torus under the shaft, coarse.
    p.ring((0, 0, z), [(R_FOOT + 0.1, 0.0), (R_FOOT + 0.2, 0.12), (R_FOOT + 0.06, 0.26)],
           segments=FLUTES, chips=1, bite=(0.05, 0.12), caps=(False, True))
    z += 0.26
    # Two fluted drums, the upper set off true and bitten.
    taper = (R_NECK - R_FOOT) / 2
    p.drum((0, 0, z), DRUM_H, R_FOOT, R_FOOT + taper, flutes=FLUTES, flute_depth=0.06, chamfer=0.04,
           chips=1, bite=(0.04, 0.12), samples=1, caps=(False, False), shift=0.02)
    z += DRUM_H
    p.drum((0, 0, z), DRUM_H, R_FOOT + taper, R_NECK, flutes=FLUTES, flute_depth=0.06, chamfer=0.04,
           chips=3, bite=(0.12, 0.3), samples=1, caps=(False, False), shift=0.06)
    z += DRUM_H
    # The slab the bowl stands on, a touch askew.
    p.block((0.06, 0.04, z + SLAB_H / 2 - 0.04), (SLAB, SLAB, SLAB_H), yaw=0.18, tilt=(0.045, -0.06), bevel=0.06,
            chips=3, chip_depth=(0.25, 0.55))
    # A piece of the slab, broken off long ago, half sunk by the steps.
    p.block((STEP / 2 + 0.55, -0.9, 0.05), (1.1, 0.8, 0.42), yaw=0.7, tilt=(0.25, -0.3), bevel=0.06,
            chips=2, chip_depth=(0.15, 0.3), far=False)
    print(f"SHRINE slab top {z + SLAB_H:.2f}")
    p.solid((-STEP / 2, -STEP / 2, -SINK), (STEP / 2, STEP / 2, STEP_H))
    p.solid((-R_FOOT, -R_FOOT, STEP_H), (R_FOOT, R_FOOT, z + SLAB_H))
    p.far_box((0, 0, (STEP_H - SINK) / 2), (STEP, STEP, STEP_H + SINK))
    p.far_cylinder((0, 0, STEP_H), z - STEP_H, R_FOOT, R_NECK, segments=6)
    p.export()
    return z + SLAB_H


def gilt(top):
    # A shallow bowl on a short foot, its inside dished; the gilding worn.
    p = T.Piece("shrine_gilt", seed=seed + 1)
    p.ring((0, 0, top - 0.06), [(0.32, 0.0), (0.24, 0.2), (0.6, 0.42), (0.92, 0.58),
                                (0.95, 0.66), (0.84, 0.66), (0.4, 0.5)],
           segments=12, chips=1, bite=(0.05, 0.1), caps=(True, True))
    p.far_cylinder((0, 0, top), 0.6, 0.35, 0.9, segments=6)
    p.export()


gilt(stone())
