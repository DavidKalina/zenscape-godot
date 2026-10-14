"""The few mathutils types headless_body_build.py's posing uses (Vector,
Matrix, Quaternion), in plain Python, so bake_clips.py can run its clips
without Blender. Same conventions as Blender's: Quaternion (w, x, y, z),
Matrix rows, column vectors (M @ v), 4x4 translation in the last column."""
import math


class Vector:
    __slots__ = ("v",)

    def __init__(self, seq=(0.0, 0.0, 0.0)):
        self.v = [float(a) for a in seq]

    x = property(lambda s: s.v[0], lambda s, a: s.v.__setitem__(0, float(a)))
    y = property(lambda s: s.v[1], lambda s, a: s.v.__setitem__(1, float(a)))
    z = property(lambda s: s.v[2], lambda s, a: s.v.__setitem__(2, float(a)))

    def __len__(self): return len(self.v)
    def __getitem__(self, i): return self.v[i]
    def __setitem__(self, i, a): self.v[i] = float(a)
    def __iter__(self): return iter(self.v)
    def __repr__(self): return "Vector(%s)" % ", ".join("%.5f" % a for a in self.v)
    def __add__(self, o): return Vector([a + b for a, b in zip(self.v, o)])
    def __sub__(self, o): return Vector([a - b for a, b in zip(self.v, o)])
    def __neg__(self): return Vector([-a for a in self.v])
    def __mul__(self, k): return Vector([a * k for a in self.v])
    __rmul__ = __mul__
    def __truediv__(self, k): return Vector([a / k for a in self.v])
    def copy(self): return Vector(self.v)
    def dot(self, o): return sum(a * b for a, b in zip(self.v, o))

    def cross(self, o):
        a, b = self.v, list(o)
        return Vector((a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]))

    @property
    def length(self): return math.sqrt(sum(a * a for a in self.v))

    def normalized(self):
        n = self.length
        return Vector(self.v) if n < 1e-12 else self / n

    def normalize(self):
        n = self.length
        if n > 1e-12: self.v = [a / n for a in self.v]

    def lerp(self, o, t): return Vector([a + (b - a) * t for a, b in zip(self.v, o)])


class Matrix:
    __slots__ = ("m",)

    def __init__(self, rows):
        self.m = [[float(a) for a in r] for r in rows]

    @staticmethod
    def Identity(n): return Matrix([[1.0 if i == j else 0.0 for j in range(n)] for i in range(n)])

    @staticmethod
    def Translation(v):
        m = Matrix.Identity(4)
        m.translation = v
        return m

    def __repr__(self): return "Matrix(%s)" % self.m
    def copy(self): return Matrix(self.m)
    def transposed(self): return Matrix([list(c) for c in zip(*self.m)])

    def to_4x4(self):
        n = len(self.m)
        out = Matrix.Identity(4)
        for i in range(min(n, 4)):
            for j in range(min(n, 4)):
                out.m[i][j] = self.m[i][j]
        return out

    def to_3x3(self): return Matrix([r[:3] for r in self.m[:3]])

    @property
    def translation(self): return Vector((self.m[0][3], self.m[1][3], self.m[2][3]))

    @translation.setter
    def translation(self, v):
        for i in range(3): self.m[i][3] = float(v[i])

    def __matmul__(self, o):
        n = len(self.m)
        if isinstance(o, Matrix):
            return Matrix([[sum(self.m[i][k] * o.m[k][j] for k in range(n)) for j in range(n)] for i in range(n)])
        v = list(o)
        if n == 4 and len(v) == 3:
            return Vector([sum(self.m[i][k] * v[k] for k in range(3)) + self.m[i][3] for i in range(3)])
        return Vector([sum(self.m[i][k] * v[k] for k in range(n)) for i in range(n)])

    def inverted(self):
        n = len(self.m)
        a = [r[:] + [1.0 if i == j else 0.0 for j in range(n)] for i, r in enumerate(self.m)]
        for c in range(n):
            p = max(range(c, n), key=lambda r: abs(a[r][c]))
            a[c], a[p] = a[p], a[c]
            d = a[c][c]
            a[c] = [x / d for x in a[c]]
            for r in range(n):
                if r != c and a[r][c] != 0.0:
                    f = a[r][c]
                    a[r] = [x - f * y for x, y in zip(a[r], a[c])]
        return Matrix([r[n:] for r in a])

    def to_quaternion(self):
        m = self.to_3x3().m
        # Normalize the columns (a scaled basis).
        cols = [Vector((m[0][j], m[1][j], m[2][j])).normalized() for j in range(3)]
        m = [[cols[j][i] for j in range(3)] for i in range(3)]
        tr = m[0][0] + m[1][1] + m[2][2]
        if tr > 0:
            s = math.sqrt(tr + 1.0) * 2
            w, x, y, z = 0.25 * s, (m[2][1] - m[1][2]) / s, (m[0][2] - m[2][0]) / s, (m[1][0] - m[0][1]) / s
        elif m[0][0] > m[1][1] and m[0][0] > m[2][2]:
            s = math.sqrt(1.0 + m[0][0] - m[1][1] - m[2][2]) * 2
            w, x, y, z = (m[2][1] - m[1][2]) / s, 0.25 * s, (m[0][1] + m[1][0]) / s, (m[0][2] + m[2][0]) / s
        elif m[1][1] > m[2][2]:
            s = math.sqrt(1.0 + m[1][1] - m[0][0] - m[2][2]) * 2
            w, x, y, z = (m[0][2] - m[2][0]) / s, (m[0][1] + m[1][0]) / s, 0.25 * s, (m[1][2] + m[2][1]) / s
        else:
            s = math.sqrt(1.0 + m[2][2] - m[0][0] - m[1][1]) * 2
            w, x, y, z = (m[1][0] - m[0][1]) / s, (m[0][2] + m[2][0]) / s, (m[1][2] + m[2][1]) / s, 0.25 * s
        q = Quaternion((w, x, y, z))
        q.normalize()
        return q

    def decompose(self):
        m = self.m
        scale = Vector([Vector((m[0][j], m[1][j], m[2][j])).length for j in range(3)])
        return self.translation, self.to_quaternion(), scale


class Quaternion:
    __slots__ = ("q",)

    def __init__(self, a=None, angle=None):
        if a is None: self.q = [1.0, 0.0, 0.0, 0.0]
        elif angle is None: self.q = [float(c) for c in a]
        else:
            ax = Vector(a).normalized()
            s = math.sin(angle * 0.5)
            self.q = [math.cos(angle * 0.5), ax.x * s, ax.y * s, ax.z * s]

    w = property(lambda s: s.q[0])
    x = property(lambda s: s.q[1])
    y = property(lambda s: s.q[2])
    z = property(lambda s: s.q[3])

    def __repr__(self): return "Quaternion(%s)" % ", ".join("%.5f" % a for a in self.q)
    def __iter__(self): return iter(self.q)
    def copy(self): return Quaternion(self.q)
    def dot(self, o): return sum(a * b for a, b in zip(self.q, o.q))
    def negate(self): self.q = [-a for a in self.q]

    def normalize(self):
        n = math.sqrt(sum(a * a for a in self.q))
        self.q = [a / n for a in self.q]

    def __matmul__(self, o):
        w1, x1, y1, z1 = self.q
        w2, x2, y2, z2 = o.q
        return Quaternion((w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2,
                           w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2,
                           w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
                           w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2))

    def to_matrix(self):
        w, x, y, z = self.q
        return Matrix([
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ])

    def slerp(self, o, t):
        a, b = self.q, list(o.q)
        d = sum(p * q for p, q in zip(a, b))
        if d < 0: b, d = [-c for c in b], -d
        if d > 0.9995:
            r = Quaternion([p + (q - p) * t for p, q in zip(a, b)])
            r.normalize()
            return r
        th = math.acos(min(1.0, d))
        s = math.sin(th)
        ka, kb = math.sin((1 - t) * th) / s, math.sin(t * th) / s
        return Quaternion([p * ka + q * kb for p, q in zip(a, b)])
