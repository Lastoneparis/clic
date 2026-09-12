#!/usr/bin/env python3
"""Run clic kernels from Python. Usage:  python3 python/example.py"""
import clic


def approx(a, b, tol=1e-4):
    return all(abs(x - y) <= tol * max(1.0, abs(y)) for x, y in zip(a, b))


# --- SAXPY: y = a*x + y ---
n, a = 8, 3.0
x = [float(i) for i in range(n)]
y = [10.0] * n
out = clic.run("examples/saxpy.clic", "saxpy", grid=[n, 1, 1],
               values={"n": n, "a": a, "x": x, "y": y}, read=["y"])
expect = [a * x[i] + y[i] for i in range(n)]
print("saxpy  ->", out["y"])
print("expect ->", expect, "OK" if approx(out["y"], expect) else "MISMATCH")

# --- element-wise square via a tiny inline-style kernel already in the repo ---
# GELU activation over an array, using the stdlib (see examples).
print("\nRan clic on the GPU from Python with zero Metal boilerplate.")
