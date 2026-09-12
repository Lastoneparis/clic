# OSHI-A1 — Silicon Design Specification v0.1

**A European, open-stack AI-inference accelerator for sovereign LLM serving.**
First target customer profile: **Mistral-class open-weight models**, served
efficiently on European hardware.

Product name **OSHI-A1**; compute stack **[clic](../../README.md)**; architecture
**[clic-A1](ARCHITECTURE.md)**; verified compute core in **[rtl/](../../rtl/)**.

> **Status: v0.1 design point.** Every number below is a *target/estimate*,
> computed by [`tools/spec_calc.py`](../../tools/spec_calc.py) from first-order
> ~12 nm constants — to be refined against a foundry PDK + synthesis. Run the
> calculator to reproduce or retune every figure.

---

## 1. Headline specification

| Parameter | OSHI-A1 v0.1 |
|-----------|--------------|
| **Tensor cores** | **16** (each a 64×64 INT8 systolic MAC tile → 4,096 MACs) |
| **Total INT8 MACs** | 65,536 |
| **SIMD width** | 64 FP16 lanes/core (1,024-bit vector/activation unit) |
| **Datatypes** | INT4, INT8, FP16, BF16 |
| **INT8 throughput** | **131 TOPS** |
| **INT4 throughput** | **262 TOPS** |
| **FP16 / BF16** | **66 TFLOPS** |
| **On-chip SRAM** | **32 MB** (~2 MB per core) |
| **External memory** | LPDDR5X, 256-bit, 8533 MT/s → **273 GB/s** |
| **Host interface** | **PCIe Gen4 ×8** (~15.8 GB/s) |
| **Clock target** | **1.0 GHz** |
| **Card TDP (target)** | **~52 W** |
| **Efficiency (target)** | **4 TOPS/W** INT8 (core) |
| **Est. die area** | **~125 mm²** @ 12 nm FinFET |
| **Process** | 12 nm FinFET (product); 22 nm FD-SOI = lower-cost/sovereign variant |

## 2. Compute architecture

- **16 tensor cores.** Each core is an output-stationary **64×64 systolic MAC
  array** (the [`rtl/systolic.v`](../../rtl/) core, scaled up and verified in
  simulation). GEMM and attention map directly onto it with maximal on-chip
  reuse (the same reuse clic's tiled kernel already exploits).
- **Vector/activation unit** per core: 64 FP16 lanes for ReLU/GELU/softmax/
  layernorm — the clic stdlib ops — fused after the MAC array to avoid memory
  round-trips.
- **Datatypes:** INT8 baseline; **INT4** packs 2×/MAC (the efficiency mode for
  quantized LLMs); **FP16/BF16** at half INT8 rate for accuracy-sensitive layers.

## 3. Memory & cache architecture

- **Scratchpad-managed, not CPU-style caches** — the compiler places data, so
  there are no cache misses on the critical path.
- **Per-core L1:** weight + activation + accumulator buffers (~2 MB/core region
  of the on-chip SRAM).
- **Shared L2:** banked, over the NoC, for weights/KV-cache reuse across cores.
- **External:** **273 GB/s LPDDR5X** (256-bit). LPDDR5X keeps cost/power low; an
  **HBM variant (OSHI-A1H, ~1 TB/s)** is the higher-tier option for large dense
  models.

## 4. Control: RISC-V subsystem + ISA

- **1× RV64GC** management core: runs firmware, schedules kernels, owns the PCIe
  driver interface and DMA orchestration.
- **Per-cluster FSM sequencers** issue the tensor macro-ops.
- **ISA:** the **[clic-A1 ISA](ISA.md)** (tensor macro-ops: `MMA`, `VEC`, `LD/ST`,
  loops) for compute; **RISC-V** for control. Fully open — no Arm license.

## 5. Interconnect (NoC) & DMA

- **Mesh NoC** connecting 16 cores + L2 banks + memory controllers + PCIe +
  RISC-V, sized so compute is not fabric-starved at 273 GB/s.
- **Multi-channel DMA** engines stream weights/activations with double-buffering,
  overlapping data movement with compute (decouples LPDDR latency from the MACs).

## 6. Physical interfaces

PCIe Gen4 ×8 (host) · LPDDR5X PHYs (256-bit) · management: I²C / SPI / UART ·
JTAG (debug + scan) · GPIO · thermal/voltage telemetry.

## 7. Package & PCB

- **Package:** FCBGA, ~35×35 mm, ~1,000+ balls (LPDDR5X + PCIe + power/IO).
- **PCB:** PCIe **HHHL card** (half-height, half-length) for the ~52 W target —
  slot-powered, single-slot, passive or low-profile active cooling. On-board
  LPDDR5X, power regulation, and a management MCU.

## 8. What this means for Mistral-class models

Rough, **memory-bound single-stream decode** estimate (tokens/s ≈ bandwidth ÷
weight bytes; real numbers depend on batching, KV-cache, and quantization):

| Model | Precision | Weights | ~tok/s (batch 1) |
|-------|-----------|---------|------------------|
| Mistral 7B | INT4 | ~3.5 GB | ~78 |
| Mistral 7B | INT8 | ~7 GB | ~39 |
| Mistral Small (~22B) | INT4 | ~11 GB | ~25 |

Batching multiplies aggregate throughput (compute headroom: 131–262 TOPS).
**Honest scope:** OSHI-A1 v0.1 is an **efficient, sovereign inference card for
quantized small/mid open models and edge/single-tenant serving** — *not* an
H100 replacement for 100B-parameter dense models at datacenter scale (that needs
the HBM variant + more silicon). The wedge is *efficiency, cost, and European
sovereignty* on exactly the model sizes Mistral open-weights ship.

## 9. Path to first silicon (de-risked)

OSHI-A1 is the **product**; the [MVP prototype](MVP-SILICON.md) (one core, SPI,
on-chip SRAM, on an FD-SOI MPW) validates the core + ISA + perf/watt *first*.
Flow: [ASIC-FLOW.md](ASIC-FLOW.md) · shuttle/process: [MPW-SHUTTLE.md](MPW-SHUTTLE.md)
· roadmap & partners (CEA-Leti, Europractice/CMP): [HARDWARE-ROADMAP.md](HARDWARE-ROADMAP.md).

## 10. Reproduce / retune these numbers

```bash
python3 tools/spec_calc.py      # edit the knobs at the top to explore
```

Everything in §1 comes out of that model, so the spec stays self-consistent as
the design point moves.
