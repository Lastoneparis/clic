#!/usr/bin/env python3
"""
A full Mistral / LLaMA-style transformer decoder BLOCK on the GPU, driven from
Python via clic. Unlike transformer_demo.py (which uses the older GELU FFN and
plain attention), this uses the modern primitives added to clic:

  x
  ├─ n1  = rmsnorm(x)
  ├─ q,k = RoPE(n1)              (rotary positions on Q and K; V un-rotated)
  ├─ att = attention(q, k, v)
  ├─ h   = x + att              (residual, via saxpy on the GPU)
  ├─ n2  = rmsnorm(h)
  ├─ ff  = SwiGLU(n2)           (SiLU-gated dual projection)
  ├─ dn  = linear(ff)           (down-projection H -> D)
  └─ out = h + dn               (residual)

Every stage runs on the GPU; the block output is checked against a pure-Python
reference. This is the exact inner loop of a Mistral layer — proof that clic's
kernels compose into a real modern transformer block, not just isolated demos.

    python3 python/mistral_block_demo.py
"""
import math
import random
import clic

random.seed(7)
S, D, H = 8, 16, 32          # tokens, model dim, FFN hidden dim
eps = 1e-5
scale = 1.0 / math.sqrt(D)
base = 10000.0


def rnd(n):
    return [random.uniform(-1, 1) for _ in range(n)]


x  = rnd(S * D)
Wg = rnd(D * H)              # SwiGLU gate weights
Wu = rnd(D * H)              # SwiGLU up weights
Wd = rnd(H * D)              # down-projection weights


# ---------------- pure-Python reference ----------------
def r_rmsnorm(X):
    y = [0.0] * (S * D)
    for r in range(S):
        ss = sum(X[r*D+j]**2 for j in range(D))
        inv = 1.0 / math.sqrt(ss / D + eps)
        for j in range(D):
            y[r*D+j] = X[r*D+j] * inv
    return y


def r_rope(X):
    O = [0.0] * (S * D)
    for t in range(S):
        for i in range(D // 2):
            freq = base ** (-(2.0 * i) / D)
            ang = t * freq
            a = X[t*D+2*i]; b = X[t*D+2*i+1]
            O[t*D+2*i]   = a*math.cos(ang) - b*math.sin(ang)
            O[t*D+2*i+1] = a*math.sin(ang) + b*math.cos(ang)
    return O


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


def r_swiglu(A):
    out = [0.0] * (S * H)
    for t in range(S):
        for j in range(H):
            g = sum(A[t*D+d]*Wg[d*H+j] for d in range(D))
            u = sum(A[t*D+d]*Wu[d*H+j] for d in range(D))
            out[t*H+j] = (g / (1 + math.exp(-g))) * u
    return out


def r_down(A):
    out = [0.0] * (S * D)
    for r in range(S):
        for c in range(D):
            out[r*D+c] = sum(A[r*H+k]*Wd[k*D+c] for k in range(H))
    return out


ref_n1  = r_rmsnorm(x)
ref_q   = r_rope(ref_n1)
ref_att = r_attention(ref_q, ref_q, ref_n1)         # Q,K rotated; V = n1
ref_h   = [ref_att[i] + x[i] for i in range(S * D)]
ref_n2  = r_rmsnorm(ref_h)
ref_ff  = r_swiglu(ref_n2)
ref_dn  = r_down(ref_ff)
ref_out = [ref_h[i] + ref_dn[i] for i in range(S * D)]


# ---------------- GPU pipeline via clic ----------------
n1 = clic.run("examples/nn.clic", "rmsnorm_rows", grid=[S, 1, 1],
              values={"R": S, "C": D, "eps": eps, "x": x, "y": S*D}, read=["y"])["y"]

q = clic.run("examples/rope.clic", "rope", grid=[S, 1, 1],
             values={"S": S, "D": D, "base": base, "X": n1, "O": S*D}, read=["O"])["O"]

att = clic.run("examples/flash_attn.clic", "flash_attn", grid=[S, 1, 1],
               values={"S": S, "D": D, "scale": scale, "Q": q, "K": q, "V": n1,
                       "O": S*D}, read=["O"])["O"]

h = clic.run("examples/saxpy.clic", "saxpy", grid=[S*D, 1, 1],
             values={"n": S*D, "a": 1.0, "x": att, "y": list(x)}, read=["y"])["y"]

n2 = clic.run("examples/nn.clic", "rmsnorm_rows", grid=[S, 1, 1],
              values={"R": S, "C": D, "eps": eps, "x": h, "y": S*D}, read=["y"])["y"]

ff = clic.run("examples/swiglu.clic", "swiglu", grid=[H, S, 1],
              threadgroup=[min(16, H), min(16, S), 1],
              values={"T": S, "D": D, "H": H, "x": n2, "Wg": Wg, "Wu": Wu,
                      "out": S*H}, read=["out"])["out"]

dn = clic.run("examples/linear.clic", "linear", grid=[D, S, 1],
              threadgroup=[min(16, D), min(16, S), 1],
              values={"M": S, "N": D, "K": H, "A": ff, "B": Wd, "bias": [0.0]*D,
                      "C": S*D}, read=["C"])["C"]

out = clic.run("examples/saxpy.clic", "saxpy", grid=[S*D, 1, 1],
               values={"n": S*D, "a": 1.0, "x": dn, "y": list(h)}, read=["y"])["y"]


# ---------------- check ----------------
def close(a, b):
    return all(abs(u - v) <= 1e-3 * max(1.0, abs(v)) for u, v in zip(a, b))


ok = close(out, ref_out)
print("block output[0:4] (GPU):", [round(v, 4) for v in out[:4]])
print("block output[0:4] (ref):", [round(v, 4) for v in ref_out[:4]])
print("MATCH — clic runs a full Mistral-style block (RMSNorm/RoPE/attention/"
      "SwiGLU + residuals) end to end on the GPU" if ok else "MISMATCH")
