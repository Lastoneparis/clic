# Minimum viable silicon (clic-A1 gen-1)

The smallest chip that proves the thesis. Everything not on this list is
**deliberately deferred** to gen-2 — first tape-out must be cheap and low-risk.

## In gen-1 (the first tape-out)

| Block | Spec | Why it's in |
|-------|------|-------------|
| **1 compute cluster** | 32×32 INT8 systolic MAC array (1024 MACs), INT4 packed mode | proves the core + the perf/watt number |
| **On-chip SRAM** | 0.5–1 MB (weight + activation + accumulators) | proves the reuse/dataflow works |
| **clic-ISA sequencer** | FSM issuing `SET/LD/MMA/VEC/ST` | proves the ISA in silicon |
| **Activation unit** | ReLU / GELU (fused after MMA) | proves fused ops (clic `linear_relu`) |
| **Host interface** | SPI or UART loader | load weights/kernels, read results — no high-speed PHY |
| **Clocking** | 1 PLL, single clock domain | keep timing/CTS simple |
| **DFT** | scan chains + memory BIST | you cannot debug silicon without it |

**Target:** load an INT8 GEMM + ReLU, run it, read the result back, and
**measure TOPS/W** vs the FPGA and a CPU/GPU baseline. That number is the whole
point of gen-1.

## Deferred to gen-2 (NOT in the first tape-out)

- ❌ PCIe (needs a licensed hard PHY — big cost/risk)
- ❌ external DRAM / LPDDR5 / HBM controller + PHY
- ❌ multiple clusters + NoC
- ❌ FP16 / BF16 datapaths (INT8/INT4 only in gen-1)
- ❌ RISC-V host (an FSM sequencer suffices; add RV32I only if area allows)

## Rough gen-1 budget (order-of-magnitude, to refine with the shuttle)

| Item | Note |
|------|------|
| Silicon area | small — one cluster + ~1 MB SRAM fits a modest MPW tile |
| Process | 28/22 nm FD-SOI (or 130 nm open for a pre-prototype) |
| Package | QFN or a simple BGA from the shuttle's packaging service |
| Bring-up board | a small PCB with the chip + an MCU/FPGA speaking SPI |

## Validation plan

1. **Pre-silicon:** RTL simulation of `MMA`/`VEC` against the clic CPU reference
   (reuse the same vectors clicrun already checks GEMM/softmax against).
2. **FPGA:** map the same RTL to the ULX3S — same design, real perf/watt on the
   FPGA (this is also the CEA-Leti credibility artifact).
3. **Silicon bring-up:** SPI-load a known GEMM, compare output to the reference,
   sweep voltage/frequency (and FD-SOI body bias) to plot the TOPS/W curve.

## Why this is the right MVP

A first tape-out with PCIe + DRAM + NoC + multi-cluster is how startups burn a
year and a run on integration bugs. One cluster + SPI + on-chip SRAM proves the
**architecture and the ISA** — the parts that are genuinely novel — and produces
the one number investors and partners actually want: **efficiency in silicon.**
