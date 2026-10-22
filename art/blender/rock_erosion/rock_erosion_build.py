"""Bake the eroded-rock relief tile (assets/textures/endless_rock_erosion.png).

Run: python tools/blender.py run art/blender/rock_erosion/rock_erosion_build.py [-- --ledges=0.7 --flutes=2]
(Blender's python carries numpy; this uses nothing else.)

The carve round (docs/design/endless-flight/rock-carve-handoff.md) bakes it
with no ledges (the land carves real ones now; the tile's drew thin lines
across the flutes) and three flute sizes, each in its own patches, so their
spacing and width wander. `--ledges=0.7 --flutes=2` bakes the erosion
round's tile again.

A tileable height field, u across the face and v down it, from three broad
forms only (no fine grain):
  - runnels and flutes: long down the face (v), narrow across (u), ridged so
    the crests are soft-sharp and the troughs round, in patches;
  - ledges and bands: long across (u), short down (v), a few, terraced;
  - rounded bulges: isotropic and low-frequency.
RGB is the tangent-space-style normal (x = -dh/du, y = -dh/dv, z up), A the
height (0 hollow, 1 proud), used for a cavity tint.
"""
import numpy as np, zlib, struct, os, sys

ARGS = dict(a[2:].split("=", 1) for a in sys.argv[sys.argv.index("--") + 1:] if a.startswith("--") and "=" in a) if "--" in sys.argv else {}
LEDGES = float(ARGS.get("ledges", "0"))
FLUTE_SETS = int(ARGS.get("flutes", "3"))

N = 512


def band_noise(fu, fv, seed, sharp=2.0):
    """Periodic noise: smooth blobs, fu cycles across the tile, fv down it."""
    r = np.random.default_rng(seed)
    w = r.standard_normal((N, N))
    F = np.fft.fft2(w)
    ky = np.fft.fftfreq(N) * N
    kx = np.fft.fftfreq(N) * N
    KX, KY = np.meshgrid(kx, ky)
    g = np.exp(-((KX / fu) ** 2 + (KY / fv) ** 2) * sharp)
    out = np.real(np.fft.ifft2(F * g))
    out -= out.mean()
    out /= out.std() + 1e-9
    return out


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


# Runnels: narrow across, long down; ridged so crests sharpen.
flutes = np.clip(1.0 - np.abs(band_noise(8.0, 1.5, 1)), 0, 1) ** 1.3
flutes2 = np.clip(1.0 - np.abs(band_noise(4.0, 1.0, 2)), 0, 1) ** 1.3
patch = smoothstep(-0.4, 0.6, band_noise(2.5, 2.0, 3))
runnel = (flutes * 0.6 + flutes2 * 0.9) * (0.25 + 0.75 * patch)
if FLUTE_SETS >= 3:
    # Each size in its own patches, a third between, so no one spacing runs on.
    flutes3 = np.clip(1.0 - np.abs(band_noise(5.5, 1.2, 21)), 0, 1) ** 1.6
    pa = smoothstep(-0.5, 0.5, band_noise(2.0, 1.5, 22))
    pb = smoothstep(-0.5, 0.5, band_noise(2.0, 1.5, 23))
    runnel = (flutes * 0.7 * pa + flutes2 * 0.9 * (1.0 - pa) + flutes3 * 0.8 * pb) * (0.35 + 0.65 * patch)

# Ledges: a few bands across the face, each with its own height, wandering a
# little down the face; a soft shelf and a lip.
yy = (np.arange(N)[:, None] / N) * np.ones((1, N))
NB = 5
warp = band_noise(2.0, 0.5, 4) * 0.22 + band_noise(6.0, 0.5, 9) * 0.06
sc = yy * NB + warp
terr = np.floor(sc)
frac = sc - terr
rr = np.random.default_rng(11)
ht = rr.random(NB + 8)
hid = ht[(terr.astype(int) + 4) % (NB + 8)] * 0.0
# each band is a ramp tilting back to the next step (an eroded shelf)
ledge = (terr + smoothstep(0.62, 0.9, frac)) / NB * 0.0 + smoothstep(0.62, 0.9, frac) * (0.6 + 0.4 * ht[terr.astype(int) % NB]) \
    - 0.35 * (frac * (1 - frac)) * 0.0

# Bulges: rounded.
bulge = band_noise(2.6, 2.6, 6) * 0.8 + band_noise(5.0, 4.0, 8) * 0.3

h = bulge * 0.7 + ledge * LEDGES + runnel * 0.85
h = (h - h.min()) / (h.max() - h.min())

du = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * N
dv = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * N
depth = 0.075
nx, ny, nz = -du * depth, -dv * depth, np.ones_like(h)
L = np.sqrt(nx * nx + ny * ny + nz * nz)
nx, ny, nz = nx / L, ny / L, nz / L
rgba = np.stack([nx * 0.5 + 0.5, ny * 0.5 + 0.5, nz * 0.5 + 0.5, h], -1)
img = (np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8)


def png(path, a):
    hgt, wid, _ = a.shape
    raw = b"".join(b"\x00" + a[y].tobytes() for y in range(hgt))

    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    data = (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", wid, hgt, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
    open(path, "wb").write(data)


out = os.path.join(os.getcwd(), "assets/textures/endless_rock_erosion.png")
png(out, img)
print("wrote", out, "slope rms", float(np.sqrt((nx ** 2 + ny ** 2).mean())))
