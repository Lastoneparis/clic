# clic-A1 hardware roadmap

From working software to sellable silicon, in de-risked stages. Each stage
produces evidence that unlocks the next round of money and the next partner.

## Stages

| Stage | Deliverable | Proves | Cost order |
|-------|-------------|--------|-----------|
| **S0 — now** | clic stack + verified GEMM/softmax/… on GPU | the software works | done |
| **S1 — FPGA accelerator** | clic-A1 RTL on the ULX3S; measured **perf/watt** | the architecture is real & synthesizable | ~€1k |
| **S2 — open first block** | tiny MAC+ISA core on 130 nm open PDK | the RTL→GDSII flow + bring-up | ~€0.3–2k |
| **S3 — gen-1 tape-out** | [MVP silicon](MVP-SILICON.md) on FD-SOI MPW | **TOPS/W in real silicon**, the ISA | MPW + EDA |
| **S4 — gen-2** | multi-cluster + PCIe + DRAM + NoC accelerator | a sellable product | dedicated run |

## Flow reference
RTL → synthesis → DFT → place & route → timing closure → physical verification
→ GDSII → tape-out. Tools and the FPGA→ASIC conversion checklist:
[ASIC-FLOW.md](ASIC-FLOW.md). Shuttle + process: [MPW-SHUTTLE.md](MPW-SHUTTLE.md).

## Partner & funding map

| Need | Who | When |
|------|-----|------|
| Silicon R&D, physical design, sign-off, MPW, packaging/test | **CEA-Leti** (+ CMP) | S2–S3 |
| Subsidized EDA + MPW access | **Europractice** | S2–S3 |
| Node / fab | **STMicro (28 FD-SOI)** or **GF (22FDX)** | S3+ |
| Non-dilutive funding | Bpifrance / France 2030, **EU EIC**, **Chips JU**, EuroHPC | S1–S4 |
| Dilutive funding | EU deep-tech VCs | S3+ |

See the company-level plan in [../FUNDRAISING.md](../FUNDRAISING.md) and the
pitch in [../../PITCH.md](../../PITCH.md).

## What to take to CEA-Leti

**Ask:** the right engagement vehicle (bilateral vs. a co-applied France 2030 /
EIC / Chips JU grant); MPW access + node (FD-SOI); design enablement (SRAM
compiler, PLL, PHYs) and any NPU/DSP IP; packaging/test; RTL review or co-design;
IP/NDA terms; startup/incubation pathways.

**Provide:** this document set (architecture, ISA, MVP config, flow, shuttle
plan); the open clic repo + verified benchmarks; the **FPGA prototype with
measured perf/watt** (S1); a bounded first-project proposal (S3) with milestones;
team + funding status; and what we own — the clic compiler, ISA, and RTL.

## Honest framing

A first *sellable* product is a **dev-kit / accelerator card** or **licensable
IP**, not a mass-market GPU. Say that plainly — it's what makes the plan
credible. Every figure here is a **target** until S1/S3 measure it.
