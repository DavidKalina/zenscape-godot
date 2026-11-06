"""The elk's clips (imported by elk_build.py).

The contract is docs/design/endless-flight/spec-wild-kit-elk.md: the clip
names, lengths, loops, ground per cycle and beats there are the ones here
(CLIPS below), and the build writes them to assets/models/elk/elk_clips.json
beside the glb for the body script, since glTF carries no markers. In the
.blend the beats are each action's pose markers.

The clips are key poses in named channels, eased between with cubic Hermite
curves (the brood's pattern): a key marked `hold` has flat tangents (an eased
stop), the others pass through with Catmull-Rom tangents. Each key carries
the channels of the one before, so a key lists only what changes. A clip's
`post(t, values)` may add procedural motion on top (the gaits' feet).

The legs are solved, not keyed by angle: each foot is a target on the
ground (its toe), and the leg reaches it, so a foot that holds still on the
ground stays planted however the body moves over it. The fore leg is a
two-bone reach (upper arm, then forearm and cannon as one piece bent at the
knee by `kf`), its shoulder blade swinging with the leg; the hind leg the
same (thigh, then shin and cannon bent at the hock), the hock folding with
the stifle as a real one does (COUPLE). The hoof's angle to the ground is a
channel, so a planted hoof stays flat.

Follow-through is computed, not keyed: a damped spring trails the neck's and
body's motion, and the head, ears and tail get its lag (FOLLOW), so they
drag, overshoot and settle.

Units: span (the plane's span is 1). BL is one body length (the spec's 0.9
span). Blender +z up, +y his front, +x his right.

Channels (degrees, span for moves):
  bob surge sway       the body's move (up, forward, to his right)
  pitch roll yaw       the body (+ front up, + leaning to his right, + turning to his left)
  flex                 the back (+ rounded: rump tucked under, chest down; - hollow)
  neck                 the neck (+ up from its rest slope)
  look                 the neck and head turned (+ to his left), spread down the neck
  nod tilt             the head (+ nose up; + top to his right)
  ear.S et.S           an ear (+ pricked forward, - laid back; + swivelled back)
  tail tsw             the tail (+ up; + swished to his left)
  fy.L fz.L fx.L       a foot's toe from its rest spot (forward, up, outward), L in fl fr hl hr
  fp.L                 the hoof (+ the toe curled back from flat, as in a stride's swing)
  kf.L                 fore: the knee folded (+ cannon back); hind: the hock folded more

    CLIPS (list of Clip); Rig(rig_ob, joint); bake(R, clip) -> Action
"""
import math

import bpy
from mathutils import Matrix, Vector

V = Vector
X, Y, Z = V((1, 0, 0)), V((0, 1, 0)), V((0, 0, 1))
FPS = 60                    # every contract length a whole frame count (0.55 s); a sprint stance 3 frames
BL = 0.9                    # one body length, span (the spec's; the mesh measures 0.934)
SIDES = {"l": -1.0, "r": 1.0}
LEGS = {"fl": ("f", "l"), "fr": ("f", "r"), "hl": ("h", "l"), "hr": ("h", "r")}
LEG_CH = ("fy", "fz", "fx", "fp", "kf")

REST = {"bob": 0.0, "surge": 0.0, "sway": 0.0, "pitch": 0.0, "roll": 0.0, "yaw": 0.0, "flex": 0.0,
        "neck": 0.0, "look": 0.0, "nod": 0.0, "tilt": 0.0, "tail": 0.0, "tsw": 0.0}
for _s in SIDES:
    REST[f"ear.{_s}"] = 0.0
    REST[f"et.{_s}"] = 0.0
for _l in LEGS:
    for _c in LEG_CH:
        REST[f"{_c}.{_l}"] = 0.0

## The shoulder blade's swing with the fore leg's reach (of the leg's angle).
SCAP = 0.35
## The hock folds with the stifle (of the stifle's fold).
COUPLE = 0.8
## How the neck shares a turn and a raise down its two bones and the head.
LOOK_SHARE = (0.40, 0.35, 0.25)
NECK_SHARE = (0.68, 0.32)

## Follow-through: (channel it adds to, its driver from the keyed values,
## spring frequency Hz, damping ratio, gain). The lag of a spring chasing the
## driver, times the gain, is added: the head drags behind the neck's swing,
## the ears behind the head's, the tail behind the body's bob.
HEAD_BOB, EAR_BOB, TAIL_BOB = 260.0, 500.0, 900.0


def _head_drive(v):
    return v["neck"] + v["pitch"] - 0.5 * v["flex"] + HEAD_BOB * v["bob"]


def _ear_drive(v):
    return v["neck"] + v["nod"] + v["pitch"] + EAR_BOB * v["bob"]


def _tail_drive(v):
    return v["pitch"] + 0.5 * v["flex"] + TAIL_BOB * v["bob"]


FOLLOW = (
    ("nod", _head_drive, 2.6, 0.6, 0.18),
    ("ear.l", _ear_drive, 3.6, 0.30, 0.55),
    ("ear.r", _ear_drive, 3.3, 0.30, 0.55),
    ("tail", _tail_drive, 3.0, 0.35, 0.60),
)


def legs(*names, **kw):
    """legs("fl", "hr", fz=0.1) -> {"fz.fl": .1, "fz.hr": .1}; no names: all four."""
    out = {}
    for leg in names or tuple(LEGS):
        for k, val in kw.items():
            out[f"{k}.{leg}"] = val
    return out


def ears(**kw):
    out = {}
    for s in SIDES:
        for k, val in kw.items():
            out[f"{k}.{s}"] = val
    return out


class Clip:
    """keys: [(t, {channel: value}, hold?)]; beats {name: [t, ...]};
    ground: the ground covered, BL per cycle for a loop, over the clip for a
    one-shot (the node is moved by the mind; nothing moves the root here);
    ground_curve(u) -> the fraction of it covered by u = t / length (one-shots);
    shots: the times its strip shows (default the keys and beats)."""

    def __init__(self, name, length, keys, loop=False, beats=None, ground=0.0, ground_curve=None,
                 post=None, shots=None, scap=SCAP):
        self.name, self.length, self.loop = name, length, loop
        self.scap = scap
        self.beats = beats or {}
        self.ground, self.ground_curve = ground, ground_curve
        self.post = post
        full, cur = [], dict(REST)
        for k in keys:
            cur = dict(cur)
            for ch in k[1]:
                assert ch in REST, (name, ch)
            cur.update(k[1])
            full.append((k[0], cur, k[2] if len(k) > 2 else False))
        if loop:
            full.append((length, full[0][1], full[0][2]))
        self.keys = full
        ts = {k[0] for k in full if k[0] < length or not loop}
        for bt in self.beats.values():
            ts.update(bt)
        self.shots = sorted(shots if shots is not None else ts)
        self._lags = None

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
            if i == 0 or i == n - 1:
                return 0.0
            ip, inx = i - 1, i + 1
            tp, tn = ks[ip][0], ks[inx][0]
        if tn - tp <= 1e-6:
            return 0.0
        return (ks[inx][1][ch] - ks[ip][1][ch]) / (tn - tp)

    def keyed(self, t):
        t = t % self.length if self.loop else min(max(t, 0.0), self.length)
        ks = self.keys
        if t <= ks[0][0] or len(ks) == 1:
            out = dict(ks[0][1])
        elif t >= ks[-1][0]:
            out = dict(ks[-1][1])
        else:
            i = 0
            while ks[i + 1][0] < t:
                i += 1
            t0, a, _ = ks[i]
            t1, b, _ = ks[i + 1]
            hh = t1 - t0
            u = (t - t0) / hh
            h00, h10 = 2 * u ** 3 - 3 * u ** 2 + 1, u ** 3 - 2 * u ** 2 + u
            h01, h11 = -2 * u ** 3 + 3 * u ** 2, u ** 3 - u ** 2
            out = {ch: h00 * a[ch] + h10 * hh * self._tangent(i, ch) + h01 * b[ch]
                   + h11 * hh * self._tangent(i + 1, ch) for ch in a}
        if self.post:
            self.post(t, out)
        return out

    def _spring(self, drive, hz, zeta, dt=1.0 / 240.0):
        """The lag (spring - driver) sampled every dt over the clip; a loop
        runs three cycles and keeps the last, so it wraps seamlessly."""
        w = 2 * math.pi * hz
        n = max(1, int(round(self.length / dt)))
        x, xv = drive(self.keyed(0.0)), 0.0
        out = []
        for _ in range(3 if self.loop else 1):
            out = []
            for i in range(n + 1):
                s = drive(self.keyed(min(i * dt, self.length)))
                out.append(x - s)
                if i < n:
                    xv += (w * w * (s - x) - 2 * zeta * w * xv) * dt
                    x += xv * dt
        return out, self.length / n

    def values(self, t):
        if self._lags is None:
            self._lags = [(ch, gain, *self._spring(fn, hz, z)) for ch, fn, hz, z, gain in FOLLOW]
        t = t % self.length if self.loop else min(max(t, 0.0), self.length)
        v = self.keyed(t)
        for ch, gain, lag, dt in self._lags:
            f = t / dt
            i = min(int(f), len(lag) - 2)
            u = f - i
            v[ch] += gain * (lag[i] * (1 - u) + lag[i + 1] * u)
        return v

    def table(self):
        out = {"length": round(self.length, 4), "loop": self.loop, "ground_bl": self.ground,
               "beats": {k: [round(x, 4) for x in ts] for k, ts in self.beats.items()}}
        if self.ground_curve and not self.loop:
            out["ground_curve"] = [[round(self.length * u / 12, 4), round(self.ground_curve(u / 12), 4)]
                                   for u in range(13)]
        return out


# ------------------------------------------------------------------ the rig's math
def rx(d): return Matrix.Rotation(math.radians(d), 4, "X")
def ry(d): return Matrix.Rotation(math.radians(d), 4, "Y")
def rz(d): return Matrix.Rotation(math.radians(d), 4, "Z")
def tr(p): return Matrix.Translation(V(p))


def about(j, m):
    return tr(j) @ m @ tr(-V(j))


def arc(a, b):
    """The shortest rotation taking direction a to direction b (3x3)."""
    return a.rotation_difference(b).to_matrix()


def place(at, rot3, rest_head):
    """An armature-space move: the bone's rest head to `at`, turned by rot3."""
    return tr(at) @ rot3.to_4x4() @ tr(-rest_head)


def two_bone(a, t, l1, l2, pole):
    """Root a, target t, lengths l1 then l2, the middle joint bent toward
    pole. Returns (middle, end); the end falls short when t is out of reach."""
    d = t - a
    dist = min(max(d.length, abs(l1 - l2) + 1e-5), l1 + l2 - 1e-5)
    u = d.normalized()
    ca = (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist)
    sa = math.sqrt(max(0.0, 1.0 - ca * ca))
    p = pole - u * pole.dot(u)
    p.normalize()
    return a + (u * ca + p * sa) * l1, a + u * dist


def reach_angle(vec, fwd, up):
    """How far forward of straight down a leg points (radians)."""
    return math.atan2(vec.dot(fwd), -vec.dot(up))


class Rig:
    def __init__(self, rig, joint):
        self.ob = rig
        self.J = {k: V(v) for k, v in joint.items()}
        self.R = {b.name: b.matrix_local.copy() for b in rig.data.bones}
        self.parent = {b.name: (b.parent.name if b.parent else None) for b in rig.data.bones}
        self.order = [b.name for b in rig.data.bones]
        self.miss = 0.0          # the worst a foot fell short of its target, this clip
        self.plant_miss = 0.0    # the same, for a foot on the ground (fz 0)
        self.scap = SCAP

    def moves(self, clip, t):
        v = clip.values(t)
        self.scap = clip.scap
        J = self.J
        D = {"root": Matrix.Identity(4)}
        D["body"] = tr((v["sway"], v["surge"], v["bob"])) @ about(
            J["body"], rz(v["yaw"]) @ ry(v["roll"]) @ rx(v["pitch"]))
        D["hips"] = D["body"] @ about(J["hips"], rx(0.5 * v["flex"]))
        D["chest"] = D["body"] @ about(J["chest"], rx(-0.5 * v["flex"]))
        lk, nk = v["look"], v["neck"]
        # a turn is about the chest's up, spread down the neck: a raised
        # neck swings round over the shoulders, the head turning on top
        D["neck1"] = D["chest"] @ about(J["neck1"], rz(LOOK_SHARE[0] * lk) @ rx(NECK_SHARE[0] * nk))
        D["neck2"] = D["neck1"] @ about(J["neck2"], rz(LOOK_SHARE[1] * lk) @ rx(NECK_SHARE[1] * nk))
        D["head"] = D["neck2"] @ about(J["head"], rz(LOOK_SHARE[2] * lk) @ rx(v["nod"])
                                       @ Matrix.Rotation(math.radians(v["tilt"]), 4, self.R["head"].to_3x3() @ Y))
        for s, sg in SIDES.items():
            D[f"ear_{s}"] = D["head"] @ about(J[f"ear_{s}"], rz(-sg * v[f"et.{s}"]) @ rx(-v[f"ear.{s}"]))
        D["tail"] = D["hips"] @ about(J["tail"], rz(v["tsw"]) @ rx(-v["tail"]))
        for leg, (fh, s) in LEGS.items():
            if fh == "f":
                self._fore(D, v, leg, s)
            else:
                self._hind(D, v, leg, s)
        return D

    def _foot(self, v, leg, j, s, fwd):
        """The toe's target and the hoof's turn (flat on the ground, but for fp)."""
        sg = SIDES[s]
        T = j("toe") + V((sg * v[f"fx.{leg}"], v[f"fy.{leg}"], v[f"fz.{leg}"]))
        fg = V((fwd.x, fwd.y, 0.0)).normalized()
        heading = arc(Y, fg)
        latg = heading @ X
        Rh = Matrix.Rotation(-math.radians(v[f"fp.{leg}"]), 3, latg) @ heading
        return T, Rh

    def _fore(self, D, v, leg, s):
        J = self.J
        j = lambda k: J[f"f_{k}_{s}"]  # noqa: E731
        Dc = D["chest"]
        Rc = Dc.to_3x3()
        lat, fwd, up = Rc @ X, Rc @ Y, Rc @ Z
        T, Rhoof = self._foot(v, leg, j, s, fwd)
        Fk = T - Rhoof @ (j("toe") - j("fetlock"))
        # the shoulder blade swings with the leg's reach
        scap_at = Dc @ j("scap")
        rest = reach_angle(j("fetlock") - j("shoulder"), Y, Z)
        now = reach_angle(Fk - Dc @ j("shoulder"), fwd, up)
        Rs = Matrix.Rotation(self.scap * (now - rest), 3, lat) @ Rc
        S = scap_at + Rs @ (j("shoulder") - j("scap"))
        fa, cn = j("knee") - j("elbow"), j("fetlock") - j("knee")
        Rk = Matrix.Rotation(-math.radians(v[f"kf.{leg}"]), 3, X)
        cn2 = Rk @ cn
        low = fa + cn2
        E, Fe = two_bone(S, Fk, (j("elbow") - j("shoulder")).length, low.length, -fwd)
        Rup = arc(Rs @ (j("elbow") - j("shoulder")), E - S) @ Rs
        RL = arc(Rs @ low, Fe - E) @ Rs
        K = E + RL @ fa
        Fa = K + RL @ cn2
        self._missed(v, leg, (Fa - Fk).length)
        D[f"scap_{s}"] = place(scap_at, Rs, j("scap"))
        D[f"upper_{s}"] = place(S, Rup, j("shoulder"))
        D[f"fore_{s}"] = place(E, RL, j("elbow"))
        D[f"cannon_{s}"] = place(K, RL @ Rk, j("knee"))
        D[f"hoof_{s}"] = place(Fa, Rhoof, j("fetlock"))

    def _hind(self, D, v, leg, s):
        J = self.J
        j = lambda k: J[f"h_{k}_{s}"]  # noqa: E731
        Dh = D["hips"]
        Rh = Dh.to_3x3()
        fwd = Rh @ Y
        T, Rhoof = self._foot(v, leg, j, s, fwd)
        Fk = T - Rhoof @ (j("toe") - j("fetlock"))
        H = Dh @ j("hip")
        th, sh, hc = j("stifle") - j("hip"), j("hock") - j("stifle"), j("fetlock") - j("hock")
        rest_fold = th.angle(sh)
        extra = math.radians(v[f"kf.{leg}"])
        hf = extra
        for _ in range(8):
            Rk = Matrix.Rotation(hf, 3, X)
            low = sh + Rk @ hc
            St, Fe = two_bone(H, Fk, th.length, low.length, fwd)
            RL = arc(Rh @ low, Fe - St) @ Rh
            fold = (St - H).angle(RL @ sh) - rest_fold
            nxt = extra + COUPLE * fold
            if abs(nxt - hf) < 1e-5:
                break
            hf = 0.5 * (hf + nxt)
        Rk = Matrix.Rotation(hf, 3, X)
        low = sh + Rk @ hc
        St, Fe = two_bone(H, Fk, th.length, low.length, fwd)
        Rth = arc(Rh @ th, St - H) @ Rh
        RL = arc(Rh @ low, Fe - St) @ Rh
        Hk = St + RL @ sh
        Fa = Hk + RL @ Rk @ hc
        self._missed(v, leg, (Fa - Fk).length)
        D[f"thigh_{s}"] = place(H, Rth, j("hip"))
        D[f"shin_{s}"] = place(St, RL, j("stifle"))
        D[f"hcannon_{s}"] = place(Hk, RL @ Rk, j("hock"))
        D[f"hhoof_{s}"] = place(Fa, Rhoof, j("fetlock"))

    def _missed(self, v, leg, d):
        self.miss = max(self.miss, d)
        if v[f"fz.{leg}"] <= 1e-6:
            self.plant_miss = max(self.plant_miss, d)

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
    R.miss = R.plant_miss = 0.0
    last = {}
    for f in range(frames + 1):
        R.apply(clip, clip.length * f / frames)
        for pb in rig.pose.bones:
            qq = pb.rotation_quaternion.copy()
            if pb.name in last and last[pb.name].dot(qq) < 0:
                qq.negate()
                pb.rotation_quaternion = qq
            last[pb.name] = qq
            pb.keyframe_insert("rotation_quaternion", frame=f)
            pb.keyframe_insert("location", frame=f)
    for name, ts in clip.beats.items():
        for bt in ts:
            action.pose_markers.new(name).frame = round(bt * FPS)
    action.use_frame_range = True
    action.frame_start, action.frame_end = 0, frames
    rig.animation_data.nla_tracks.new().strips.new(clip.name, 0, action)
    rig.animation_data.action = None
    print(f"ELK_CLIP {clip.name} frames={frames} seconds={clip.length:.3f} loop={clip.loop} "
          f"ground={clip.ground}BL beats={clip.table()['beats']} foot_miss={R.miss:.4f} "
          f"planted_miss={R.plant_miss:.4f}")
    return action


def reset(rig):
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)


# ================================================================== the clips
HEAD_REST = -22.6           # the head's rest angle, poll to nose (deg from level)


def aim(head, neck, pitch=0.0, flex=0.0):
    """The neck at `neck` and the nod that sets the head `head` deg from level
    (- nose down), given the body's pitch and flex."""
    return {"neck": neck, "nod": head - HEAD_REST - pitch + 0.5 * flex - neck}


# Grazing: the muzzle in the grass, the shoulders let down, the near fore
# foot a step ahead.
GP, GF = -8.0, 8.0
GRAZE = {"pitch": GP, "bob": -0.02, "flex": GF, **aim(-82.0, -118.0, GP, GF), "look": 3.0,
         **ears(ear=-12.0), "tail": -6.0,
         **legs("fl", fy=0.08), **legs("fr", fy=-0.025), **legs("hl", fy=0.025), **legs("hr", fy=-0.01)}


def graze():
    """Head down, two tugs at the grass (a push in, then a jerk up and
    aside), a tail flick and an ear flick between them; then a dip, and the
    head comes up a little, chewing, an ear swivelled back to listen
    (graze.lift), and goes back down."""
    G = GRAZE
    return Clip("graze", 3.0, [
        (0.0, dict(G)),
        (0.32, aim(-86.0, -121.0, GP, GF), True),                                       # pushes into the grass
        (0.46, {**aim(-70.0, -108.0, GP, GF), "look": 9.0, "tilt": 7.0, "bob": -0.017}),  # the tug
        (0.72, {**aim(-82.0, -118.0, GP, GF), "look": 4.0, "tilt": 0.0, "bob": -0.02}, True),
        (0.95, {"tsw": 28.0, "tail": 2.0, "et.l": 30.0, "sway": 0.004, "roll": 1.5}),
        (1.12, {"tsw": -8.0, "tail": -6.0, "et.l": 0.0}),
        (1.3, {"tsw": 0.0, **aim(-86.0, -121.0, GP, GF), "look": 1.0}, True),
        (1.44, {**aim(-68.0, -107.0, GP, GF), "look": -7.0, "tilt": -6.0, "bob": -0.017}),
        (1.68, {**aim(-82.0, -118.0, GP, GF), "look": -2.0, "tilt": 0.0, "bob": -0.02, "sway": 0.0,
                "roll": 0.0}, True),
        (1.9, {**aim(-87.0, -122.0, GP, GF), **ears(ear=-16.0)}, True),                 # the dip before the lift
        (2.2, {**aim(-52.0, -76.0, -6.0, 6.0), "pitch": -6.0, "flex": 6.0, "look": 12.0, "bob": -0.015,
               "ear.l": 14.0, "et.r": 40.0, "ear.r": 4.0}, True),                       # graze.lift
        (2.45, {**aim(-48.0, -78.0, -6.0, 6.0), "look": 14.0, "et.r": 34.0}, True),    # chewing, a moving hold
        (2.72, {**aim(-76.0, -108.0, GP, GF), "pitch": GP, "flex": GF, "bob": -0.02, "look": 5.0,
                "ear.l": -10.0, "et.r": 6.0, "ear.r": -12.0}),
    ], loop=True, beats={"graze.lift": [2.2]},
        shots=[0.0, 0.32, 0.46, 0.95, 1.44, 1.9, 2.2, 2.45, 2.72])


def alert():
    """From grazing: the head dips and the body tightens, then the head snaps
    up past its mark and settles there (alert.up), ears pricked, tail up,
    the weight rocked back and the near fore foot lifted, held."""
    G = GRAZE
    up = {"neck": 24.0, "nod": 4.0, "look": 0.0, "pitch": 2.5, "surge": -0.012, "bob": 0.0, "flex": 0.0,
          **ears(ear=42.0, et=-6.0), "tail": 22.0}
    return Clip("alert", 0.6, [
        (0.0, dict(G)),
        (0.07, {**aim(-80.0, -104.0, -10.0, 12.0), "pitch": -10.0, "flex": 12.0, "bob": -0.03,
                **ears(ear=-26.0), "tail": -12.0}, True),                                                    # the tense
        (0.19, {**up, "neck": 28.0, "nod": 6.0, "pitch": 3.5, **legs("fl", fz=0.03, kf=45.0, fp=35.0)}),
        (0.25, {**up, **legs("fl", fy=0.055, fz=0.055, kf=78.0, fp=70.0)}, True),             # alert.up
        (0.36, {"neck": 22.5, "nod": 3.0, "pitch": 2.2}),
        (0.6, {**up, "neck": 23.5}, True),
    ], loop=False, beats={"alert.up": [0.25]}, shots=[0.0, 0.07, 0.13, 0.19, 0.25, 0.36, 0.6])


STOP_HALT = 0.35


def _stop_ground(u):
    """The ground covered by u of stop_look: decelerating evenly to a halt."""
    h = min(u * 1.2 / STOP_HALT, 1.0)
    return 1.0 - (1.0 - h) ** 2


def stop_look():
    """Coming in from a run: the fore feet brace out ahead and skid, the
    hind feet come under and the rump sinks, the head goes up; the halt
    (stop_look.halt) rocks the weight forward once, then the head turns back
    over his left shoulder, the body turning with it, and holds there
    (stop_look.hold), an ear flicking."""
    look = {"look": 140.0, "yaw": 14.0, "roll": -3.0, "neck": 18.0, "nod": 6.0, "tilt": -12.0,
            "pitch": 0.5, "bob": -0.005, "surge": 0.0, "flex": 0.0, **ears(ear=30.0, et=0.0), "tail": 8.0,
            **legs("fl", fy=0.045, fz=0.0, kf=0.0, fp=0.0), **legs("fr", fy=0.02, fx=0.0),
            **legs("hl", fy=0.035, kf=0.0), **legs("hr", fy=0.02, fx=0.015, fz=0.0, kf=0.0, fp=0.0)}
    return Clip("stop_look", 1.2, [
        (0.0, {"pitch": -3.0, "bob": 0.006, "neck": 2.0, "nod": -4.0, **ears(ear=-18.0), "tail": 12.0,
               **legs("fl", fy=0.10, fz=0.045, kf=35.0, fp=30.0), **legs("fr", fy=-0.09),
               **legs("hl", fy=0.08, fz=0.035, kf=10.0, fp=25.0), **legs("hr", fy=-0.08)}),
        (0.12, {"pitch": 8.0, "bob": -0.025, "surge": -0.025, "flex": 6.0, "neck": 20.0, "nod": 8.0,
                **ears(ear=10.0), "tail": 28.0,
                **legs("fl", fy=0.165, fz=0.0, kf=0.0, fp=-10.0), **legs("fr", fy=0.14, fz=0.0, fp=-8.0),
                **legs("hl", fy=0.10, fz=0.0, kf=0.0, fp=0.0), **legs("hr", fy=0.07, fz=0.02, kf=8.0, fp=10.0)}),
        (0.25, {"pitch": 10.0, "bob": -0.055, "surge": -0.04, "flex": 14.0, "neck": 28.0, "nod": 10.0,
                **legs("fl", fy=0.14, fp=-8.0), **legs("fr", fy=0.12, fp=-6.0),
                **legs("hl", fy=0.15), **legs("hr", fy=0.14, fz=0.0, kf=0.0, fp=0.0)}),
        (STOP_HALT, {"pitch": 3.0, "bob": -0.028, "surge": -0.01, "flex": 6.0, "neck": 22.0, "nod": 6.0,
                     **legs("fl", fy=0.08, fp=0.0), **legs("fr", fy=0.06, fp=0.0),
                     **legs("hl", fy=0.08), **legs("hr", fy=0.07)}),
        (0.43, {"pitch": -3.5, "bob": -0.012, "surge": 0.014, "flex": 0.0, "neck": 12.0, "nod": -2.0,
                **ears(ear=18.0), "look": 25.0,
                **legs("fl", fy=0.06), **legs("fr", fy=0.04), **legs("hl", fy=0.045),
                **legs("hr", fy=0.035, fz=0.03, kf=12.0, fp=20.0)}),                 # the rock forward
        (0.6, dict(look), True),                                                  # stop_look.hold
        (0.78, {"look": 144.0, "nod": 8.0, "tilt": -13.0}),
        (0.94, {"et.l": 30.0, "ear.l": 22.0, "tsw": 22.0}),
        (1.06, {"et.l": 0.0, "ear.l": 30.0, "tsw": -6.0}),
        (1.2, {**look, "look": 141.0, "tsw": 0.0}, True),
    ], loop=False, ground=0.5, ground_curve=_stop_ground,
        beats={"stop_look.halt": [STOP_HALT], "stop_look.hold": [0.6]},
        shots=[0.0, 0.12, 0.25, STOP_HALT, 0.43, 0.5, 0.6, 0.94, 1.2])


# ------------------------------------------------------------------ the gaits
def _smooth(e0, e1, x):
    if e1 <= e0:
        return 1.0 if x >= e1 else 0.0
    u = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return u * u * (3 - 2 * u)


def _spline(w, pts, m0=0.0, m1=0.0):
    """A value along keys [(w, value[, hold])] from w 0 to 1, cubic Hermite:
    Catmull-Rom tangents inside (flat at a hold), m0 and m1 at the ends
    (per unit w)."""
    n = len(pts)

    def tan(i):
        if i == 0:
            return m0
        if i == n - 1:
            return m1
        if len(pts[i]) > 2 and pts[i][2]:
            return 0.0
        return (pts[i + 1][1] - pts[i - 1][1]) / (pts[i + 1][0] - pts[i - 1][0])

    i = 0
    while i < n - 2 and w > pts[i + 1][0]:
        i += 1
    w0, a = pts[i][0], pts[i][1]
    w1, b = pts[i + 1][0], pts[i + 1][1]
    h = w1 - w0
    u = min(max((w - w0) / h, 0.0), 1.0)
    h00, h10 = 2 * u ** 3 - 3 * u ** 2 + 1, u ** 3 - 2 * u ** 2 + u
    h01, h11 = -2 * u ** 3 + 3 * u ** 2, u ** 3 - u ** 2
    return h00 * a + h10 * h * tan(i) + h01 * b + h11 * h * tan(i + 1)


class Gait:
    """Each foot's stance and swing in a loop, written over the keyed leg
    channels (a clip's post). A foot down stays put on the ground: in the
    root frame its toe slides back at the clip's own speed (ground * BL /
    length), so the mind moving the node at that speed holds it still. Up,
    the foot lifts (fz), the knee or hock folds (kf), the hoof flips (fp),
    and it swings forward to its next touchdown, drawing back a little
    before it lands (ret), as a runner's foot meets the ground.

    feet {leg: {td, lo: touchdown and liftoff (s); fy: the toe's fy at
    touchdown; roll: fp at liftoff (the hoof rolling over its toe); heel: fp
    at touchdown; ret: the draw-back at each end of the swing, of the
    ground speed; and the swing's shape, keys [(w, value[, hold])] inside
    w 0..1 of the swing for each channel (fy_keys, fz_keys, kf_keys,
    fp_keys), or by default: lift at lift_at (fz), fold at fold_at (kf),
    flip at flip_at (fp), the leg straight and the hoof flat by open}}"""

    def __init__(self, length, ground, feet):
        self.T = length
        self.v = ground * BL / length
        self.feet = feet

    def __call__(self, t, v):
        T = self.T
        for leg, f in self.feet.items():
            d = (f["lo"] - f["td"]) % T
            fy0 = f["fy"]
            fy1 = fy0 - self.v * d
            into = (t - f["td"]) % T
            heel = f.get("heel", 0.0)
            if into <= d:
                s = into / d
                v[f"fy.{leg}"] = fy0 - self.v * into
                v[f"fz.{leg}"] = 0.0
                v[f"fp.{leg}"] = heel * (1 - _smooth(0.0, 0.4, s)) + f["roll"] * _smooth(0.4, 1.0, s)
                v[f"kf.{leg}"] = 0.0
                continue
            D = T - d
            w = (into - d) / D
            m = -f.get("ret", 0.12) * self.v * D
            op = f.get("open", 0.82)
            v[f"fy.{leg}"] = _spline(w, [(0.0, fy1), *f.get("fy_keys", ()), (1.0, fy0)], m, m)
            if "fz_keys" in f:
                k = f["fz_keys"]
                v[f"fz.{leg}"] = max(0.0, _spline(w, [(0.0, 0.0), *k, (1.0, 0.0)],
                                                  1.5 * k[0][1] / k[0][0], -1.5 * k[-1][1] / (1 - k[-1][0])))
            else:
                a = math.log(0.5) / math.log(f["lift_at"])
                v[f"fz.{leg}"] = f["lift"] * math.sin(math.pi * w ** a)
            v[f"kf.{leg}"] = _spline(w, [(0.0, 0.0), *f.get("kf_keys", [(f.get("fold_at", 0.4), f.get("fold", 0.0)),
                                                                        (op, 0.0, True)]), (1.0, 0.0)])
            v[f"fp.{leg}"] = _spline(w, [(0.0, f["roll"]), *f.get("fp_keys", [(f.get("flip_at", 0.3), f.get("flip", 0.0)),
                                                                              (op, 0.0)]), (1.0, heel)])


def _feet(spec, fore, hind):
    """{leg: (td, lo, fy)} with the fore or hind swing's shape."""
    return {leg: {"td": td, "lo": lo, "fy": fy, **(fore if leg[0] == "f" else hind)}
            for leg, (td, lo, fy) in spec.items()}


GAIT_SCAP = 0.5             # the shoulder blade swings more in a stride


def trot():
    """A floating diagonal trot: fl with hr, fr with hl (trot.plant at each
    pair's touchdown), each pair down a little over a quarter of the cycle,
    a hang between. The body dips as a pair takes it and floats in the hang;
    the head carried high and the knees lifted smartly."""
    T = 0.8
    fore = dict(lift=0.10, lift_at=0.38, fold=88.0, fold_at=0.36, flip=80.0, flip_at=0.3, roll=35.0,
                heel=-4.0, open=0.8, ret=0.10)
    hind = dict(lift=0.075, lift_at=0.42, fold=30.0, fold_at=0.38, flip=60.0, flip_at=0.3, roll=30.0,
                open=0.82, ret=0.10)
    g = Gait(T, 2.0, _feet({"fl": (0.0, 0.17, 0.17), "hr": (0.0, 0.17, 0.21),
                            "fr": (0.4, 0.57, 0.17), "hl": (0.4, 0.57, 0.21)}, fore, hind))
    carry = {**aim(-30.0, 10.0), **ears(ear=12.0), "tail": 10.0}
    keys = []
    for half in (0.0, 0.4):
        sg = 1.0 if half == 0.0 else -1.0
        keys += [
            (half + 0.0, {**carry, "bob": -0.016, "pitch": -2.0, "roll": 0.0}),
            (half + 0.085, {"bob": -0.026, "pitch": -2.8, "roll": -1.2 * sg, "yaw": 1.0 * sg}),
            (half + 0.17, {"bob": -0.016, "pitch": -1.7, "roll": 0.0, "yaw": 0.0}),
            (half + 0.285, {"bob": 0.002, "pitch": -1.4}),
        ]
    return Clip("trot", T, keys, loop=True, beats={"trot.plant": [0.0, 0.4]}, ground=2.0, post=g,
                scap=GAIT_SCAP, shots=[0.0, 0.085, 0.17, 0.285, 0.4, 0.485, 0.57, 0.685])


def gallop():
    """A transverse gallop led by the right fore: hl, hr, fl, then fr
    (gallop.plant); off it into the hang with the legs gathered under
    (gallop.air), the back rounded; the hinds land far forward and the back
    opens as they drive, the fores reaching out ahead for the next plant.
    The front dips as the fores take the weight and lifts as they push; the
    head pumps with it."""
    T = 0.55
    # the fores tuck, then reach out ahead and hold it before drawing back to land
    fore = dict(fy_keys=[(0.3, -0.02), (0.72, 0.30, True)], fz_keys=[(0.3, 0.17), (0.72, 0.07)],
                fold=115.0, fold_at=0.32, flip=130.0, flip_at=0.3, roll=55.0, heel=-12.0, open=0.68, ret=0.12)
    hind = dict(fy_keys=[(0.1, -0.25)], lift=0.14, lift_at=0.33, fold=50.0, fold_at=0.36, flip=110.0,
                flip_at=0.32, roll=45.0, open=0.8, ret=0.12)
    g = Gait(T, 4.0, _feet({"hl": (0.375, 0.445, 0.24), "hr": (0.41, 0.48, 0.27),
                            "fl": (0.48, 0.54, 0.19), "fr": (0.05, 0.11, 0.2)}, fore, hind))
    run = {**aim(-18.0, 4.0), **ears(ear=-25.0), "tail": 15.0}
    return Clip("gallop", T, [
        (0.0, {**run, "bob": -0.02, "pitch": -3.0, "flex": -10.0, "neck": -1.0}),
        (0.05, {"bob": -0.026, "pitch": -4.0, "flex": -6.0, "neck": -4.0}),             # gallop.plant
        (0.125, {"bob": -0.008, "pitch": 4.0, "flex": 8.0, "neck": 4.0}),
        (0.25, {"bob": 0.024, "pitch": 2.0, "flex": 22.0, "neck": 10.0}),               # gathered
        (0.35, {"bob": 0.012, "pitch": 0.0, "flex": 24.0, "neck": 6.0}),                # gallop.air
        (0.41, {"bob": -0.008, "pitch": 2.0, "flex": 16.0, "neck": 2.0}),
        (0.465, {"bob": -0.022, "pitch": -2.0, "flex": -6.0, "neck": -2.0}),            # the reach
    ], loop=True, beats={"gallop.plant": [0.05], "gallop.air": [0.35]}, ground=4.0, post=g,
        scap=GAIT_SCAP, shots=[0.0, 0.05, 0.09, 0.125, 0.2, 0.25, 0.35, 0.39, 0.43, 0.47, 0.51])


def sprint():
    """The run beside the plane at cruise: a bound with a long hang. The
    fores land nearly together (sprint.plant), the body vaults over them and
    the back rounds hard to bring the hinds far forward under it (the
    gather), the hinds drive (sprint.push) and he sails off them (sprint.air)
    stretched out, fores reaching and hinds trailing, rising and falling in
    a long hang to the next plant."""
    T = 0.5
    # the fores tuck hard off the plant, then reach far out ahead through the
    # hang; the hinds trail out straight behind off the push, then fold and
    # swing through under the body late in the hang
    fore = dict(fy_keys=[(0.2, -0.12), (0.55, 0.36, True)], fz_keys=[(0.2, 0.18), (0.55, 0.17), (0.85, 0.07)],
                kf_keys=[(0.18, 125.0), (0.5, 0.0, True)], fp_keys=[(0.18, 140.0), (0.5, -5.0), (0.85, -10.0)],
                roll=60.0, heel=-14.0, ret=0.10)
    hind = dict(fy_keys=[(0.15, -0.44), (0.35, -0.42, True), (0.65, -0.02), (0.88, 0.29)],
                fz_keys=[(0.15, 0.10), (0.35, 0.14), (0.62, 0.17), (0.88, 0.05)],
                kf_keys=[(0.15, -5.0), (0.35, 0.0, True), (0.6, 55.0), (0.85, 0.0, True)],
                fp_keys=[(0.15, 75.0), (0.35, 70.0, True), (0.6, 125.0), (0.85, 0.0)], roll=55.0, ret=0.10)
    g = Gait(T, 7.0, _feet({"fl": (0.035, 0.08, 0.25), "fr": (0.05, 0.095, 0.25),
                            "hl": (0.155, 0.205, 0.30), "hr": (0.17, 0.22, 0.30)}, fore, hind))
    run = {**aim(-12.0, -4.0), **ears(ear=-35.0), "tail": 20.0}
    return Clip("sprint", T, [
        (0.0, {**run, "bob": 0.02, "pitch": -3.0, "flex": -14.0, "neck": -4.0}),
        (0.04, {"bob": -0.042, "pitch": -6.0, "flex": -6.0, "neck": -8.0, "surge": 0.0}),     # sprint.plant
        (0.095, {"bob": -0.045, "pitch": 2.0, "flex": 14.0, "neck": -2.0, "surge": -0.02}),
        (0.155, {"bob": -0.04, "pitch": 4.0, "flex": 26.0, "neck": 2.0}),                     # the gather
        (0.2, {"bob": -0.028, "pitch": 8.0, "flex": 10.0, "neck": 8.0, "surge": -0.005}),     # sprint.push
        (0.25, {"bob": 0.02, "pitch": 6.0, "flex": -8.0, "neck": 6.0, "surge": 0.005}),       # sprint.air
        (0.38, {"bob": 0.075, "pitch": 1.0, "flex": -16.0, "neck": 2.0, "surge": 0.01}),     # the top of the hang
        (0.47, {"bob": 0.045, "pitch": -2.0, "flex": -15.0, "neck": 0.0, "surge": 0.004}),
    ], loop=True, beats={"sprint.plant": [0.05], "sprint.push": [0.2], "sprint.air": [0.25]}, ground=7.0,
        post=g, scap=GAIT_SCAP, shots=[0.0, 0.035, 0.065, 0.1, 0.155, 0.2, 0.25, 0.32, 0.38, 0.44])


def clips():
    return [graze(), alert(), stop_look(), trot(), gallop(), sprint()]
