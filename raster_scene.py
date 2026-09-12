#!/usr/bin/env python3
"""
raster_scene.py — the "vertex stage" for the clic rasterizer.

Builds a rotated, perspective-projected, Lambert-shaded cube and writes a run
manifest (a depth-sorted triangle list) for examples/raster.clic to render.
This is the CPU-side geometry step; clic does the per-pixel work.

  python3 raster_scene.py                          # -> runs/raster.json, 512px
  python3 raster_scene.py --ay 1.2 --size 360 \
        --json runs/_anim.json --out /abs/f01.png  # one animation frame
"""
import argparse
import json
import math

ap = argparse.ArgumentParser()
ap.add_argument("--ay", type=float, default=-0.72, help="Y rotation (radians)")
ap.add_argument("--ax", type=float, default=0.62, help="X rotation (radians)")
ap.add_argument("--size", type=int, default=512)
ap.add_argument("--json", default="runs/raster.json")
ap.add_argument("--out", default="../build/raster.png",
                help="image path written into the manifest (abs or rel to it)")
args = ap.parse_args()

W = H = args.size
AX, AY = args.ax, args.ay
L = (0.35, 0.55, -0.75)
_ln = math.sqrt(sum(c * c for c in L))
L = tuple(c / _ln for c in L)

V = [(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1),
     (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]
FACES = [([0, 1, 2, 3], (0.93, 0.26, 0.33)),
         ([4, 5, 6, 7], (0.24, 0.72, 0.96)),
         ([0, 1, 5, 4], (0.32, 0.83, 0.47)),
         ([3, 2, 6, 7], (0.97, 0.79, 0.29)),
         ([1, 2, 6, 5], (0.73, 0.43, 0.93)),
         ([0, 3, 7, 4], (0.97, 0.56, 0.29))]


def rot(p):
    x, y, z = p
    x, z = x * math.cos(AY) + z * math.sin(AY), -x * math.sin(AY) + z * math.cos(AY)
    y, z = y * math.cos(AX) - z * math.sin(AX), y * math.sin(AX) + z * math.cos(AX)
    return (x, y, z)


def project(rp):
    x, y, z = rp
    zc = z + 4.0
    f, s = 2.4, W * 0.42
    return (W * 0.5 + x * f / zc * s, H * 0.5 - y * f / zc * s)


def normal(a, b, c):
    ux, uy, uz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
    vx, vy, vz = c[0] - a[0], c[1] - a[1], c[2] - a[2]
    nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    nl = math.sqrt(nx * nx + ny * ny + nz * nz) + 1e-9
    return (nx / nl, ny / nl, nz / nl)


R = [rot(v) for v in V]
tris = []
for face, col in FACES:
    q = [R[i] for i in face]
    for i0, i1, i2 in [(0, 1, 2), (0, 2, 3)]:
        a, b, c = q[i0], q[i1], q[i2]
        n = normal(a, b, c)
        lam = abs(n[0] * L[0] + n[1] * L[1] + n[2] * L[2])
        bright = 0.25 + 0.75 * lam
        pa, pb, pc = project(a), project(b), project(c)
        avgz = (a[2] + b[2] + c[2]) / 3.0
        rgb = [min(1.0, col[k] * bright) for k in range(3)]
        tris.append((avgz, [pa[0], pa[1], pb[0], pb[1], pc[0], pc[1]] + rgb))

tris.sort(key=lambda t: -t[0])
flat = [round(v, 4) for _, t in tris for v in t]

manifest = {
    "kernel": "raster",
    "metal": "../build/raster.metal",
    "grid": [W, H, 1],
    "threadgroup": [16, 16, 1],
    "iters": 30,
    "image": {"buffer": "img", "width": W, "height": H, "path": args.out},
    "bindings": [
        {"name": "W", "kind": "scalar", "type": "i32", "value": W},
        {"name": "H", "kind": "scalar", "type": "i32", "value": H},
        {"name": "ntri", "kind": "scalar", "type": "i32", "value": len(tris)},
        {"name": "tris", "kind": "buffer", "type": "f32", "len": len(flat), "data": flat},
        {"name": "img", "kind": "buffer", "type": "u32", "len": W * H, "init": "zero"},
    ],
}
with open(args.json, "w") as fp:
    json.dump(manifest, fp, indent=2)
print("wrote %s  (%d triangles, %dx%d)" % (args.json, len(tris), W, H))
