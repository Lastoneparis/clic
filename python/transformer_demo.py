#!/usr/bin/env python3
"""
A tiny transformer forward pass on the GPU, driven from Python via clic.

Pipeline (all clic kernels, chained in Python):
  x -> rmsnorm -> self-attention -> linear_gelu (FFN) -> linear (logits) -> argmax

Every stage runs on the GPU; the result (predicted token per position) is checked
against a pure-Python reference. Proves clic expresses and runs the whole
transformer inner loop — the Mistral-style workload — end to end.

    python3 python/transformer_demo.py
"""
import math
import random
import clic

random.seed(11)
S, D, H, V = 8, 16, 32, 10          # tokens, model dim, FFN dim, vocab
eps = 1e-5
scale = 1.0 / math.sqrt(D)


def rnd(n):
    return [random.uniform(-1, 1) for _ in range(n)]


x   = rnd(S * D)
Wff = rnd(D * H); bff = rnd(H)
Wo  = rnd(H * V); bo  = rnd(V)

# ---------- pure-Python reference ----------
def r_rmsnorm(X):
    y = [0.0] * (S * D)
    for r in range(S):
        ss = sum(X[r*D+j]**2 for j in range(D))
        inv = 1.0 / math.sqrt(ss / D + eps)
        for j in range(D):
            y[r*D+j] = X[r*D+j] * inv
    return y


def r_attention(Q, K, Vv):
    O = [0.0] * (S * D)
    for i in range(S):
        sc = [scale * sum(Q[i*D+d]*K[j*D+d] for d in range(D)) for j in range(S)]
        m = max(sc)
        e = [math.exp(s - m) for s in sc]
        z = sum(e)
        for d in range(D):
            O[i*D+d] = sum(e[j]*Vv[j*D+d] for j in range(S)) / z
    return O


def r_gemm(A, W, b, M, K, N, gelu):
    out = [0.0] * (M * N)
    for r in range(M):
        for c in range(N):
            acc = b[c] + sum(A[r*K+k]*W[k*N+c] for k in range(K))
            if gelu:
                acc = 0.5*acc*(1+math.tanh(0.7978845608*(acc+0.044715*acc**3)))
            out[r*N+c] = acc
    return out


def r_argmax(L, M, N):
    return [max(range(N), key=lambda c: L[r*N+c]) for r in range(M)]


ref_h1  = r_rmsnorm(x)
ref_att = r_attention(ref_h1, ref_h1, ref_h1)
ref_ff  = r_gemm(ref_att, Wff, bff, S, D, H, gelu=True)
ref_lg  = r_gemm(ref_ff, Wo, bo, S, H, V, gelu=False)
ref_tok = r_argmax(ref_lg, S, V)

# ---------- GPU pipeline via clic ----------
h1 = clic.run("examples/nn.clic", "rmsnorm_rows", grid=[S, 1, 1],
              values={"R": S, "C": D, "eps": eps, "x": x, "y": S*D}, read=["y"])["y"]

att = clic.run("examples/attention.clic", "attention", grid=[S, 1, 1],
               values={"S": S, "D": D, "scale": scale, "Q": h1, "K": h1, "V": h1,
                       "O": S*D}, read=["O"])["O"]

ff = clic.run("examples/linear_gelu.clic", "linear_gelu",
              grid=[H, S, 1], threadgroup=[min(16, H), min(16, S), 1],
              values={"M": S, "N": H, "K": D, "A": att, "B": Wff, "bias": bff,
                      "C": S*H}, read=["C"])["C"]

logits = clic.run("examples/linear.clic", "linear",
                  grid=[V, S, 1], threadgroup=[min(16, V), min(16, S), 1],
                  values={"M": S, "N": V, "K": H, "A": ff, "B": Wo, "bias": bo,
                          "C": S*V}, read=["C"])["C"]

tok = clic.run("examples/argmax.clic", "argmax", grid=[S, 1, 1],
               values={"R": S, "C": V, "x": logits, "out": S}, read=["out"])["out"]
tok = [int(t) for t in tok]

# ---------- check ----------
print("predicted tokens (GPU):", tok)
print("predicted tokens (ref):", ref_tok)
logits_ok = all(abs(a - b) <= 1e-3*max(1.0, abs(b)) for a, b in zip(logits, ref_lg))
print("MATCH — clic runs a transformer forward pass end to end"
      if tok == ref_tok and logits_ok else "MISMATCH")
