"""The rune knight's rig and clips (imported by rune_knight_build.py).

The rig is the build's JOINT table as bones; every stone piece rides one
bone rigidly (weight 1), so nothing bends and the body can throw pieces
loose later. The clips are key poses in named channels, eased between with
cubic Hermite curves (as art/blender/guacharo/guacharo_clips.py): a key
marked `hold` has flat tangents (an eased stop), the others pass through
with Catmull-Rom tangents. Each key carries the channels of the one
before, so a key lists only what changes. A clip's `extra(t, v)` adds
generated motion (the walk's gait).

The pose is built in armature space (Blender: +z up, +y his front, +x his
right): each bone gets a rigid move D (a turn about its rest joint, then
its parent's move), and the bake turns that into the pose bone's local
basis, R^-1 . Dparent^-1 . D . R. The legs reach their feet by two-bone IK
(knee pole forward), so a foot channel is where the foot is, not how the
leg turns: feet stay planted wherever the clip puts them.

Follow-through is computed, not keyed: the pauldrons and head lag the
hips' bob, the gauntlets trail the arms' swing, the tabard and skirt slabs
swing with the thighs and trail the hips.

Channels (degrees and metres; REST is the model's pose, knees a touch soft):
  bob sway surge            the hips' move (m: up, to his right, forward)
  pitch roll yaw            the hips' turn (+ tip forward, right side down, to his left)
  lean twist side           the spine (+ forward, to his left, top to his right)
  chest chest_twist         the chest over the spine (+ forward, to his left)
  nod look tilt             the head (+ up, to his left, top to his right)
  swing.S out.S bend.S wrist.S shrug.S
                            an arm (+ forward, away from him, elbow more bent,
                            hand up; the pauldron up, m)
  fx.S fy.S fz.S pitch.S yaw.S
                            a foot (m off its rest spot; + toes up, toes to
                            his left). Toes up turns it on its heel, toes
                            down on its toe.

    clips() -> list of Clip; Rig(rig_ob); bake(R, clip) -> Action

Lengths are the stand-in's (scripts/enemies/rune_knight_body_standin.gd
CLIPS): `walk` a step 0.95 s (the clip is the two-step cycle, 1.9 s, a
`plant` per footfall), `turn` a step 0.8 s (1.6 s cycle), `idle` 2.0 s,
`notice` 0.6 s. The walk is in place at the mind's pace (shape(): stride
0.3 h a step), so its planted feet slide back exactly as fast as the mind
carries his root forward.
"""
import math

import bpy
from mathutils import Matrix, Vector

V = Vector
FPS = 30

# Sizes (rune_knight_build.py).
WANDERER_TALL = 1.19
H = WANDERER_TALL * 1.6
STEP = 0.95
SWING_SHARE = 0.62
STRIDE = 0.3 * H
PACE = STRIDE / STEP
TURN_STEP = 0.8
## The sabaton's heel and toe from the ankle (m, along y) and the sole below it.
HEEL = 0.07 * H
TOE = 0.15 * H
SOLE = 0.045 * H
## Follow-through lags (s) and gains.
LAG = 0.09
SHRUG_GAIN = 0.55
HEAD_GAIN = 30.0     # deg per m of bob, the head steadying itself
WRIST_GAIN = 0.45
TABARD_GAIN = 0.75   # of the thigh's swing
TABARD_DROP = 260.0  # deg per m the hips' bob outruns the tabard
SKIRT_GAIN = 0.55

SIDES = ("l", "r")
ARM_CH = {"swing": 0.0, "out": 0.0, "bend": 0.0, "wrist": 0.0, "shrug": 0.0}
FOOT_CH = {"fx": 0.0, "fy": 0.0, "fz": 0.0, "pitch": 0.0, "yaw": 0.0}
REST = {
    "bob": -0.015, "sway": 0.0, "surge": 0.0, "hpitch": 0.0, "roll": 0.0, "yaw": 0.0,
    "lean": 0.0, "twist": 0.0, "side": 0.0, "chest": 0.0, "chest_twist": 0.0,
    "nod": 0.0, "look": 0.0, "tilt": 0.0,
}
for _s in SIDES:
    for _k, _v in {**ARM_CH, **FOOT_CH}.items():
        REST[f"{_k}.{_s}"] = _v


def both(**kw):
    out = {}
    for k, v in kw.items():
        out[f"{k}.l"] = v
        out[f"{k}.r"] = v
    return out


class Clip:
    """keys: [(t, {channel: value}, hold?)]; beats {name: [t, ...]}."""

    def __init__(self, name, length, keys, loop=True, extra=None, beats=None):
        self.name, self.length, self.loop, self.extra = name, length, loop, extra
        self.beats = beats or {}
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

    def raw(self, t):
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

    def values(self, t):
        v = self.raw(t)
        if self.extra:
            self.extra(t % self.length if self.loop else t, v)
        return v

    def lagged(self, t, lag):
        return self.values(t - lag if self.loop else max(t - lag, 0.0))


# ------------------------------------------------------------------ the rig's math
def rx(d): return Matrix.Rotation(math.radians(d), 4, "X")
def ry(d): return Matrix.Rotation(math.radians(d), 4, "Y")
def rz(d): return Matrix.Rotation(math.radians(d), 4, "Z")
def tr(p): return Matrix.Translation(V(p))


def about(j, m):
    """The turn m about joint j."""
    return tr(j) @ m @ tr(-V(j))


def frame(u, pole):
    """Columns: u, the pole made square to it, and their cross."""
    u = u.normalized()
    p = (pole - u * pole.dot(u)).normalized()
    w = u.cross(p)
    return Matrix((u, p, w)).transposed()


class Rig:
    """Bones from rune_knight_build.py's JOINT; the pose as armature-space moves."""

    def __init__(self, rig, joint, arm):
        self.ob = rig
        self.J = {k: V(v) for k, v in joint.items()}
        self.arm = arm
        self.R = {b.name: b.matrix_local.copy() for b in rig.data.bones}
        self.parent = {b.name: (b.parent.name if b.parent else None) for b in rig.data.bones}
        self.order = [b.name for b in rig.data.bones]   # parents come first
        self.L1, self.L2, self.F0 = {}, {}, {}
        for s in SIDES:
            hip, knee, ank = self.J[f"thigh_{s}"], self.J[f"shin_{s}"], self.J[f"foot_{s}"]
            self.L1[s], self.L2[s] = (knee - hip).length, (ank - knee).length
            fwd = V((0, 1, 0))
            self.F0[s] = (frame(knee - hip, fwd), frame(ank - knee, fwd))
        self.reach_max = 0.0

    def _ik(self, s, hip, ank, pole):
        l1, l2 = self.L1[s], self.L2[s]
        d_vec = ank - hip
        d = d_vec.length
        self.reach_max = max(self.reach_max, d / (l1 + l2))
        d = min(max(d, abs(l1 - l2) + 1e-3), (l1 + l2) * 0.9995)
        u = d_vec.normalized()
        a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
        hgt = math.sqrt(max(l1 * l1 - a * a, 0.0))
        p = (pole - u * pole.dot(u)).normalized()
        knee = hip + u * a + p * hgt
        ank = hip + u * d
        return knee, ank

    def moves(self, clip, t):
        """bone -> armature-space move (Matrix 4x4)."""
        v = clip.values(t)
        vl = clip.lagged(t, LAG)
        J = self.J
        D = {"root": Matrix.Identity(4)}
        D["hips"] = tr((v["sway"], v["surge"], v["bob"])) @ about(J["hips"], rz(v["yaw"]) @ ry(v["roll"]) @ rx(-v["hpitch"]))
        D["spine"] = D["hips"] @ about(J["spine"], rz(v["twist"]) @ ry(v["side"]) @ rx(-v["lean"]))
        D["chest"] = D["spine"] @ about(J["chest"], rz(v["chest_twist"]) @ rx(-v["chest"]))
        steady = HEAD_GAIN * (v["bob"] - vl["bob"])
        D["head"] = D["chest"] @ about(J["head"], rz(v["look"]) @ ry(v["tilt"]) @ rx(v["nod"] + steady))
        # The tabard and skirt: with the thighs, trailing the hips' bob.
        drop = TABARD_DROP * (v["bob"] - vl["bob"])
        swing = {}
        for s in SIDES:
            sg = 1.0 if s == "r" else -1.0
            # the arms: the pauldron rides up with the shrug and lags the bob
            shrug = v[f"shrug.{s}"] + SHRUG_GAIN * (vl["bob"] - v["bob"])
            out = sg * -v[f"out.{s}"]
            D[f"shoulder_{s}"] = D["chest"] @ tr((0, 0, shrug)) @ about(J[f"shoulder_{s}"], ry(0.4 * out) @ rx(0.25 * v[f"swing.{s}"]))
            D[f"upper_arm_{s}"] = D["chest"] @ tr((0, 0, 0.5 * shrug)) @ about(J[f"upper_arm_{s}"], rx(v[f"swing.{s}"]) @ ry(out))
            _, sh, el, wr, fdir = self.arm[s]
            hinge = (el - sh).normalized().cross(fdir).normalized()
            D[f"forearm_{s}"] = D[f"upper_arm_{s}"] @ about(el, Matrix.Rotation(math.radians(v[f"bend.{s}"]), 4, hinge))
            trail = WRIST_GAIN * (vl[f"swing.{s}"] - v[f"swing.{s}"])
            D[f"hand_{s}"] = D[f"forearm_{s}"] @ about(wr, Matrix.Rotation(math.radians(v[f"wrist.{s}"] + trail), 4, hinge))
            # the legs: the foot where the channels put it, the leg reaching it
            base = J[f"foot_{s}"] + V((v[f"fx.{s}"], v[f"fy.{s}"], v[f"fz.{s}"]))
            pitch, yaw = v[f"pitch.{s}"], v[f"yaw.{s}"]
            Wf = rz(yaw) @ rx(pitch)
            pivot = base + (rz(yaw) @ V((0, -HEEL if pitch > 0 else TOE, -SOLE)))
            ank = pivot + (Wf @ (base - pivot))
            hip = D["hips"] @ J[f"thigh_{s}"]
            pole = (D["hips"].to_3x3() @ rz(0.5 * yaw).to_3x3() @ V((0.12 * sg, 1, 0))).normalized()
            knee, ank = self._ik(s, hip, ank, pole)
            f_t, f_s = self.F0[s]
            Wt = frame(knee - hip, pole) @ f_t.transposed()
            Ws = frame(ank - knee, pole) @ f_s.transposed()
            D[f"thigh_{s}"] = tr(hip) @ Wt.to_4x4() @ tr(-J[f"thigh_{s}"])
            D[f"shin_{s}"] = tr(knee) @ Ws.to_4x4() @ tr(-J[f"shin_{s}"])
            D[f"foot_{s}"] = tr(ank) @ Wf @ tr(-J[f"foot_{s}"])
            # the thigh's swing in the hips' frame (deg, + forward)
            dk = D["hips"].inverted().to_3x3() @ (knee - hip)
            swing[s] = math.degrees(math.atan2(dk.y, -dk.z)) - math.degrees(math.atan2((J[f"shin_{s}"] - J[f"thigh_{s}"]).y, -(J[f"shin_{s}"] - J[f"thigh_{s}"]).z))
            D[f"skirt_{s}"] = D["hips"] @ about(J[f"skirt_{s}"], rx(SKIRT_GAIN * swing[s] + 0.3 * drop))
        fwd_most = max(swing["l"], swing["r"], 0.0)
        back_most = min(swing["l"], swing["r"], 0.0)
        D["tabard_f"] = D["hips"] @ about(J["tabard_f"], rx(TABARD_GAIN * fwd_most + drop))
        D["tabard_b"] = D["hips"] @ about(J["tabard_b"], rx(TABARD_GAIN * back_most - drop))
        return D

    def basis(self, D):
        """bone -> pose basis (Matrix) from the moves."""
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
    R.reach_max = 0.0
    for f in range(frames + 1):
        t = clip.length * f / frames
        R.apply(clip, t)
        for pb in rig.pose.bones:
            q = pb.rotation_quaternion.copy()
            if pb.name in last and last[pb.name].dot(q) < 0:
                q.negate()
                pb.rotation_quaternion = q
            last[pb.name] = q
            pb.keyframe_insert("rotation_quaternion", frame=f)
            pb.keyframe_insert("location", frame=f)
    for name, ts in clip.beats.items():
        for bt in ts:
            action.pose_markers.new(name).frame = round(bt * FPS)
    action.frame_range = (0, frames)
    rig.animation_data.nla_tracks.new().strips.new(clip.name, 0, action)
    rig.animation_data.action = None
    beats = {k: [round(x, 3) for x in ts] for k, ts in clip.beats.items()}
    print(f"RK_CLIP {clip.name} frames={frames} seconds={clip.length:.3f} loop={clip.loop} beats={beats} "
          f"reach_max={R.reach_max:.3f}")
    return action


def reset(rig):
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)


# ================================================================== the clips
def _bump(x, at, width):
    """A smooth bump 0..1..0 centred on `at`, `width` each side (wraps 0..1)."""
    d = min(abs(x - at), 1 - abs(x - at))
    if d >= width:
        return 0.0
    c = math.cos(math.pi * d / width) * 0.5 + 0.5
    return c


def smooth(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def settle(ph, low, high):
    """The hips over a step (ph 0 at the plant): driven down into the planted
    foot (lowest at 0.1, a hard stop), eased back up by 0.6, then falling,
    faster and faster, into the next plant."""
    x = (ph - 0.1) % 1.0
    if x < 0.5:
        return low + (high - low) * smooth(x / 0.5)
    return high - (high - low) * ((x - 0.5) / 0.5) ** 1.6


def idle():
    """Standing heavy: a slow breath (the chest and pauldrons rise, the arms
    ease out, the fists curl), a held exhale, a little weight on the left."""
    return Clip("idle", 2.0, [
        (0.0, {"bob": -0.018, "lean": 1.0, "nod": -1.0, **both(bend=0.0, out=0.0)}, True),
        (0.85, {"bob": -0.012, "lean": -1.2, "chest": -1.0, "nod": 1.0, "sway": -0.006, "roll": 0.6,
                **both(shrug=0.014, out=2.5, bend=3.0, swing=0.8, wrist=2.0)}, True),
        (1.3, {"bob": -0.016, "lean": 0.4, "chest": -0.3, "nod": 0.0, "sway": -0.004,
               **both(shrug=0.004, out=1.0, bend=1.0, wrist=0.5)}),
    ])


def _walk_gait(t, v):
    cyc = 2 * STEP
    sw = SWING_SHARE * STEP
    stance = cyc - sw
    half = PACE * stance * 0.5
    lift = 0.065 * H
    for s, off in (("l", 0.0), ("r", STEP)):
        tl = (t - off) % cyc
        if tl < stance:
            v[f"fy.{s}"] = half - PACE * tl
            v[f"fz.{s}"] = 0.0
            heel = 11.0 * (1 - smooth(tl / 0.16))           # heel strike, rolled flat
            off_toe = -24.0 * smooth((tl - (stance - 0.3)) / 0.3)   # heel off
            v[f"pitch.{s}"] = heel + off_toe
        else:
            u = (tl - stance) / sw
            e = smooth(u)
            e = e + 0.06 * math.sin(math.pi * e)          # reaches a touch early
            v[f"fy.{s}"] = -half + 2 * half * min(e, 1.0)
            v[f"fz.{s}"] = lift * math.sin(math.pi * min(u ** 0.8, 1.0))
            v[f"pitch.{s}"] = -24.0 * (1 - smooth(u / 0.45)) + 11.0 * smooth((u - 0.4) / 0.6)
    ph = (t % STEP) / STEP                               # 0 at each plant
    # the settle: down hard just after the plant, slowly back up
    v["bob"] = settle(ph, -0.072, -0.03)
    a = 2 * math.pi * t / cyc
    left_support = math.cos(a - 2 * math.pi * 0.655 / cyc)
    v["sway"] = -0.032 * left_support
    v["roll"] = 2.5 * left_support
    v["yaw"] = -5.0 * math.cos(a)
    v["twist"] = 4.0 * math.cos(a)
    v["chest_twist"] = 3.5 * math.cos(a)
    v["side"] = 1.2 * left_support
    v["lean"] = 5.0 + 1.5 * math.cos(2 * a)
    v["hpitch"] = 2.0
    aa = a - 2 * math.pi * 0.12 / cyc                       # the arms trail the legs
    v["swing.l"] = -15.0 * math.cos(aa)
    v["swing.r"] = 15.0 * math.cos(aa)
    for s in SIDES:
        v[f"bend.{s}"] = 6.0 + 9.0 * max(v[f"swing.{s}"], 0.0) / 15.0
        v[f"out.{s}"] = 2.0


def walk():
    """The heavy walk at the mind's pace: heel strike, a hard settle onto the
    planted foot, the sway over it, the hips and chest counter-turning, the
    gauntlets swinging behind the legs."""
    return Clip("walk", 2 * STEP, [(0.0, {"nod": -2.0})], extra=_walk_gait,
                beats={"plant": [0.0, STEP]})


def _turn_gait(t, v):
    cyc = 2 * TURN_STEP
    sw = SWING_SHARE * TURN_STEP
    for s, off in (("l", 0.0), ("r", TURN_STEP)):
        # this foot swings in the last `sw` of the step before its plant
        tl = (t - off) % cyc
        u = (tl - (cyc - sw)) / sw
        if u >= 0:
            v[f"fz.{s}"] = 0.05 * H * math.sin(math.pi * min(u ** 0.85, 1.0))
            v[f"pitch.{s}"] = -14.0 * (1 - smooth(u / 0.5)) + 6.0 * smooth((u - 0.5) / 0.5) * (1 - smooth((u - 0.85) / 0.15))
            v[f"yaw.{s}"] = (1.0 if s == "l" else -1.0) * 9.0 * math.sin(math.pi * u)
    ph = (t % TURN_STEP) / TURN_STEP
    v["bob"] = settle(ph, -0.06, -0.03)
    a = 2 * math.pi * (t - TURN_STEP * 0.6) / cyc
    v["sway"] = 0.03 * math.cos(a)        # over the foot that stands
    v["roll"] = -2.0 * math.cos(a)
    v["side"] = -1.5 * math.cos(a)
    v["lean"] = 4.0
    v["swing.l"] = 4.0 * math.cos(a)
    v["swing.r"] = -4.0 * math.cos(a)
    for s in SIDES:
        v[f"out.{s}"] = 5.0 + 3.0 * abs(math.sin(a))
        v[f"bend.{s}"] = 10.0


def turn():
    """Stepping round in place (the mind turns his root a chunk a step):
    each foot lifts, set down heavily, the weight rocking over the other."""
    return Clip("turn", 2 * TURN_STEP, [(0.0, {})], extra=_turn_gait,
                beats={"plant": [0.0, TURN_STEP]})


def notice():
    """A start: a flinch (head dips, he gathers), then he snaps upright, head
    up, arms flung out, shoulders up; then sinks into a guard, knees bent,
    forearms raised, glaring down at you. The eye lights at the snap (the
    trunk's eye_glow, about 0.1 s)."""
    return Clip("notice", 0.6, [
        (0.0, {}),
        (0.06, {"bob": -0.03, "lean": 4.0, "nod": -6.0, **both(swing=-3.0, bend=4.0)}, True),
        (0.15, {"bob": -0.004, "lean": -8.0, "chest": -4.0, "nod": 13.0,
                **both(swing=16.0, out=20.0, bend=22.0, wrist=-6.0, shrug=0.03)}),
        (0.33, {"bob": -0.075, "lean": 7.0, "chest": 2.0, "nod": -6.0, "hpitch": 3.0,
                **both(swing=20.0, out=13.0, bend=48.0, wrist=12.0, shrug=0.0), "fx.l": -0.0, "fx.r": 0.0}),
        (0.6, {"bob": -0.06, "lean": 5.0, "chest": 1.5, "nod": -3.0, "hpitch": 2.0,
               **both(swing=18.0, out=12.0, bend=44.0, wrist=9.0)}, True),
    ], loop=False, beats={"end": [0.6]})


def clips():
    return [idle(), walk(), turn(), notice()]
