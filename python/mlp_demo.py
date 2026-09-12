#!/usr/bin/env python3
"""
End-to-end tiny MLP inference on the GPU, driven from Python via clic.

  Y = (relu(X · W1 + b1)) · W2 + b2

Two clic kernels (linear_relu, linear) are compiled and run on the GPU, chained
in Python, and checked against a pure-Python reference. Proves the kernels
COMPOSE into real inference — not just isolated benchmarks.

    python3 python/mlp_demo.py
"""
import random
import clic

random.seed(7)
M, Din, H, Dout = 4, 8, 16, 4          # batch, input, hidden, output


def rnd(n):
    return [random.uniform(-1, 1) for _ in range(n)]


X  = rnd(M * Din)
W1 = rnd(Din * H); b1 = rnd(H)
W2 = rnd(H * Dout); b2 = rnd(Dout)


def gemm_bias(A, W, b, m, k, n, relu):
    out = [0.0] * (m * n)
    for r in range(m):
        for c in range(n):
            acc = b[c]
            for kk in range(k):
                acc += A[r * k + kk] * W[kk * n + c]
            out[r * n + c] = max(0.0, acc) if relu else acc
    return out


# --- layer 1 on the GPU: H1 = relu(X · W1 + b1) ---
h1 = clic.run("examples/linear_relu.clic", "linear_relu",
              grid=[H, M, 1], threadgroup=[min(16, H), min(16, M), 1],
              values={"M": M, "N": H, "K": Din, "A": X, "B": W1, "bias": b1, "C": M * H},
              read=["C"])["C"]

# --- layer 2 on the GPU: Y = H1 · W2 + b2 ---
y = clic.run("examples/linear.clic", "linear",
             grid=[Dout, M, 1], threadgroup=[min(16, Dout), min(16, M), 1],
             values={"M": M, "N": Dout, "K": H, "A": h1, "B": W2, "bias": b2, "C": M * Dout},
             read=["C"])["C"]

# --- reference ---
ref = gemm_bias(gemm_bias(X, W1, b1, M, Din, H, True), W2, b2, M, H, Dout, False)


def close(a, b, tol=1e-3):
    return all(abs(x - z) <= tol * max(1.0, abs(z)) for x, z in zip(a, b))


print("MLP output (GPU):", [round(v, 4) for v in y])
print("MLP output (ref):", [round(v, 4) for v in ref])
print("MATCH — clic kernels compose into real inference"
      if close(y, ref) else "MISMATCH")
