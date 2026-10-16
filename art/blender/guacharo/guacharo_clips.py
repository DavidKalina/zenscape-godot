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
    "reach": 0.0, "toes": 0.0, "strike": 0.0,
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
            # strike: the shin and foot thrown straight out ahead (the talons at him)
            k = v["strike"]
            out[f"shin.{s}"] = (None, _rot(m((-25 * r + 45 * k, 0, 0))), None)
            out[f"foot.{s}"] = (None, _rot(m((-40 * r + 30 * v["toes"] + 55 * k, 0, 0))), None)
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


# ------------------------------------------------------------------ the hunt
# The hunt's lengths (lane guacharo-hunt, guacharo.gd): TELL 0.95 s, the scream
# for its first TELL_SCREAM (0.45) of it, the rest the teardrop's hold; the
# dive up to STOOP_MAX 2.5 s; clicks every CLICK_SLOW 0.42 .. CLICK_FAST 0.07 s.
# The one-shot clips (scream, fold) do their move early and end on a held pose:
# a longer tell only lengthens the hold (the player clamps on the last frame).
TELL = 0.95
TELL_SCREAM = 0.45
SCREAM = TELL * TELL_SCREAM      # 0.43 s
FOLD = TELL - SCREAM             # 0.52 s
FLARE = 0.22                     # the strike's flare, before contact
LIFT = 0.7                       # the snatch's first hard beats
CARRY = 1.5
PULL = 1.1

# hovering: body raised steep, tail fanned down as a brake, feet let down a
# little, the head held level and staring down at him
STALK = dict(pitch=38, tail=-22, fan=1.2, reach=0.12, toes=0.3, neck=-14, head=-30, stretch=1.0,
             **both(elev=20, sweep=-6, fold=0.1, twist=0, spread=1.0, hand=0))
# the teardrop: wings shut against the body, primaries and tail closed,
# drawn long, the head pushed forward along the line of the dive
TEARDROP = dict(pitch=-6, stretch=1.16, tail=2, fan=0.0, reach=0.0, toes=0.0,
                neck=8, head=-4, head_yaw=0, head_roll=0, jaw=0.25, bob=0.0, roll=0.0,
                **both(elev=0, sweep=0, fold=1.0, twist=0, spread=0.0, hand=0))


def _click(t, at, v, big=1.0):
    """One click at time `at`: a quick dip of the head with the beak snapped
    a crack open (40 ms down, 80 ms back)."""
    d = t - at
    if d < 0.0 or d > 0.12:
        return
    k = d / 0.04 if d < 0.04 else 1.0 - (d - 0.04) / 0.08
    k = k * k * (3 - 2 * k)
    v["head"] -= 9.0 * big * k
    v["jaw"] += 0.22 * big * k
    v["neck"] += 3.0 * big * k


def _stalk_extra(t, v):
    # a click on each beat's bottom hold: CLICK_SLOW's rate (the look adds
    # the faster clicks of a committing bird procedurally at the mind's rate)
    for at in (0.14, 0.64):
        _click(t, at, v)
    v["tail_roll"] += 3.0 * math.sin(t * math.tau / 1.0 + 0.7)


def stalk():
    """1 s loop, two hovering beats (the hunt beats at 2 Hz in the stalk).
    The body hangs steep, the wings row forward and down on the stroke and
    flick back and up with the wrist turned, the tail fanned as a brake;
    the head stays put while the body heaves under it (a hovering bird's
    stare) and clicks on each beat's low point."""
    top = dict(STALK, **both(elev=54, sweep=4, fold=0.12, twist=14, spread=1.12, hand=8),
               bob=-0.03, stretch=1.03, head=-26, neck=-12)
    stroke = dict(**both(elev=4, sweep=-26, fold=0.0, twist=-16, spread=1.05, hand=-6),
                  bob=0.02, stretch=0.99, head=-31, neck=-15)
    bottom = dict(**both(elev=-10, sweep=-22, fold=0.06, twist=-8, spread=0.95, hand=-6),
                  bob=0.05, stretch=0.94, pitch=35, head=-34, neck=-16)
    up = dict(**both(elev=24, sweep=10, fold=0.38, twist=22, spread=0.55, hand=-8),
              bob=0.0, stretch=1.02, pitch=39, head=-29, neck=-14)
    keys = []
    for o in (0.0, 0.5):
        keys += [(o + 0.00, top, True), (o + 0.13, stroke), (o + 0.24, bottom, True), (o + 0.38, up)]
    return Clip("stalk", 1.0, keys, extra=_stalk_extra)


def scream():
    """0.43 s one-shot (the tell's first TELL_SCREAM), ends held. From the
    hover it ducks (head pulled in, wings dipped forward, the body squashed:
    the anticipation), then throws the wings straight up and back with the
    primaries and tail splayed wide, rears, stretches tall and opens the
    beak full; a little overshoot, then the hold."""
    return Clip("scream", SCREAM, [
        (0.00, dict(STALK), False),
        # the duck: everything drawn in and down
        (0.09, dict(**both(elev=-14, sweep=-18, fold=0.25, twist=-10, spread=0.8, hand=-12),
                    pitch=22, stretch=0.88, bob=-0.04, neck=-24, head=-18, jaw=0.1, tail=-30, fan=0.9), True),
        (0.13, dict(stretch=0.86, neck=-26, bob=-0.045), True),   # held a beat: the breath in
        # the throw: past the hold pose
        (0.21, dict(**both(elev=88, sweep=14, fold=0.0, twist=18, spread=1.22, hand=14),
                    pitch=40, stretch=1.12, bob=0.05, neck=10, head=14, jaw=1.05, tail=-36, fan=1.3,
                    reach=0.35, toes=0.8)),
        # the hold: wide, rearing, beak open
        (0.27, dict(**both(elev=80, sweep=10, fold=0.0, twist=14, spread=1.18, hand=10),
                    pitch=38, stretch=1.07, bob=0.04, neck=8, head=10, jaw=1.0, tail=-34, fan=1.25,
                    reach=0.3, toes=0.7), True),
        (SCREAM, dict(), True),
    ], loop=False)


def fold():
    """0.52 s one-shot (the tell's rest), ends held on the teardrop. From
    the scream's thrown-up wings it snaps them shut in one beat (the arms
    drop and fold, the primaries close last), tips its nose down and draws
    itself long, beak still parted; the stretch overshoots and settles."""
    thrown = dict(**both(elev=80, sweep=10, fold=0.0, twist=14, spread=1.18, hand=10),
                  pitch=38, stretch=1.07, bob=0.04, neck=8, head=10, jaw=1.0, tail=-34, fan=1.25,
                  reach=0.3, toes=0.7)
    return Clip("fold", FOLD, [
        (0.00, thrown, True),
        # the snap: arms half in, still high; the body tips over
        (0.07, dict(**both(elev=40, sweep=40, fold=0.6, twist=6, spread=0.5, hand=4),
                    pitch=8, stretch=1.0, bob=0.02, neck=0, head=0, jaw=0.6, tail=-10, fan=0.5,
                    reach=0.1, toes=0.2)),
        # shut, and overshooting long
        (0.13, dict(TEARDROP, stretch=1.22, pitch=-10, jaw=0.4, **both(elev=-3, spread=0.0, fold=1.0, sweep=0))),
        (0.20, dict(TEARDROP), True),
        (FOLD, dict(), True),
    ], loop=False)


def _stoop_extra(t, v):
    # the shudder of the air past it: a fast tremor in the shut wings and tail
    for s, ph in (("L", 0.0), ("R", 1.9)):
        v[f"elev.{s}"] += 1.6 * math.sin(t * math.tau * 9.0 + ph) + 0.8 * math.sin(t * math.tau * 14.0 + ph * 2)
        v[f"hand.{s}"] += 1.2 * math.sin(t * math.tau * 11.0 + ph)
    v["roll"] += 1.2 * math.sin(t * math.tau * 7.0)
    v["tail_roll"] += 3.0 * math.sin(t * math.tau * 8.0 + 0.5)
    v["head_roll"] -= 0.6 * math.sin(t * math.tau * 7.0)   # the head steadier than the body


def stoop():
    """1 s loop, the dive: the teardrop shuddering in the rush of air, the
    wrists trimmed open a crack and shut again (steering), the head locked
    forward on him."""
    return Clip("stoop", 1.0, [
        (0.00, dict(TEARDROP), True),
        (0.35, dict(**both(fold=0.9, elev=3, sweep=-3, spread=0.08), stretch=1.13, tail=4), True),
        (0.55, dict(**both(fold=1.0, elev=0, sweep=0, spread=0.0), stretch=1.17, tail=1)),
        (0.75, dict(TEARDROP), True),
    ], extra=_stoop_extra)


# the flare: wings thrown open forward as air brakes, the body reared, the
# legs swung through with the talons spread at him, the head down on him
FLARED = dict(**both(elev=62, sweep=-24, fold=0.0, twist=34, spread=1.2, hand=12),
              pitch=52, stretch=0.92, bob=0.02, neck=-10, head=-44, head_yaw=0, jaw=0.9,
              tail=-40, fan=1.35, reach=1.3, toes=-0.6, strike=1.0)


def flare():
    """0.22 s one-shot (FLARE before contact), ends held. From the teardrop
    the wings burst open (the arms first, the hands and primaries flung
    out after: the follow-through), the body slams up against the brake
    (the squash), the legs swing through and the talons open; it overshoots
    and settles into the strike pose."""
    return Clip("flare", FLARE, [
        (0.00, dict(TEARDROP), False),
        # the burst: arms out, still swept back, the body starting up
        (0.05, dict(**both(elev=30, sweep=20, fold=0.45, twist=10, spread=0.5, hand=-6),
                    pitch=14, stretch=1.05, neck=0, head=-20, jaw=0.6, tail=-14, fan=0.7,
                    reach=0.45, toes=0.2, strike=0.3)),
        # past the pose: reared further, squashed by the brake, talons wide
        (0.12, dict(FLARED, **both(elev=70, sweep=-30, twist=40, spread=1.28, hand=16),
                    pitch=60, stretch=0.86, reach=1.42, toes=-0.8, strike=1.15, head=-50, jaw=1.05, fan=1.45)),
        (0.17, dict(FLARED), True),
        (FLARE, dict(), True),
    ], loop=False)


def _carry_extra(t, v):
    # the load swings under it: the body rolls and the legs trail the beat
    v["roll"] += 4.0 * math.sin(t * math.tau / 0.5 + 0.8)
    v["tail_roll"] += 5.0 * math.sin(t * math.tau / 0.5 + 2.0)
    v["reach"] += 0.05 * math.sin(t * math.tau / 0.5 - 1.2)


def carry():
    """0.5 s loop, one hard beat with a load (a 2 Hz beat; the hunt beats
    at 2.4 Hz: the look plays it at freq/2). Deeper than the flap: the body
    hangs upright from the load, the legs locked down with the talons shut;
    the wings reach far up and back (a straining hold at the top), the power
    stroke drives all the way under it and the body heaves up on it, then
    sags back as the wings come up (the weight)."""
    base = dict(pitch=30, reach=0.75, toes=1.0, neck=-8, head=-12, tail=-18, fan=1.15)
    return Clip("carry", 0.5, [
        # the top: wings high and back, the body sagged under the load
        (0.00, dict(base, **both(elev=72, sweep=12, fold=0.05, twist=14, spread=1.2, hand=12),
                    bob=-0.07, stretch=1.07, jaw=0.15), True),
        # the drive: fast, forward, leading edge down
        (0.13, dict(**both(elev=10, sweep=-18, fold=0.0, twist=-16, spread=1.1, hand=-4),
                    bob=0.0, stretch=1.0, pitch=26, jaw=0.35)),
        # the bottom: far under, the body heaved up and squashed
        (0.24, dict(**both(elev=-44, sweep=-20, fold=0.06, twist=-8, spread=0.95, hand=-10),
                    bob=0.06, stretch=0.9, pitch=24, head=-8, tail=-24, jaw=0.2), True),
        # the recovery: wrists flexed, primaries shut, the body sagging again
        (0.38, dict(**both(elev=26, sweep=14, fold=0.42, twist=22, spread=0.5, hand=-10),
                    bob=-0.04, stretch=1.03, pitch=31, head=-12, tail=-16)),
    ], extra=_carry_extra)


def pull():
    """1.1 s one-shot (PULL), ends held. Out of the dive (or the drop): the
    wings snap open, the body pitches up against the pull (squashed by it),
    then two heavy climbing beats, slower on the second, and it settles
    level into the glide."""
    up = dict(**both(elev=64, sweep=8, fold=0.06, twist=12, spread=1.18, hand=10), stretch=1.05, bob=-0.03)
    drive = dict(**both(elev=6, sweep=-14, fold=0.0, twist=-12, spread=1.08, hand=-4), stretch=1.0, bob=0.02)
    low = dict(**both(elev=-34, sweep=-14, fold=0.05, twist=-6, spread=0.95, hand=-8), stretch=0.92, bob=0.06)
    rec = dict(**both(elev=22, sweep=12, fold=0.35, twist=16, spread=0.55, hand=-8), stretch=1.02, bob=0.0)
    return Clip("pull", PULL, [
        (0.00, dict(TEARDROP, pitch=-12), False),
        # the snap open: wings out against the rush, the body levering up
        (0.10, dict(**both(elev=36, sweep=6, fold=0.2, twist=26, spread=1.0, hand=4),
                    pitch=22, stretch=0.84, bob=0.03, tail=-20, fan=1.2, neck=-6, head=-10, jaw=0.3)),
        (0.18, dict(up, pitch=30, tail=-14, fan=1.1, head=-6, jaw=0.1), True),
        # beat one
        (0.30, dict(drive, pitch=28)),
        (0.40, dict(low, pitch=26), True),
        (0.52, dict(rec, pitch=24)),
        # beat two, slower
        (0.62, dict(up, pitch=20, tail=-8), True),
        (0.76, dict(drive, pitch=16)),
        (0.88, dict(low, pitch=12, stretch=0.95), True),
        # settle into the glide
        (1.00, dict(**both(elev=6, sweep=0, fold=0.0, twist=2, spread=1.0, hand=-3),
                    pitch=2, stretch=1.0, bob=0.0, tail=-3, fan=0.85, head=-6, neck=-4, jaw=0.0)),
        (PULL, dict(**both(elev=4), pitch=0), True),
    ], loop=False)


def hurt():
    """0.5 s one-shot flinch, ends held on the glide. Struck: the head
    snaps back and the beak gapes, the wings fling up crooked (one higher,
    the primaries splayed), the body jolts back and rolls off its line
    (squash, then a stretch on the rebound); then it shakes itself and
    catches the air again, the right wing a beat behind the left."""
    glide_pose = dict(**both(elev=4, sweep=0, fold=0.0, twist=2, spread=1.0, hand=-3),
                      pitch=0, roll=0, stretch=1.0, bob=0.0, tail=-3, fan=0.85, head=-6, neck=-4,
                      head_yaw=0, head_roll=0, jaw=0.0, reach=0.0, toes=0.0)
    return Clip("hurt", 0.5, [
        (0.00, glide_pose, False),
        # the jolt: hit, everything thrown back, squashed
        (0.05, dict(**{"elev.L": 58, "sweep.L": 26, "twist.L": 20, "spread.L": 1.3, "hand.L": 18,
                       "elev.R": 34, "sweep.R": 34, "twist.R": 8, "spread.R": 1.25, "hand.R": 24,
                       "fold.L": 0.1, "fold.R": 0.25},
                    pitch=18, roll=16, stretch=0.82, bob=0.05, neck=16, head=26, head_roll=-18,
                    jaw=1.0, tail=16, fan=1.4, reach=0.5, toes=-0.6)),
        # the rebound: stretched, rolled the other way, held a moment (stunned)
        (0.13, dict(**{"elev.L": 20, "sweep.L": 6, "twist.L": 4, "spread.L": 1.1, "hand.L": 0,
                       "elev.R": 46, "sweep.R": 18, "twist.R": 12, "spread.R": 1.2, "hand.R": 14,
                       "fold.L": 0.05, "fold.R": 0.15},
                    pitch=6, roll=-10, stretch=1.1, bob=-0.02, neck=4, head=6, head_roll=10,
                    jaw=0.6, tail=-6, fan=1.1, reach=0.3, toes=0.2), True),
        (0.22, dict(roll=-12, stretch=1.08, head_roll=12), True),
        # the shake and the catch: the right wing comes down last
        (0.32, dict(**{"elev.L": -2, "elev.R": 22, "twist.R": 6, "hand.R": 4, "spread.R": 1.05},
                    roll=4, pitch=1, stretch=0.97, head=-8, head_roll=-4, jaw=0.2, tail=-4, reach=0.05, toes=0.0)),
        (0.42, dict(glide_pose, roll=-2, **{"elev.R": 2}), False),
        (0.5, dict(glide_pose), True),
    ], loop=False)


def clips():
    return [glide(), flap(), circle(), stalk(), scream(), fold(), stoop(), flare(), carry(), pull(), hurt()]
