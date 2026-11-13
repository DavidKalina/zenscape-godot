"""The temple kit's standing column (base lane): plinth, torus, eleven
fluted drums with open joints and bitten edges, echinus and abacus.

    python tools/blender.py run art/blender/temple_kit/column_build.py [-- --seed=N]
"""

import sys

import temple_lib as T

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
seed = next((int(a.split("=")[1]) for a in args if a.startswith("--seed=")), 3)

p = T.Piece("column", seed=seed)
r = p.rng

# The plinth: a square slab, its corners worn.
p.block((0, 0, T.PLINTH_H / 2), (T.PLINTH, T.PLINTH, T.PLINTH_H), bevel=0.09, chips=3,
        chip_depth=(0.2, 0.5))
# The torus: a fat round moulding under the shaft.
R0 = T.COLUMN_D / 2
p.ring((0, 0, T.PLINTH_H), [(R0 + 0.15, 0.0), (R0 + 0.38, 0.12), (R0 + 0.45, 0.3), (R0 + 0.38, 0.48),
                            (R0 + 0.05, T.TORUS_H)], segments=56, chips=2, bite=(0.12, 0.3))

# The shaft: drums tapering from COLUMN_D to COLUMN_D_TOP, each set a
# little off true, a few bitten at their edges.
z = T.BASE_H
for i in range(T.DRUMS):
    f0 = i / T.DRUMS
    f1 = (i + 1) / T.DRUMS
    r0 = T.COLUMN_D / 2 + (T.COLUMN_D_TOP - T.COLUMN_D) / 2 * f0
    r1 = T.COLUMN_D / 2 + (T.COLUMN_D_TOP - T.COLUMN_D) / 2 * f1
    chips = r.choice((1, 2, 2, 3))
    p.drum((0, 0, z + T.JOINT / 2), T.DRUM_H - T.JOINT, r0, r1, chips=chips, yaw=0.0, shift=0.06, samples=6, flute_depth=0.17, bite=(0.15, 0.5))
    z += T.DRUM_H

# The echinus: the cushion flaring from the neck out under the abacus.
RT = T.COLUMN_D_TOP / 2
top = T.BASE_H + T.SHAFT_H
p.ring((0, 0, top), [(RT - 0.05, 0.0), (RT + 0.05, 0.12), (RT + 0.45, 0.4), (RT + 0.85, 0.75),
                     (RT + 0.9, T.ECHINUS_H)], segments=56, chips=2, bite=(0.12, 0.35))
# The abacus: the square slab the lintel rests on.
p.block((0, 0, top + T.ECHINUS_H + T.ABACUS_H / 2), (T.ABACUS, T.ABACUS, T.ABACUS_H),
        bevel=0.08, chips=3, chip_depth=(0.2, 0.55))

# The far LOD.
p.far_cylinder((0, 0, T.PLINTH_H), T.TORUS_H + T.SHAFT_H, R0 + 0.1, RT, segments=12)
p.far_cylinder((0, 0, top), T.ECHINUS_H, RT, RT + 0.9, segments=12)

# The flight's solids: the plinth and the abacus as their squares, the
# shaft as a box inside its round (the flight's solid is boxes).
h = T.PLINTH / 2
p.solid((-h, -h, 0.0), (h, h, T.BASE_H))
s = T.COLUMN_D / 2 * 0.9
p.solid((-s, -s, T.BASE_H), (s, s, top + T.ECHINUS_H))
a = T.ABACUS / 2
p.solid((-a, -a, top + T.ECHINUS_H), (a, a, T.COLUMN_H))

p.export()
