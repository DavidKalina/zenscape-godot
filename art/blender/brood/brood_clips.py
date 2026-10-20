"""The stone guy's rig and clips (imported by brood_build.py).

The contract is docs/design/brood/body-contract.md: clip names, lengths,
loops and beats there are the ones here (CLIPS below), and the build
writes them to assets/models/brood_clips.json for the body script
(scripts/brood/stone_guy_body.gd), so the two never drift.

The rig is the build's JOINT table as bones; each stone piece rides one
bone rigidly (weight 1), so nothing bends: the squash and stretch are bone
scales (the whole body squashed about his feet, an arm stretched along its
length). The clips are key poses in named channels, eased between with
cubic Hermite curves (as art/blender/rune_knight/rune_knight_clips.py): a
key marked `hold` has flat tangents (an eased stop), the others pass
through with Catmull-Rom tangents. Each key carries the channels of the one
before, so a key lists only what changes.

Follow-through is computed, not keyed: the head lags the trunk's lean and
the body's bob, the fists trail the arms' swing.

Units: H = his height (1 in Blender; the game scales the glb to
BroodKnobs.tall()). Blender +z up, +y his front, +x his right. The origin is
his middle, his soles at z = -0.5.

Channels (degrees, and H for moves):
  bob surge sway     the body's move (up, forward, to his right)
  sq                 squash (+ squat and wide, - tall and thin), about his feet
  yaw                the body's turn (+ to his left)
  pitch roll twist   the trunk over the hips (+ forward, right side down, to his left)
  nod look tilt      the head (+ up, to his left, top to his right)
  arm.S out.S elb.S str.S
                     an arm (+ forward/up from hanging: 90 level, 180 straight
                     up; + away from him; the fist bent + forward; stretch,
                     1 at rest)
  leg.S knee.S       a leg (+ forward; the foot's stub bent back + at the knee)

    CLIPS (list of Clip); Rig(rig_ob, joint); bake(R, clip) -> Action
"""
import math

import bpy
from mathutils import Matrix, Vector

V = Vector
FPS = 30

SIDES = ("l", "r")
ARM_CH = {"arm": 8.0, "out": 4.0, "elb": 12.0, "str": 1.0}
LEG_CH = {"leg": 0.0, "knee": 0.0}
REST = {"bob": 0.0, "surge": 0.0, "sway": 0.0, "sq": 0.0, "yaw": 0.0,
        "pitch": 4.0, "roll": 0.0, "twist": 0.0, "nod": 0.0, "look": 0.0, "tilt": 0.0}
for _s in SIDES:
    for _k, _v in {**ARM_CH, **LEG_CH}.items():
        REST[f"{_k}.{_s}"] = _v

## Follow-through: the lag (s), the head's give to the lean (of the lean's
## change) and to the bob (deg per H), the fists' trail (of the swing's).
LAG = 0.07
HEAD_LEAN = 0.6
HEAD_BOB = 160.0
FIST_TRAIL = 0.5


def both(**kw):
    out = {}
    for k, v in kw.items():
        out[f"{k}.l"] = v
        out[f"{k}.r"] = v
    return out


def side(s, **kw):
    return {f"{k}.{s}": v for k, v in kw.items()}


class Clip:
    """keys: [(t, {channel: value}, hold?)]; beats {name: [t, ...]}.
    `driven`: how the game plays it: "time" (by the clock), "seek" (set to
    the mind's own time each frame), "stride" (advanced by the distance he
    moves: one loop per `stride` H)."""

    def __init__(self, name, length, keys, loop=True, beats=None, driven="time", stride=0.0, then=""):
        self.name, self.length, self.loop = name, length, loop
        self.beats = beats or {}
        self.driven, self.stride, self.then = driven, stride, then
        full, cur = [], dict(REST)
        for k in keys:
            cur = dict(cur)
            cur.update(k[1])
            full.append((k[0], cur, k[2] if len(k) > 2 else False))
        if loop:
            full.append((length, full[0][1], full[0][2]))
        self.keys = full

    def _tangent(self, i, ch):
        ks, n = self.keys, len(self.keys)
        if ks[i][2] or n < 3:
            return 0.0
        if self.loop:
            ip = i - 1 if i > 0 else n - 2
            inx = i + 1 if i < n - 1 else 1
            tp = ks[ip][0] - (self.length if ip >= i else 0.0)
            tn = ks[inx][0] + (self.length if inx <= i else 0.0)
        else:
            ip, inx = max(i - 1, 0), min(i + 1, n - 1)
            tp, tn = ks[ip][0], ks[inx][0]
        if tn - tp <= 1e-6:
            return 0.0
        return (ks[inx][1][ch] - ks[ip][1][ch]) / (tn - tp)

    def values(self, t):
        t = t % self.length if self.loop else min(max(t, 0.0), self.length)
        ks = self.keys
        if t <= ks[0][0] or len(ks) == 1:
            return dict(ks[0][1])
        if t >= ks[-1][0]:
            return dict(ks[-1][1])
        i = 0
        while ks[i + 1][0] < t:
            i += 1
        t0, a, _ = ks[i]
        t1, b, _ = ks[i + 1]
        hh = t1 - t0
        u = (t - t0) / hh
        h00, h10 = 2 * u ** 3 - 3 * u ** 2 + 1, u ** 3 - 2 * u ** 2 + u
        h01, h11 = -2 * u ** 3 + 3 * u ** 2, u ** 3 - u ** 2
        return {ch: h00 * a[ch] + h10 * hh * self._tangent(i, ch) + h01 * b[ch] + h11 * hh * self._tangent(i + 1, ch)
                for ch in a}

    def lagged(self, t, lag):
        return self.values(t - lag if self.loop else max(t - lag, 0.0))

    def table(self):
        return {"length": round(self.length, 4), "loop": self.loop, "driven": self.driven,
                "stride": self.stride, "then": self.then,
                "beats": {k: [round(x, 4) for x in ts] for k, ts in self.beats.items()}}


# ------------------------------------------------------------------ the rig's math
def rx(d): return Matrix.Rotation(math.radians(d), 4, "X")
def ry(d): return Matrix.Rotation(math.radians(d), 4, "Y")
def rz(d): return Matrix.Rotation(math.radians(d), 4, "Z")
def tr(p): return Matrix.Translation(V(p))


def sc(x, y, z):
    m = Matrix.Identity(4)
    m[0][0], m[1][1], m[2][2] = x, y, z
    return m


def about(j, m):
    return tr(j) @ m @ tr(-V(j))


class Rig:
    def __init__(self, rig, joint):
        self.ob = rig
        self.J = {k: V(v) for k, v in joint.items()}
        self.R = {b.name: b.matrix_local.copy() for b in rig.data.bones}
        self.parent = {b.name: (b.parent.name if b.parent else None) for b in rig.data.bones}
        self.order = [b.name for b in rig.data.bones]

    def moves(self, clip, t):
        v = clip.values(t)
        vl = clip.lagged(t, LAG)
        J = self.J
        D = {"root": Matrix.Identity(4)}
        q = v["sq"]
        wide = 1.0 + 0.5 * q
        D["body"] = tr((v["sway"], v["surge"], v["bob"])) @ about(J["body"], rz(v["yaw"]) @ sc(wide, wide, 1.0 - q))
        D["trunk"] = D["body"] @ about(J["trunk"], rz(v["twist"]) @ ry(v["roll"]) @ rx(-v["pitch"]))
        give = HEAD_LEAN * (v["pitch"] - vl["pitch"]) + HEAD_BOB * (vl["bob"] - v["bob"])
        D["head"] = D["trunk"] @ about(J["head"], rz(v["look"]) @ ry(v["tilt"]) @ rx(v["nod"] + give))
        for s in SIDES:
            sg = 1.0 if s == "r" else -1.0
            st = max(v[f"str.{s}"], 0.3)
            thin = 1.0 / math.sqrt(st)
            D[f"arm_{s}"] = D["trunk"] @ about(J[f"arm_{s}"], ry(-sg * v[f"out.{s}"]) @ rx(v[f"arm.{s}"]) @ sc(thin, thin, st))
            trail = FIST_TRAIL * (vl[f"arm.{s}"] - v[f"arm.{s}"])
            D[f"hand_{s}"] = D[f"arm_{s}"] @ about(J[f"hand_{s}"], rx(v[f"elb.{s}"] + trail))
            D[f"leg_{s}"] = D["body"] @ about(J[f"leg_{s}"], rx(v[f"leg.{s}"]))
            D[f"foot_{s}"] = D[f"leg_{s}"] @ about(J[f"foot_{s}"], rx(-v[f"knee.{s}"]))
        return D

    def basis(self, D):
        out = {}
        for n in self.order:
            p = self.parent[n]
            Dp = D[p] if p else Matrix.Identity(4)
            out[n] = self.R[n].inverted() @ Dp.inverted() @ D.get(n, Dp) @ self.R[n]
        return out

    def apply(self, clip, t):
        B = self.basis(self.moves(clip, t))
        for pb in self.ob.pose.bones:
            pb.matrix_basis = B[pb.name]


def bake(R, clip):
    rig = R.ob
    frames = max(1, round(clip.length * FPS))
    action = bpy.data.actions.new(clip.name)
    action.use_fake_user = True
    rig.animation_data.action = action
    last = {}
    for f in range(frames + 1):
        t = clip.length * f / frames
        R.apply(clip, t)
        for pb in rig.pose.bones:
            qq = pb.rotation_quaternion.copy()
            if pb.name in last and last[pb.name].dot(qq) < 0:
                qq.negate()
                pb.rotation_quaternion = qq
            last[pb.name] = qq
            pb.keyframe_insert("rotation_quaternion", frame=f)
            pb.keyframe_insert("location", frame=f)
            pb.keyframe_insert("scale", frame=f)
    for name, ts in clip.beats.items():
        for bt in ts:
            action.pose_markers.new(name).frame = round(bt * FPS)
    action.frame_range = (0, frames)
    rig.animation_data.nla_tracks.new().strips.new(clip.name, 0, action)
    rig.animation_data.action = None
    print(f"BROOD_CLIP {clip.name} frames={frames} seconds={clip.length:.3f} loop={clip.loop} "
          f"driven={clip.driven} beats={clip.table()['beats']}")
    return action


def reset(rig):
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)


# ================================================================== the clips
# The mind's times (scripts/brood/brood_knobs.gd), so seeked clips line up:
WAKE_RISE = 0.7
SINK_TIME = 1.1
MANTLE_TIME = 0.5
LEAP_TIME = 0.35

ARMS_UP = both(arm=172.0, out=6.0, elb=8.0)


def idle():
    """A breath (a slow rise and settle), his weight shifting, a glance."""
    return Clip("idle", 1.6, [
        (0.0, {}, True),
        (0.55, {"sq": -0.035, "roll": 2.5, "pitch": 2.0, "nod": 4.0, **both(arm=12.0, out=6.0)}),
        (0.8, {"look": 10.0}, True),
        (1.25, {"sq": 0.015, "roll": -1.0, "look": 4.0}),
    ], loop=True)


def look():
    """Standing, a look round: a snap to his left past and back onto it, a
    hold, a snap to his right with the trunk after it, a hold."""
    return Clip("look", 1.4, [
        (0.0, {"look": 0.0, "twist": 0.0}, True),
        (0.1, {"look": 52.0, "twist": 6.0, "nod": 6.0, "sq": 0.03}),
        (0.18, {"look": 44.0, "twist": 10.0, "sq": 0.0}, True),
        (0.6, {"look": 44.0, "twist": 10.0}, True),
        (0.7, {"look": -56.0, "twist": -4.0, "nod": 4.0, "sq": 0.03, "tilt": -6.0}),
        (0.8, {"look": -46.0, "twist": -12.0, "sq": 0.0}, True),
        (1.22, {"look": -46.0, "twist": -12.0, "tilt": 0.0}, True),
    ], loop=True, beats={"left": [0.1], "right": [0.7]})


def wake():
    """Over the isle's lip (seeked to the mind's wake time). He hangs on the
    face (up the face is his up, into it his front); his middle rises from
    1.05 H under the lip to 0.68 by `grip` (0.315 s), holds, then to 0.32 by
    `peek` (0.7 s). The fingers go first: a dip, a reach that stretches the
    arms up past the lip, the fists hooking over it at `grip`; a squash
    under the pull, then the heave that brings his head up over, elbows
    bent, the fists flat on top."""
    return Clip("wake", WAKE_RISE, [
        (0.0, {**both(arm=168.0, out=8.0, elb=0.0, str=1.0), "sq": 0.0, "nod": 20.0, "pitch": 0.0,
               **both(leg=-10.0, knee=30.0)}),
        (0.05, {"sq": 0.12, **both(str=0.92), "nod": 26.0}, True),
        (0.2, {"sq": -0.12, **side("l", arm=176.0, str=1.48, elb=20.0), **side("r", arm=172.0, str=1.42, elb=10.0),
               **both(leg=-20.0, knee=10.0)}),
        (0.315, {"sq": -0.05, **both(arm=172.0, str=1.3, elb=70.0), "nod": 30.0}, True),
        (0.42, {"sq": 0.1, **both(str=1.25, elb=75.0), **both(leg=10.0, knee=55.0)}, True),
        (0.6, {"sq": -0.06, **both(arm=150.0, str=1.0, elb=100.0, out=14.0), "pitch": 8.0, "nod": 14.0,
               **both(leg=-6.0, knee=20.0)}),
        (0.7, {"sq": 0.0, **both(arm=142.0, str=0.95, elb=104.0, out=16.0), "pitch": 6.0, "nod": 10.0}, True),
    ], loop=False, beats={"grip": [0.315], "peek": [0.7]}, driven="seek", then="peek")


def peek():
    """Hanging on the lip after the wake, chin over it, a look round (the
    wake's hold: as long as the mind holds)."""
    hang = {**both(arm=142.0, str=0.95, elb=104.0, out=16.0), "pitch": 6.0, "nod": 10.0}
    return Clip("peek", 1.2, [
        (0.0, {**hang}, True),
        (0.09, {"look": 40.0, "tilt": 8.0, "nod": 14.0, **side("l", elb=96.0)}),
        (0.16, {"look": 34.0}, True),
        (0.52, {"look": 34.0}, True),
        (0.62, {"look": -42.0, "tilt": -8.0, **side("l", elb=104.0), **side("r", elb=96.0)}),
        (0.7, {"look": -36.0}, True),
        (1.05, {"look": -36.0, "tilt": 0.0, "nod": 10.0, **side("r", elb=104.0)}, True),
    ], loop=True, beats={"left": [0.09], "right": [0.62]}, driven="time")


def rise():
    """Out of a burrow (seeked to the mind's rise time): his middle rises
    from 0.7 H under the floor to 0.1 under by `peek` (0.28), holds, then
    heaves up to stand by `stand` (0.7). Head first, looking up, the fists
    tucked; at the hold a quick look; then the arms come up out, slap down
    on the floor either side and push, a squash, a spring up and a landing
    squash on his feet."""
    return Clip("rise", WAKE_RISE, [
        (0.0, {"nod": 30.0, **both(arm=60.0, out=10.0, elb=80.0), **both(leg=0.0, knee=30.0), "sq": -0.06}),
        (0.28, {"nod": 12.0, "look": 0.0}, True),
        (0.33, {"look": 24.0}),
        (0.385, {"look": -10.0, "sq": 0.08, **both(arm=40.0, out=70.0, elb=30.0)}, True),
        (0.5, {"look": 0.0, "nod": 0.0, "sq": -0.16, **both(arm=10.0, out=60.0, elb=10.0, str=1.1),
               **both(leg=-6.0, knee=8.0)}),
        (0.62, {"sq": 0.14, **both(arm=18.0, out=24.0, elb=20.0, str=1.0), **both(leg=8.0, knee=24.0), "pitch": 10.0}),
        (0.7, {"sq": 0.0, **both(arm=8.0, out=4.0, elb=12.0), **both(leg=0.0, knee=0.0), "pitch": 4.0}, True),
    ], loop=False, beats={"peek": [0.28], "heave": [0.385], "stand": [0.7]}, driven="seek", then="look")


def sink():
    """Home into a burrow (seeked to the mind's sink time, SINK_TIME): steps
    onto the mouth (to 0.33), a look round, a crouch (`crouch` 0.5), the hop
    (`hop` 0.56, the mind lifts him), and down with his arms straight up,
    stretched thin, till he's gone (`gone` 1.1)."""
    return Clip("sink", SINK_TIME, [
        (0.0, {**side("l", leg=28.0, arm=-24.0), **side("r", leg=-24.0, arm=26.0), "pitch": 14.0}),
        (0.1, {**side("l", leg=0.0, arm=0.0, knee=0.0), **side("r", leg=0.0, arm=0.0, knee=40.0), "bob": 0.02}),
        (0.2, {**side("l", leg=-24.0, arm=24.0), **side("r", leg=28.0, arm=-24.0, knee=0.0), "bob": 0.0}),
        (0.33, {**both(leg=0.0, arm=8.0, knee=0.0), "pitch": 4.0, "sq": 0.04}, True),
        (0.38, {"look": 46.0, "sq": 0.0}),
        (0.43, {"look": -40.0}),
        (0.5, {"look": 0.0, "sq": 0.24, **both(arm=-30.0, out=14.0, elb=20.0, knee=40.0, leg=24.0), "pitch": 22.0, "nod": 14.0}, True),
        (0.56, {"sq": -0.2, **both(arm=150.0, out=10.0, elb=10.0, str=1.1, knee=0.0, leg=0.0), "pitch": 0.0, "nod": 20.0}),
        (0.68, {"sq": -0.12, **both(arm=176.0, out=4.0, elb=0.0, str=1.25), "nod": 26.0}),
        (1.1, {"sq": -0.16, **both(arm=178.0, str=1.3), **both(leg=-6.0, knee=10.0), "nod": 30.0}, True),
    ], loop=False, beats={"look": [0.38], "crouch": [0.5], "hop": [0.56], "gone": [1.1]}, driven="seek")


WALK = 0.44
WALK_STRIDE = 1.5


def walk():
    """The scurry: two quick steps a loop, leaning in, arms pumping against
    the legs, a dip and squash at each footfall (`plant`), up and thin
    between, the trunk rolling over the planted foot. Played by the
    distance he moves: a loop per WALK_STRIDE H."""
    h = WALK / 2
    def step(s, o):
        return {**side(s, leg=34.0, knee=0.0, arm=-34.0, elb=10.0), **side(o, leg=-30.0, knee=20.0, arm=40.0, elb=34.0)}
    return Clip("walk", WALK, [
        (0.0, {**step("l", "r"), "bob": -0.03, "sq": 0.07, "pitch": 18.0, "nod": 10.0, "roll": -4.0, "twist": -8.0}),
        (h * 0.5, {**side("l", leg=0.0, knee=0.0, arm=0.0), **side("r", leg=4.0, knee=50.0, arm=4.0),
                   "bob": 0.035, "sq": -0.05, "roll": 0.0, "twist": 0.0}),
        (h, {**step("r", "l"), "bob": -0.03, "sq": 0.07, "roll": 4.0, "twist": 8.0}),
        (h * 1.5, {**side("r", leg=0.0, knee=0.0, arm=0.0), **side("l", leg=4.0, knee=50.0, arm=4.0),
                   "bob": 0.035, "sq": -0.05, "roll": 0.0, "twist": 0.0}),
    ], loop=True, beats={"plant": [0.0, h]}, driven="stride", stride=WALK_STRIDE)


HAUL = 0.6
HAUL_STRIDE = 0.9


def haul():
    """One of a crew under a treasure: arms straight up, fists turned under
    the load (the load socket), short heavy steps with a big squash at each
    footfall, the head down straining, the trunk wobbling. By distance: a
    loop per HAUL_STRIDE H."""
    h = HAUL / 2
    up = {**side("l", arm=170.0, out=10.0, elb=24.0, str=1.02), **side("r", arm=170.0, out=10.0, elb=24.0, str=1.02)}
    return Clip("haul", HAUL, [
        (0.0, {**up, **side("l", leg=20.0, knee=0.0), **side("r", leg=-16.0, knee=14.0),
               "bob": -0.04, "sq": 0.11, "pitch": 4.0, "nod": -18.0, "roll": -5.0}, True),
        (h * 0.55, {**side("l", leg=0.0), **side("r", leg=4.0, knee=40.0), "bob": 0.0, "sq": -0.02, "roll": 0.0,
                    **side("l", str=1.06), **side("r", str=0.98)}),
        (h, {**side("r", leg=20.0, knee=0.0), **side("l", leg=-16.0, knee=14.0),
             "bob": -0.04, "sq": 0.11, "roll": 5.0, **both(str=1.02)}, True),
        (h * 1.55, {**side("r", leg=0.0), **side("l", leg=4.0, knee=40.0), "bob": 0.0, "sq": -0.02, "roll": 0.0,
                    **side("r", str=1.06), **side("l", str=0.98)}),
    ], loop=True, beats={"plant": [0.0, h]}, driven="stride", stride=HAUL_STRIDE)


CLIMB = 0.62
CLIMB_STRIDE = 0.55


def climb():
    """Up a face (up the face is his up, into it his front): hand over hand,
    each fist reaching up stretched and slapping on (`grab`), the other
    pulling down under him, the opposite knee drawn up to push; the body
    jerks up a little at each pull and rolls toward the reaching arm, the
    head tipped back to look up. By distance up the face: a loop per
    CLIMB_STRIDE H (backwards, climbing down)."""
    h = CLIMB / 2
    def reach(s, o):
        return {**side(s, arm=168.0, out=16.0, elb=26.0, str=1.18, leg=-8.0, knee=10.0),
                **side(o, arm=118.0, out=24.0, elb=78.0, str=0.95, leg=46.0, knee=80.0)}
    return Clip("climb", CLIMB, [
        (0.0, {**reach("l", "r"), "bob": -0.02, "sq": 0.06, "roll": -7.0, "pitch": 0.0, "nod": 26.0, "twist": -6.0}, True),
        (h * 0.55, {**side("l", arm=150.0, elb=50.0, str=1.0, leg=20.0, knee=40.0),
                    **side("r", arm=150.0, elb=40.0, str=1.06, leg=20.0, knee=40.0), "bob": 0.03, "sq": -0.05,
                    "roll": 0.0, "twist": 0.0}),
        (h, {**reach("r", "l"), "bob": -0.02, "sq": 0.06, "roll": 7.0, "twist": 6.0}, True),
        (h * 1.55, {**side("r", arm=150.0, elb=50.0, str=1.0, leg=20.0, knee=40.0),
                    **side("l", arm=150.0, elb=40.0, str=1.06, leg=20.0, knee=40.0), "bob": 0.03, "sq": -0.05,
                    "roll": 0.0, "twist": 0.0}),
    ], loop=True, beats={"grab": [0.0, h]}, driven="stride", stride=CLIMB_STRIDE)


def mantle():
    """Over a face's top (seeked to the mind's mantle, MANTLE_TIME; upright,
    facing over): fists on top, a squash under them (anticipation), the
    heave at `lip` (0.275: chest thrown over, arms pressing down past his
    hips, legs kicked back, stretched), a knee up onto the top, and a
    landing squash on his feet at `over` (0.5)."""
    return Clip("mantle", MANTLE_TIME, [
        (0.0, {**both(arm=160.0, out=14.0, elb=60.0, str=1.05), **both(leg=-10.0, knee=30.0), "pitch": 6.0, "nod": 20.0}),
        (0.09, {"sq": 0.16, **both(arm=150.0, elb=80.0, str=0.95), **both(leg=20.0, knee=70.0), "nod": 24.0}, True),
        (0.275, {"sq": -0.14, **both(arm=30.0, out=26.0, elb=-10.0, str=1.1), **both(leg=-46.0, knee=40.0),
                 "pitch": 56.0, "nod": 30.0}),
        (0.39, {"sq": 0.0, **both(arm=0.0, out=22.0, elb=10.0, str=1.0), **side("l", leg=74.0, knee=96.0),
                **side("r", leg=-30.0, knee=40.0), "pitch": 34.0, "nod": 22.0}),
        (0.5, {"sq": 0.14, **both(arm=14.0, out=10.0, elb=24.0), **both(leg=14.0, knee=30.0), "pitch": 14.0, "nod": 6.0}, True),
    ], loop=False, beats={"lip": [0.275], "over": [0.5]}, driven="seek", then="land")


def drop():
    """Letting himself off a ledge: a lean out, then stretched thin, arms
    flung up, legs straight down together, looking down at where he'll land
    (`hang`, held to the ground)."""
    return Clip("drop", 0.26, [
        (0.0, {"pitch": 16.0, **both(arm=40.0, out=30.0, elb=20.0), "sq": 0.06}),
        (0.12, {"sq": -0.14, **both(arm=150.0, out=30.0, elb=14.0, str=1.1), **both(leg=-4.0, knee=4.0),
                "pitch": -4.0, "nod": -22.0}),
        (0.26, {"sq": -0.1, **both(arm=160.0, out=24.0, elb=10.0, str=1.06), "nod": -26.0}, True),
    ], loop=False, beats={"hang": [0.26]}, driven="time")


def land():
    """Down on his feet (after a drop, a fall, a mantle): a hard squash at
    `contact` (knees bent, arms flung down and out, leaning in, the head
    nodding down after), held a breath, then up through a little stretch
    to rest (`up`). Weight: stone, so the squash is deep and the
    recovery quick."""
    return Clip("land", 0.26, [
        (0.0, {"sq": 0.3, **both(arm=-12.0, out=34.0, elb=10.0, str=1.0), **both(leg=26.0, knee=56.0),
               "pitch": 24.0, "nod": -14.0, "bob": -0.02}, True),
        (0.07, {"sq": 0.3, "nod": -20.0}, True),
        (0.17, {"sq": -0.05, **both(arm=14.0, out=8.0), **both(leg=0.0, knee=0.0), "pitch": 2.0, "nod": 4.0, "bob": 0.0}),
        (0.26, {"sq": 0.0, **both(arm=8.0, out=4.0, elb=12.0), "pitch": 4.0, "nod": 0.0}, True),
    ], loop=False, beats={"contact": [0.0], "up": [0.26]}, driven="time")


def fall():
    """Falling with no floor in sight: arms windmilling out of step, legs
    kicking, stretched, eyes up."""
    return Clip("fall", 0.5, [
        (0.0, {**side("l", arm=160.0, out=40.0, elb=20.0, leg=30.0, knee=20.0),
               **side("r", arm=60.0, out=50.0, elb=40.0, leg=-26.0, knee=50.0),
               "sq": -0.08, "nod": 16.0, "roll": 8.0, "pitch": -6.0}),
        (0.25, {**side("r", arm=160.0, out=40.0, elb=20.0, leg=30.0, knee=20.0),
                **side("l", arm=60.0, out=50.0, elb=40.0, leg=-26.0, knee=50.0), "roll": -8.0, "nod": 22.0}),
    ], loop=True, driven="time")


def shake():
    """Thrown off (a jump, the plane's bank): splayed wide at `flung`, the
    arms whipped back over his head, the head snapping after, then into the
    fall's flail."""
    return Clip("shake", 0.45, [
        (0.0, {"sq": 0.18, **both(arm=80.0, out=70.0, elb=30.0), **side("l", leg=40.0, knee=10.0),
               **side("r", leg=-30.0, knee=40.0), "pitch": 20.0, "nod": -10.0}),
        (0.08, {"sq": -0.18, **both(arm=196.0, out=46.0, elb=-10.0, str=1.15), **both(leg=-20.0, knee=10.0),
                "pitch": -20.0, "nod": 30.0, "tilt": 14.0}),
        (0.2, {"sq": -0.06, **side("l", arm=170.0, out=50.0, elb=10.0), **side("r", arm=120.0, out=60.0, elb=30.0),
               **side("l", leg=20.0), **side("r", leg=-10.0, knee=40.0), "pitch": -6.0, "nod": 18.0, "tilt": 4.0}),
        (0.45, {"sq": -0.08, **side("l", arm=160.0, out=40.0, elb=20.0, leg=30.0, knee=20.0, str=1.0),
                **side("r", arm=60.0, out=50.0, elb=40.0, leg=-26.0, knee=50.0, str=1.0),
                "nod": 16.0, "roll": 8.0, "pitch": -6.0, "tilt": 0.0}),
    ], loop=False, beats={"flung": [0.08]}, driven="time", then="fall")


def cling():
    """Hanging on the wanderer (his front to him): arms round him, squeezing
    (`squeeze`), legs kicking for a hold, the head pressed in to one side."""
    return Clip("cling", 0.5, [
        (0.0, {**both(arm=86.0, out=-26.0, elb=64.0, str=1.0), **side("l", leg=40.0, knee=60.0),
               **side("r", leg=-10.0, knee=20.0), "sq": 0.08, "nod": -10.0, "look": 30.0, "tilt": 10.0, "roll": -5.0}, True),
        (0.14, {"sq": -0.02, **both(elb=50.0, out=-18.0)}),
        (0.25, {**both(arm=92.0, out=-28.0, elb=68.0), **side("r", leg=40.0, knee=60.0),
                **side("l", leg=-10.0, knee=20.0), "sq": 0.08, "roll": 5.0, "look": 24.0}, True),
        (0.39, {"sq": -0.02, **both(elb=50.0, out=-18.0)}),
    ], loop=True, beats={"squeeze": [0.0, 0.25]}, driven="time")


def leap():
    """Onto the plane's bag (seeked to the mind's leap, LEAP_TIME): a quick
    crouch (anticipation, all in the first beat), `launch` stretched long
    with arms flung forward and legs trailing, a tuck over the arc, arms
    out to it, and a squash as he grabs on at `catch`."""
    return Clip("leap", LEAP_TIME, [
        (0.0, {"sq": 0.26, **both(arm=-40.0, out=14.0, elb=20.0), **both(leg=30.0, knee=60.0), "pitch": 30.0, "nod": 14.0}, True),
        (0.07, {"sq": -0.26, **both(arm=150.0, out=10.0, elb=6.0, str=1.2), **both(leg=-40.0, knee=10.0), "pitch": 20.0, "nod": 24.0}),
        (0.2, {"sq": 0.0, **both(arm=124.0, out=20.0, elb=20.0, str=1.1), **both(leg=60.0, knee=84.0), "pitch": 10.0}),
        (0.3, {"sq": 0.12, **both(arm=150.0, out=14.0, elb=50.0, str=1.0), **both(leg=30.0, knee=50.0), "nod": 16.0}, True),
        (0.35, {"sq": 0.06}, True),
    ], loop=False, beats={"launch": [0.07], "catch": [0.3]}, driven="seek", then="ride")


def ride():
    """On the bag (his front to it): fists up in the net, legs dangling and
    swinging in the wind out of step, the body swaying, peering down."""
    return Clip("ride", 0.8, [
        (0.0, {**side("l", arm=166.0, out=14.0, elb=34.0, leg=30.0, knee=30.0),
               **side("r", arm=160.0, out=18.0, elb=40.0, leg=-10.0, knee=50.0),
               "roll": 7.0, "nod": -22.0, "look": 26.0, "sq": -0.04}),
        (0.4, {**side("r", arm=166.0, out=14.0, elb=34.0, leg=30.0, knee=30.0),
               **side("l", arm=160.0, out=18.0, elb=40.0, leg=-10.0, knee=50.0),
               "roll": -7.0, "look": -18.0}),
    ], loop=True, beats={"kick": [0.0, 0.4]}, driven="time")


def clips():
    return [idle(), look(), wake(), peek(), rise(), sink(), walk(), haul(), climb(), mantle(),
            drop(), land(), fall(), shake(), cling(), leap(), ride()]
