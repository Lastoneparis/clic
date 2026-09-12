# clic-A1 — AI Accelerator Architecture v0.1

*Codename `clic-A1` (accelerator, generation 1). Rename freely — you suggested
`OSHI-A1`. This is the silicon target of the open [clic](../../README.md)
compute stack: the software (compiler, runtime, verified AI/hash/graphics
kernels) exists today; this document specifies the hardware it compiles to.*

**Status:** design intent v0.1. All performance figures are **targets/goals to
be validated in RTL and silicon**, not measurements.

---

## 1. Thesis

An **open, efficient inference accelerator** for European sovereign/edge AI.
We do not chase NVIDIA's training flagship; we win on **performance-per-watt**,
openness, and a software stack (clic) that already runs. The chip executes the
**clic ISA** (see [ISA.md](ISA.md)); the clic compiler already emits verified
GEMM, activation, softmax/layernorm and reduction kernels.

## 2. Two generations (be honest about scope)

| | **gen-1 — MVP silicon (first tape-out)** | **gen-2 — product accelerator** |
|---|---|---|
| Goal | prove the compute core + clic ISA + perf/watt in silicon | a sellable inference accelerator |
| Compute | **1 cluster** (systolic INT8/INT4 MAC array) | **8–16 clusters** |
| Datatypes | INT8, INT4 | INT4/8 **+ FP16/BF16** |
| On-chip SRAM | 0.5–1 MB | 8–32 MB |
| Host interface | **SPI / UART** (debug) | **PCIe Gen4 x4/x8** |
| External memory | none (on-chip only) | **LPDDR5 / HBM** controller |
| Control | clic-ISA sequencer (FSM) + optional small RISC-V | **RISC-V** host + FSMs |
| Interconnect | single-cluster bus | **NoC** (mesh) |
| Process | 28/22 nm FD-SOI (or 130 nm open for a first cheap block) | 22/12 nm |
| Power target | ~0.5–2 W | ~10–40 W |

Gen-1 exists to **de-risk**: one cluster, no PCIe, no DRAM, no NoC. Everything
else is gen-2. See [MVP-SILICON.md](MVP-SILICON.md).

## 3. Block diagram (gen-2 target; gen-1 = one cluster + SPI)

```
        ┌────────────────────────── clic-A1 (gen-2) ──────────────────────────┐
        │  Host ─PCIe Gen4─► PCIe controller ─┐                                │
        │  RISC-V control core (RV32IMC) ─────┼──► NoC (mesh) ◄──► LPDDR5 ctrl │
        │                                     │        ▲                       │
        │        ┌──────────────┐  ┌──────────┴───┐   ...  (8–16 clusters)     │
        │        │  Cluster 0   │  │  Cluster 1   │                            │
        │        │ ┌──────────┐ │  │              │   each cluster:            │
        │        │ │ MAC array│ │  │   MAC array  │   - INT8/INT4 systolic PE  │
        │        │ │ 32×32 PE │ │  │              │   - local SRAM (wt/act)    │
        │        │ └────┬─────┘ │  │              │   - accumulators           │
        │        │ local SRAM   │  │  local SRAM  │   - clic-ISA sequencer     │
        │        │ + vector ALU │  │              │   - activation unit        │
        │        └──────────────┘  └──────────────┘                           │
        └──────────────────────────────────────────────────────────────────────┘
```

## 4. Compute architecture

**Processing element (PE): a systolic MAC array.** GEMM is the workload
(every dense layer, every attention block), and clic already drives verified
tiled GEMM. A weight-stationary or output-stationary **systolic array** maps
GEMM directly to hardware with high MAC utilization and local data reuse (the
same reuse the tiled clic kernel exploits with threadgroup memory).

- **gen-1:** one **32×32** array = **1024 INT8 MACs**. At ~500 MHz →
  ~1 TOPS INT8 (2 ops/MAC). INT4 packs 2× → ~2 TOPS. Modest, but real, and
  enough to measure TOPS/W and validate the ISA.
- **gen-2:** 8–16 such clusters → tens of TOPS.

**Vector/activation unit** per cluster: ReLU/GELU/sigmoid (clic stdlib already
implements these), plus softmax/layernorm reductions — fused after GEMM to
avoid memory round-trips (clic's `linear_relu` already does matmul+bias+relu
fused).

## 5. Datatypes

| Type | gen-1 | Use |
|------|:-----:|-----|
| **INT8** | ✅ | primary inference precision |
| **INT4** | ✅ | packed 2×/MAC for quantized models — the efficiency lever |
| **FP16** | gen-2 | mixed-precision / accuracy-sensitive layers |
| **BF16** | gen-2 | training-adjacent / wider dynamic range |

Rationale: INT8/INT4 give the best TOPS/W and cover most quantized inference;
FP16/BF16 add hardware cost (larger MAC), so they're deferred to gen-2. The
clic ISA reserves opcodes for all four (see [ISA.md](ISA.md)) so software is
forward-compatible.

## 6. On-chip memory (SRAM)

The dominant energy cost in inference is **data movement**, not MACs — so
on-chip SRAM and reuse are the architecture.

- **gen-1:** 0.5–1 MB split into **weight buffer**, **activation buffer**, and
  **accumulators**, sized so a tile of GEMM stays on-chip (mirrors clic's
  16×16 threadgroup tiling). SRAM via the foundry **memory compiler** (single-
  and dual-port macros), not FPGA BRAM.
- **gen-2:** 8–32 MB distributed per cluster + a shared L2 over the NoC.

## 7. Memory controller (gen-2)

gen-1 is **on-chip only** (no external DRAM) — deliberately, to avoid the PHY
cost/risk. gen-2 adds an **LPDDR5** controller (edge/low-power) or **HBM** (data-
center), with the controller + PHY as the largest external-IP item.

## 8. Host interface

- **gen-1: SPI/UART** for loading kernels + weights and reading results. Cheap,
  simple, no high-speed PHY. (The clic Python host API already talks to the
  Metal runtime this way; the same manifest model maps to an SPI loader.)
- **gen-2: PCIe Gen4 x4/x8** — a licensed **hard PHY** (do not build from
  scratch); this is a major IP cost and a key CEA-Leti/Europractice discussion.

## 9. Control processor (RISC-V)

- **gen-1:** a **clic-ISA sequencer** (FSM) issues tile/loop commands to the
  array; optionally a minimal **RV32I** core (Ibex / PicoRV32, open-source) for
  flexibility.
- **gen-2:** a **RISC-V RV32IMC** host core schedules kernels across clusters,
  manages DMA, and runs the runtime. RISC-V keeps the whole stack open and
  sovereign (no Arm license).

## 10. Interconnect (NoC)

- **gen-1:** single cluster → a simple bus (AXI-lite for control, wide streaming
  buses for data). **No NoC.**
- **gen-2:** a **mesh NoC** connecting clusters, L2, memory controller and host
  — the standard scalable fabric for many-core accelerators.

## 11. Power & performance targets (goals)

| Metric | gen-1 goal | gen-2 goal |
|--------|-----------|-----------|
| INT8 throughput | ~1–2 TOPS | tens of TOPS |
| Efficiency (INT8) | **measure it** — target 1–5 TOPS/W | 10+ TOPS/W |
| Power | 0.5–2 W | 10–40 W |
| Clock | 400–600 MHz | 1 GHz+ |

FD-SOI **body biasing** is the primary knob for the efficiency target: forward
bias for speed when needed, reverse bias to cut leakage at idle.

## 12. Process target

**FD-SOI**, for perf/watt and European sovereignty:
- **gen-1 prototype:** **28 nm FD-SOI (STMicro, via CMP)** or **22 nm FD-SOI
  (GF 22FDX, via Europractice)**.
- **Optional cheap first block:** **130 nm open PDK (IHP SG13G2)** or SkyWater
  130 nm — proves RTL + flow + a small MAC core only.

See [MPW-SHUTTLE.md](MPW-SHUTTLE.md) for shuttle choice and
[ASIC-FLOW.md](ASIC-FLOW.md) for RTL→GDSII.

## 13. How clic maps to clic-A1

| clic concept | clic-A1 hardware |
|---|---|
| `kernel` grid of threads | tiles streamed through the MAC array |
| `gemm_tiled` (threadgroup memory) | weight/activation SRAM + systolic reuse |
| `linear_relu` (fused) | MAC array → accumulator → activation unit |
| `softmax`/`layernorm` | vector unit + on-chip reduction |
| stdlib activations | activation-unit function table |

The compiler front-end is already separate from the backend, so adding a
**clic-A1 backend** (clic → clic-ISA) reuses everything above the code
generator. That is the bridge from the working software to this silicon.
