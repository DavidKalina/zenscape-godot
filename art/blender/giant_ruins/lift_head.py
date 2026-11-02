"""The head the stomper lifts (head-lift prototype): mourner_55 with a capped
neck and a straight way bored from the stump out through one great socket.

    python3 tools/blender.py run art/blender/giant_ruins/lift_head.py -- [--voxel 0.7]

Writes assets/models/giants/lift_head.glb (origin at the head's middle) and
assets/models/giants/lift_head.json: the bore's ends, the turn from the model to
the carried frame and the boxes the flight meets, read off the same field. The
carried frame: -z along the flight's level way through the bore, y up, the bore
climbing CLIMB degrees. scripts/endless/head_lift.gd reads it.
"""
import argparse
import json
import math
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import giant_head_build as ruin  # noqa: E402
import small_heads  # noqa: E402

MIDDLE = np.array((0.0, 3.0, 28.0))
# WorldScale.opening(TOY_WAY) at the game's plane, 2 x the toy width.
TOY_WAY = 7.0
WAY = TOY_WAY * 2.0
# Stump to socket, in the build's axes (face down -Y, z up).
ENTRY = np.array((-3.0, 6.0, 0.0))
SOCKET = np.array((-12.0, -19.0, 28.0))
CLIMB = 5.0
BOX = 3.0


def godot(p):
    return np.array((p[0], p[2], -p[1]))


def segment(f, a, b, r):
    """The signed distance to a capsule."""
    ax, ay, az = f.X - a[0], f.Y - a[1], f.Z - a[2]
    e = b - a
    t = np.clip((ax * e[0] + ay * e[1] + az * e[2]) / float(e @ e), 0, 1)
    return np.sqrt((ax - e[0] * t) ** 2 + (ay - e[1] * t) ** 2 + (az - e[2] * t) ** 2) - r


def turn_to_carried():
    """The model's axes (Godot's) to the carried frame: the bore on the flight's
    way, the back of the skull toward the body on the plane's right."""
    b = godot(SOCKET - ENTRY)
    b /= np.linalg.norm(b)
    back = np.array((0.0, 0.0, -1.0))                                           # the skull's back, Godot's axes
    t = back - b * (back @ b)
    t /= np.linalg.norm(t)
    w = np.cross(b, t)
    c = math.radians(CLIMB)
    fl = np.array((0.0, math.sin(c), -math.cos(c)))
    side = np.array((1.0, 0.0, 0.0))
    g = side - fl * (side @ fl)
    g /= np.linalg.norm(g)
    h = np.cross(fl, g)
    return np.stack((fl, g, h), 1) @ np.stack((b, t, w), 0)                      # model -> carried


def boxes(f, d, turn):
    """Upright runs of the solid on a BOX m grid, carried frame, joined across x."""
    half = 42
    xs = np.arange(-half, half, BOX) + BOX / 2
    ys = np.arange(-half, half, BOX / 2) + BOX / 4
    zs = np.arange(-half, half, BOX) + BOX / 2
    out = {}
    for iz, z in enumerate(zs):
        for ix, x in enumerate(xs):
            pts = np.stack((np.full_like(ys, x), ys, np.full_like(ys, z)), 1)
            model = pts @ turn                                                  # the inverse of a turn is its transpose
            built = np.stack((model[:, 0], -model[:, 2], model[:, 1]), 1) + MIDDLE
            at = np.round((built - f.lo) / f.h).astype(int)
            good = np.all((at >= 0) & (at < np.array(d.shape)), 1)
            solid = np.zeros(len(ys), bool)
            solid[good] = d[tuple(at[good].T)] < 0
            edges = np.flatnonzero(np.diff(np.concatenate(([0], solid.astype(int), [0]))))
            for a, b in zip(edges[::2], edges[1::2]):
                key = (iz, int(a), int(b))
                out.setdefault(key, []).append(ix)
    rows = []
    for (iz, a, b), cols in out.items():
        cols.sort()
        start = prev = cols[0]
        for c in cols[1:] + [10 ** 6]:
            if c != prev + 1:
                rows.append([float(xs[start] - BOX / 2), float(ys[a] - BOX / 4), float(zs[iz] - BOX / 2),
                             float(xs[prev] + BOX / 2), float(ys[b - 1] + BOX / 4), float(zs[iz] + BOX / 2)])
                start = c
            prev = c
    return rows


def main():
    import bpy
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--voxel", type=float, default=0.7)
    ap.add_argument("--ratio", type=float, default=0.35)
    args = ap.parse_args(argv)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    f, full, _ = small_heads.carved("mourner_55", args.voxel)
    b = (SOCKET - ENTRY) / np.linalg.norm(SOCKET - ENTRY)
    way = segment(f, ENTRY - b * 30.0, SOCKET + b * 30.0, WAY / 2)
    d = ruin.smax(ruin.smax(full, -way, 0.6), 0.8 - f.Z, 0.5)
    ob = ruin.to_object("lift_head", *ruin.surface_nets(d, f.lo, f.h))
    n = len(ob.data.vertices)
    co = np.empty(n * 3)
    ob.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3) - MIDDLE
    ob.data.vertices.foreach_set("co", co.ravel())
    ob.data.update()
    deci = ob.modifiers.new("less", "DECIMATE")
    deci.ratio = args.ratio
    bpy.ops.object.modifier_apply(modifier="less")
    ob.data.shade_smooth()
    game = ruin.ROOT / "assets/models/giants"
    ruin.export("lift_head", game / "lift_head.glb")
    turn = turn_to_carried()
    rows = boxes(f, d, turn)
    data = {"way": WAY, "toy_way": TOY_WAY, "climb": CLIMB,
            "entry": godot(ENTRY - MIDDLE).tolist(), "socket": godot(SOCKET - MIDDLE).tolist(),
            "turn": turn.T.ravel().tolist(), "boxes": rows}                     # the turn's columns, x then y then z
    (game / "lift_head.json").write_text(json.dumps(data))
    print(f"lift_head: {len(ob.data.polygons)} tris, {len(rows)} boxes")
    print("carried entry", (turn @ godot(ENTRY - MIDDLE)).round(1), "socket", (turn @ godot(SOCKET - MIDDLE)).round(1))


if __name__ == "__main__":
    main()
