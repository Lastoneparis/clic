# FPGA → ASIC: the flow to GDSII and tape-out

How the clic-A1 RTL becomes a chip, and what has to change moving off the FPGA.

## 0. FPGA RTL ≠ ASIC RTL — the conversion checklist

The FPGA prototype validates the architecture, but the RTL must be reworked for
silicon:

| FPGA construct | ASIC replacement |
|----------------|------------------|
| Inferred **BRAM** | foundry **SRAM macros** from the memory compiler |
| **DSP** blocks (hard multipliers) | synthesized / compiled MAC cells (standard cells) |
| Vendor IP (PLL, transceivers, FIFOs) | foundry PLL, licensed PHYs, generated FIFOs |
| Loose clocking / gated clocks | proper **clock tree** + integrated clock gating cells |
| Async / ad-hoc resets | defined **reset strategy** (sync deassert), reset tree |
| Implicit CDC | explicit **clock-domain-crossing** synchronizers |
| (none) | **DFT**: scan chains, memory BIST — mandatory for silicon |

Keep the RTL **portable and synthesizable** (no vendor primitives in the core),
so the same source targets the FPGA *and* the ASIC.

## 1. RTL → 2. Synthesis
Verilog/SystemVerilog → gate-level netlist against the PDK standard cells.
Constraints in **SDC** (clocks, I/O delays, false/multicycle paths).
- Commercial: Synopsys **Design Compiler**, Cadence **Genus**
- Open: **Yosys**

## 3. DFT insertion
Scan chains + memory BIST so the fabbed chip is testable.

## 4. Place & Route
Floorplan → power grid → placement → **clock tree synthesis (CTS)** → routing.
- Commercial: Cadence **Innovus**, Synopsys **ICC2 / Fusion Compiler**
- Open: **OpenROAD / OpenLane**

## 5. Timing closure
Static timing analysis across **PVT corners**; fix setup/hold; sign-off.
- Commercial: Synopsys **PrimeTime**  · Open: **OpenSTA**

## 6. Physical verification (sign-off)
- **DRC** (design rules), **LVS** (layout vs schematic), **antenna**, **ERC**
- **IR-drop / power** and **EM** checks
- Commercial: Siemens **Calibre**  · Open: **Magic** + **netgen** + **KLayout**

## 7. GDSII
Final layout streamed out as **GDSII** (or OASIS) — the file the fab consumes.

## 8. Tape-out
Submit GDS to the **MPW shuttle** ([MPW-SHUTTLE.md](MPW-SHUTTLE.md)) →
fab (weeks–months) → dicing → **packaging** → **test/bring-up**.

## Toolchain strategy for a startup

- **Cheap first block (130 nm open PDK):** the **fully open flow** — Yosys +
  OpenROAD/OpenLane + Magic/KLibrary on IHP SG13G2 or SkyWater. Near-zero tool
  cost, and a strong open-silicon story.
- **FD-SOI prototype (28/22 nm):** access **subsidized commercial EDA licenses
  via Europractice** (this is a major reason to go through them) plus the
  foundry PDK. A silicon partner (CEA-Leti) can run or co-run P&R + sign-off.

## What we bring vs. what we buy/partner

| We own | We license / partner for |
|--------|--------------------------|
| the clic-A1 RTL (compute core, ISA sequencer) | SRAM compiler, PLL, PCIe/DRAM PHYs (gen-2) |
| the clic compiler + ISA | PDK, EDA licenses (Europractice), fab + packaging |
| verification vectors (from clicrun) | sign-off / physical-design expertise (CEA-Leti) |
