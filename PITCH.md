# clic — European open compute for AI

> An open, vendor-neutral compute stack and an efficient European accelerator
> for AI **inference** — built to break the CUDA/NVIDIA lock-in that leaves the
> EU without sovereign AI compute.

*One-pager · pre-seed · working name · Sept 2026*

## The problem
Almost all AI compute in Europe runs on one US vendor's chips and one
proprietary stack (CUDA). That is a sovereignty, cost, and energy problem at
once — and inference (running models), not training, is now the dominant bill.

## Why now
The EU Chips Act and the compute-sovereignty agenda **explicitly** target
fabless chip design and "AI chips and systems for EU compute infrastructure,"
with billions in public/private capital behind it. A *European fabless AI
accelerator* is fundable in a way a "national graphics card" never was.

## The insight
You don't beat CUDA on the flagship training GPU — no one does by building a
chip. You win where its lock-in and power draw are liabilities: **open,
efficient inference, on hardware Europe controls.** The software is the moat.

## The product — one language, many backends
**clic** keeps CUDA's grid-of-threads model and drops the lock-in. The same
kernel targets a GPU today, an FPGA over USB next, and custom silicon after — so
the software is ready before the chip is.

## Proof — it already works (open-source, CI-tested)
Measured on an Apple M3 Pro GPU, verified:

| Workload | Result | Verified against |
|---|---|---|
| AI — tiled matmul (`gemm_tiled`) | **872 GFLOP/s** | CPU reference |
| AI — fused dense layer (`relu(A·B+bias)`) | 505 GFLOP/s | CPU reference |
| Hash — SHA-256 (1M nonces) | **836 MH/s** | Apple CryptoKit |
| Graphics — shaded 3D rasterizer | ~3,200 fps | rendered output |

Absolute numbers are bounded by the test GPU; the point is a **complete,
correct, portable** stack across AI + hash + graphics, ready to retarget to our
own hardware. → https://github.com/Lastoneparis/clic

## The plan (de-risking milestones)
Stack + FPGA prototype (now) → first taped-out silicon via a shuttle (Phase 1)
→ accelerator IP + design partners (Phase 2) → production inference silicon
(Phase 3).

## Team — in formation (stated honestly)
Founder: **Hugo Moriceau** — built the language, compiler, runtime, demos.
**Recruiting the critical hire:** a senior ASIC/accelerator architect
(ex-STMicro / Kalray / SiPearl / Arm or equivalent). Advisory board forming.

## The ask
A staged **pre-seed of €500k–€1M** (illustrative) to reach a fundable seed:
FPGA accelerator + perf-per-watt, first silicon, one design-partner LOI, and the
silicon co-founder — over 12–18 months. Stacked with non-dilutive EU funding
(Bpifrance, EIC Accelerator, Chips JU/EuroHPC).

**Contact:** Hugo Moriceau · hugomoriceau@icloud.com
