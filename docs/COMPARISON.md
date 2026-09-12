# clic vs CUDA — an honest comparison

Where clic stands against CUDA today, without spin. Overclaiming loses the
technical audience we need; this page is deliberately fair.

| Dimension | CUDA | clic |
|-----------|------|------|
| **Vendor** | NVIDIA GPUs only | vendor-neutral — Apple Metal today; FPGA / custom silicon next |
| **License** | proprietary | open source (MIT) |
| **Programming model** | grid / block / thread (manual block math) | grid of threads — `tid.x`, no block bookkeeping |
| **Ecosystem** | massive: cuBLAS, cuDNN, CUTLASS, 15 yrs of libraries | small: activations, GEMM (tiled), reductions, softmax/layernorm, SHA-256 |
| **Backends** | NVIDIA CUDA GPUs | Metal (working); FPGA (ECP5) + ASIC (in progress) |
| **Absolute performance** | world-class on NVIDIA hardware | bounded by the target device — **not faster** |
| **Toolchain** | large SDK | a single-file compiler (`clicc.py`) + a small Swift runtime |
| **Host API** | C / C++ / Python | Python, a few lines (`clic.run(...)`) |
| **Path to your own silicon** | none — you rent the chip | open ISA + verified RTL toward your own accelerator |
| **Maturity** | 15+ years, production | early prototype |

## The honest verdict

**clic is not a drop-in CUDA replacement, and not faster.** Speed comes from
silicon; CUDA on an NVIDIA GPU will out-run clic on any hardware clic runs on
today. CUDA's ecosystem is a 15-year moat clic will not out-feature.

**What clic offers instead:**
- **Openness & portability** — one language, many backends, MIT-licensed.
- **Ergonomics** — the good part of CUDA's model without the sharp edges.
- **A path to hardware you control** — the same kernels target an FPGA and,
  ultimately, a sovereign European accelerator ([OSHI-A1](hardware/SILICON-SPEC.md)).

## When to use which

- **Use CUDA** if you need maximum performance and the mature library ecosystem
  on NVIDIA hardware, now.
- **Use / follow clic** if you need openness, portability off NVIDIA, clean
  kernels, or a route to efficient, sovereign, non-NVIDIA silicon.

clic competes on the axes where CUDA's lock-in and power draw are liabilities —
not on a head-to-head benchmark it would lose.
