"""The guacharo's clips, keyed onto guacharo_build.py's rig (imported by it).

A clip is a track of key poses in a few named channels (the body's bob,
pitch, roll and stretch; the neck and head; each wing's elevation, sweep,
fold, twist and primary spread; the tail's pitch, fan and roll; the legs'
reach), eased between with cubic Hermite curves. A key marked `hold` has flat
tangents (an eased stop); the others pass through with Catmull-Rom tangents
(they may overshoot a little, on purpose). Each key carries the channels of
the one before, so a key lists only what changes.

Follow-through is computed, not keyed: the hands trail the arms' elevation
by HAND_LAG, the primaries trail the hands by PRIM_LAG (more the further
out), the tail trails the body's pitch and the head counters the body's bob.

Rotations are given in the rig's rest axes (x the right wing, y forward,
z up), for the LEFT wing; the right is mirrored. Signs (left wing):
  elev  + up        (about y)      sweep + back       (about z)
  twist + leading edge up (about x)
  head pitch + up (about x), yaw + left (about z); tail pitch + up.

    clips(rig) -> list of Clip; bake(rig, clip) -> bpy.types.Action

Lengths match guacharo.gd's beats (lane guacharo-hunt): one flap is a 2 Hz
beat (0.5 s; the look plays it at the state's rate: 1.7, 2.0 or 2.4 Hz).
"""
import math

import bpy
from mathutils import Euler, Quaternion, Vector

FPS = 30
HAND_LAG = 0.07     # s, the hand behind the arm
HAND_GAIN = 0.7
PRIM_LAG = 0.05     # s, the outer primary behind the hand
PRIM_GAIN = 0.55

# Every channel and its rest value (rest = the glide pose the model is built in).
WING = {"elev": 0.0, "sweep": 0.0, "fold": 0.0, "twist": 0.0, "spread": 1.0, "hand": 0.0}
REST = {
    "bob": 0.0, "pitch": 0.0, "roll": 0.0, "yaw": 0.0, "stretch": 1.0,
    "neck": 0.0, "head": 0.0, "head_yaw": 0.0, "head_roll": 0.0, "jaw": 0.0,
    "tail": 0.0, "fan": 1.0, "tail_roll": 0.0,
    "reach": 0.0, "toes": 0.0,
}
for _s in "LR":
    for _k, _v in WING.items():
        REST[f"{_k}.{_s}"] = _v


def both(**kw):
    """Wing channels for both sides: both(elev=10) -> {'elev.L': 10, 'elev.R': 10}."""
    out = {}
    for k, v in kw.items():
        out[f"{k}.L"] = v
        out[f"{k}.R"] = v
    return out


class Clip:
    """keys: [(t, {channel: value}, hold?)]; extra(t, v) adds procedural motion."""

    def __init__(self, name, length, keys, loop=True, extra=None):
        self.name, self.length, self.loop, self.extra = name, length, loop, extra
        full, cur = [], dict(REST)
        for k in keys:
            t, d = k[0], k[1]
            hold = k[2] if len(k) > 2 else False
            cur = dict(cur)
            cur.update(d)
            full.append((t, cur, hold))
        if loop:
            full.append((length, full[0][1], full[0][2]))
        self.keys = full

    def _tangent(self, i, ch):
        ks = self.keys
        n = len(ks)
        if ks[i][2]:
            return 0.0
        if self.loop:
            # the last key repeats the first: neighbours wrap past it
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

    def raw(self, t):
        if self.loop:
            t = t % self.length
        else:
            t = min(max(t, 0.0), self.length)
        ks = self.keys
        if t <= ks[0][0]:
            return dict(ks[0][1])
        if t >= ks[-1][0]:
            return dict(ks[-1][1])
        i = 0
        while ks[i + 1][0] < t:
            i += 1
        t0, a, _ = ks[i]
        t1, b, _ = ks[i + 1]
        h = t1 - t0
        u = (t - t0) / h
        h00, h10 = 2 * u ** 3 - 3 * u ** 2 + 1, u ** 3 - 2 * u ** 2 + u
        h01, h11 = -2 * u ** 3 + 3 * u ** 2, u ** 3 - u ** 2
        out = {}
        for ch in a:
            out[ch] = (h00 * a[ch] + h10 * h * self._tangent(i, ch)
                       + h01 * b[ch] + h11 * h * self._tangent(i + 1, ch))
        return out

    def values(self, t):
        v = self.raw(t)
        if self.extra:
            self.extra(t, v)
        return v

    def lagged(self, t, lag):
        if not self.loop:
            t = max(t - lag, 0.0)
            return self.values(t)
        return self.values(t - lag)


# ------------------------------------------------------------------ the rig's math
def q(x=0.0, y=0.0, z=0.0):
    """Degrees about the rest axes: x first, then y, then z (all extrinsic)."""
    return Euler((math.radians(x), math.radians(y), math.radians(z)), "XYZ").to_quaternion()


def mirror(x, y, z):
    return (x, -y, -z)


class Rig:
    def __init__(self, rig):
        self.ob = rig
        self.rest = {b.name: b.matrix_local.to_quaternion() for b in rig.data.bones}
        self.vec = {b.name: (b.tail_local - b.head_local) for b in rig.data.bones}
        self.prims = sorted(n for n in self.rest if n.startswith("prim.") and n.endswith(".L"))
        self.prims.sort(key=lambda n: int(n.split(".")[1]))
        self.tails = sorted((n for n in self.rest if n.startswith("tail.")), key=lambda n: int(n.split(".")[1]))
        # each primary's angle from straight back toward the span (degrees)
        self.prim_th = {n: math.degrees(math.atan2(abs(self.vec[n].x), -self.vec[n].y)) for n in self.prims}
        self.tail_a = {n: math.degrees(math.atan2(self.vec[n].x, -self.vec[n].y)) for n in self.tails}
        self.th_out = max(self.prim_th.values())

    def local(self, name, rot):
        r = self.rest[name]
        return r.inverted() @ rot @ r

    def pose(self, clip, t):
        """bone -> (location, quaternion, scale) for the rig's pose bones."""
        v = clip.values(t)
        vh = clip.lagged(t, HAND_LAG)
        vp = clip.lagged(t, HAND_LAG + PRIM_LAG)
        out = {}
        st = max(v["stretch"], 0.3)
        w = 1.0 / math.sqrt(st)
        out["root"] = (Vector((0, 0, v["bob"])), q(v["pitch"], v["roll"], v["yaw"]), Vector((w, st, w)))
        out["chest"] = (None, q(), None)
        out["pelvis"] = (None, q(-0.3 * v["pitch"]), None)
        out["neck"] = (None, q(v["neck"]), None)
        out["head"] = (None, q(v["head"], v["head_roll"], v["head_yaw"]), None)
        out["jaw"] = (None, q(-38.0 * v["jaw"]), None)
        # the tail trails the body's pitch a little
        out["tail"] = (None, q(v["tail"] + 0.35 * (vh["pitch"] - v["pitch"]), v["tail_roll"]), None)
        for n in self.tails:
            a = self.tail_a[n]
            out[n] = (None, q(z=a * (v["fan"] - 1.0)), None)
        for s in "LR":
            m = (lambda r: r) if s == "L" else (lambda r: mirror(*r))
            el, sw, fo, tw = v[f"elev.{s}"], v[f"sweep.{s}"], v[f"fold.{s}"], v[f"twist.{s}"]
            # the arm: elevation, sweep, the fold's back-swing
            out[f"upperarm.{s}"] = (None, _rot(m((tw * 0.4, el - 12 * fo, sw + 78 * fo))), None)
            out[f"forearm.{s}"] = (None, _rot(m((tw * 0.3, 6 * fo, -158 * fo))), None)
            # the hand trails the arm (follow-through) and carries its own flex
            follow = HAND_GAIN * (vh[f"elev.{s}"] - el)
            out[f"hand.{s}"] = (None, _rot(m((tw * 0.3, v[f"hand.{s}"] + follow + 4 * fo, 160 * fo))), None)
            sp = v[f"spread.{s}"]
            pfollow = PRIM_GAIN * (vp[f"elev.{s}"] - vh[f"elev.{s}"])
            for i, n in enumerate(self.prims):
                k = i / max(len(self.prims) - 1, 1)
                th = self.prim_th[n]
                close = -(self.th_out + 4 - th) * (1.0 - sp)
                out[n.replace(".L", f".{s}")] = (None, _rot(m((0.0, pfollow * (0.3 + 0.7 * k), close))), None)
            r = v["reach"]
            out[f"thigh.{s}"] = (None, _rot(m((95 * r, -6 * r, 0))), None)
            out[f"shin.{s}"] = (None, _rot(m((-25 * r, 0, 0))), None)
            out[f"foot.{s}"] = (None, _rot(m((-40 * r + 30 * v["toes"], 0, 0))), None)
            out[f"toes.{s}"] = (None, _rot(m((-50 * v["toes"], 0, 0))), None)
        return out


def _rot(xyz):
    return q(*xyz)


def bake(R, clip):
    rig = R.ob
    frames = max(1, round(clip.length * FPS))
    action = bpy.data.actions.new(clip.name)
    action.use_fake_user = True
    rig.animation_data.action = action
    last = {}
    for f in range(frames + 1):
        t = clip.length * f / frames
        P = R.pose(clip, t)
        for pb in rig.pose.bones:
            loc, rot, scl = P.get(pb.name, (None, q(), None))
            rot = R.local(pb.name, rot)
            if pb.name in last and last[pb.name].dot(rot) < 0:
                rot.negate()
            last[pb.name] = rot
            pb.rotation_quaternion = rot
            pb.keyframe_insert("rotation_quaternion", frame=f)
            pb.location = R.rest[pb.name].inverted() @ loc if loc is not None else Vector()
            pb.keyframe_insert("location", frame=f)
            if pb.name == "root":
                pb.scale = scl
                pb.keyframe_insert("scale", frame=f)
    action.frame_range = (0, frames)
    rig.animation_data.nla_tracks.new().strips.new(clip.name, 0, action)
    rig.animation_data.action = None
    print(f"GUACHARO_CLIP {clip.name} frames={frames} seconds={clip.length:.3f} loop={clip.loop}")
    return action


def reset(rig):
    for pb in rig.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.scale = (1, 1, 1)


# ================================================================== the clips
def _glide_extra(t, v):
    # the air under it: a slow swell through the wings, a tremor at the tips
    sw = math.sin(t * math.tau / 4.0)
    v["bob"] += 0.012 * sw
    for s in "LR":
        v[f"elev.{s}"] += 2.0 * math.sin(t * math.tau / 4.0 + 0.6)
        v[f"twist.{s}"] += 1.2 * math.sin(t * math.tau / 2.0 + (0.0 if s == "L" else 1.3))
        v[f"hand.{s}"] += 0.7 * math.sin(t * math.tau * 3.0 + (0.0 if s == "L" else 2.1))
    v["tail_roll"] += 2.5 * math.sin(t * math.tau / 4.0 + 1.9)


def glide():
    """4 s loop. Wings held a touch above level (a dihedral), primaries
    fingered, the tail half fanned; the head looks down one side, holds,
    snaps to the other, holds, and back."""
    base = dict(both(elev=4, twist=2, spread=1.0, hand=-3), tail=-3, fan=0.85, head=-6, neck=-4)
    return Clip("glide", 4.0, [
        (0.0, dict(base, head_yaw=0, head_roll=0), True),
        (0.55, dict(head_yaw=24, head_roll=-14, head=-14), False),   # the snap
        (0.70, dict(head_yaw=28, head_roll=-16, head=-16), True),    # look down, hold
        (1.75, dict(head_yaw=26, head_roll=-15, head=-15), True),
        (2.05, dict(head_yaw=-30, head_roll=16, head=-16), False),
        (2.20, dict(head_yaw=-27, head_roll=14, head=-14), True),
        (3.25, dict(head_yaw=-25, head_roll=13, head=-13), True),
        (3.60, dict(head_yaw=0, head_roll=0, head=-6), False),
    ], extra=_glide_extra)


def flap():
    """0.5 s loop, one heavy beat. The top (wings high, hands flicked up,
    primaries splayed: the anticipation), the long power stroke down with
    the body lifted on it, the bottom (wings swept forward and low, the
    body's squash), the quick upstroke with the wrist flexed and the
    primaries closed."""
    return Clip("flap", 0.5, [
        # the top: wings up and a touch back, the anticipation
        (0.00, dict(both(elev=58, sweep=6, fold=0.08, twist=10, spread=1.12, hand=8),
                    bob=-0.03, pitch=4, stretch=1.04, tail=4, fan=0.9, head=-8, neck=-6), True),
        # the power stroke: fast through level, wings forward, leading edge down
        (0.15, dict(both(elev=8, sweep=-10, fold=0.0, twist=-12, spread=1.05, hand=-4),
                    bob=0.02, pitch=-2, stretch=1.0, tail=-4)),
        # the bottom: low and forward, the body heaved up, the squash
        (0.27, dict(both(elev=-30, sweep=-12, fold=0.05, twist=-6, spread=0.95, hand=-8),
                    bob=0.06, pitch=-5, stretch=0.93, tail=-8, fan=1.0, head=-4, neck=-2), True),
        # the upstroke: wrists flexed, primaries closed, wing drawn up and back
        (0.40, dict(both(elev=20, sweep=12, fold=0.3, twist=14, spread=0.6, hand=-6),
                    bob=0.0, pitch=2, stretch=1.02, tail=0)),
    ])


def _circle_extra(t, v):
    # its head sweeps the ground below the turn, then holds
    v["bob"] += 0.01 * math.sin(t * math.tau / 4.0)
    for s in "LR":
        v[f"twist.{s}"] += 1.0 * math.sin(t * math.tau / 2.0 + (0.4 if s == "L" else 1.7))
        v[f"hand.{s}"] += 0.6 * math.sin(t * math.tau * 3.0 + (0.0 if s == "L" else 2.4))


def circle():
    """4 s loop, banked left (into the turn; the look mirrors the body's
    turn by its yaw). Rolled 22 degrees: the inner (left) wing flexed and
    swept a little, the outer reached long, the tail twisted to steer and
    fanned wide; the head turned in and down at the ground, scanning in
    two held looks, and one slow corrective half-beat."""
    base = dict(roll=-22, pitch=2, fan=1.1, tail=-2, tail_roll=-14,
                **{"elev.L": 2, "sweep.L": 8, "fold.L": 0.12, "twist.L": 5, "spread.L": 0.85, "hand.L": -6,
                   "elev.R": 6, "sweep.R": -4, "fold.R": 0.0, "twist.R": 0, "spread.R": 1.1, "hand.R": 0},
                head=-18, neck=-6, head_yaw=30, head_roll=-10)
    return Clip("circle", 4.0, [
        (0.0, base, True),
        (0.9, dict(head_yaw=34, head=-24, head_roll=-14), True),
        (1.25, dict(head_yaw=18, head=-26, head_roll=-6), False),
        (1.4, dict(head_yaw=16, head=-26, head_roll=-5), True),
        # the corrective half-beat: the outer wing presses down, the roll holds
        (2.2, dict(**{"elev.R": 15, "hand.R": 5, "twist.R": 6, "spread.R": 1.15}, roll=-24), True),
        (2.45, dict(**{"elev.R": -4, "hand.R": -4, "twist.R": -8, "sweep.R": -10}, roll=-19, bob=0.03)),
        (2.75, dict(**{"elev.R": 6, "hand.R": 0, "twist.R": 0, "sweep.R": -4}, roll=-22, bob=0.0), True),
        (3.4, dict(head_yaw=30, head=-18, head_roll=-10), False),
    ], extra=_circle_extra)


def clips():
    return [glide(), flap(), circle()]
