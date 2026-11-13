"""The temple kit's standing column (base lane): plinth, torus, eleven
fluted drums with open joints and bitten edges, echinus and abacus; and its
mid LOD (column_mid.glb).

    python tools/blender.py run art/blender/temple_kit/column_build.py [-- --seed=N]
"""

import sys

import temple_lib as T

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
seed = next((int(a.split("=")[1]) for a in args if a.startswith("--seed=")), 3)
# Turned work's segments round, and points per flute: the trim's numbers
# (11,792 tris -> about 3,500; the trim commit has the table).
SEG = int(next((a.split("=")[1] for a in args if a.startswith("--seg=")), 40))
SAMPLES = int(next((a.split("=")[1] for a in args if a.startswith("--samples=")), 2))


def build(mid=False):
    """The column; `mid` its mid LOD: the same stones from the same draws,
    turned work at 20 segments and the shaft 20 plain facets that still
    take the flutes' light (shaft samples=1), its joints kept."""
    seg, samples = (20, 1) if mid else (SEG, SAMPLES)
    p = T.Piece("column", seed=seed)

    # The plinth: a square slab, its corners worn.
    p.block((0, 0, T.PLINTH_H / 2), (T.PLINTH, T.PLINTH, T.PLINTH_H), bevel=0.09, chips=3,
            chip_depth=(0.2, 0.5))
    # The torus: a fat round moulding under the shaft. Its foot sits on the
    # plinth (no cap there); its top cap is kept, the floor the shaft stands on.
    R0 = T.COLUMN_D / 2
    p.ring((0, 0, T.PLINTH_H), [(R0 + 0.15, 0.0), (R0 + 0.38, 0.12), (R0 + 0.45, 0.3), (R0 + 0.38, 0.48),
                                (R0 + 0.05, T.TORUS_H)], segments=seg, chips=2, bite=(0.12, 0.3), caps=(False, True))

    # The shaft: drums tapering from COLUMN_D to COLUMN_D_TOP, each set a
    # little off true, a few bitten at their edges; one mesh, the joints
    # shared V-grooves (temple_lib.Piece.shaft).
    p.shaft((0, 0, T.BASE_H), T.DRUMS, T.DRUM_H, T.COLUMN_D / 2, T.COLUMN_D_TOP / 2, samples=samples,
            flute_depth=0.17, bite=(0.15, 0.5), shift=0.06, yaw=0.0)

    # The echinus: the cushion flaring from the neck out under the abacus.
    # Its foot cap covers the shaft's top; its top is under the abacus.
    RT = T.COLUMN_D_TOP / 2
    top = T.BASE_H + T.SHAFT_H
    p.ring((0, 0, top), [(RT - 0.05, 0.0), (RT + 0.05, 0.12), (RT + 0.45, 0.4), (RT + 0.85, 0.75),
                         (RT + 0.9, T.ECHINUS_H)], segments=seg, chips=2, bite=(0.12, 0.35), caps=(True, False))
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

    p.export(mid_of="column" if mid else None)


build()
build(mid=True)
