# ECP5 synthesis results — clic-A1 RTL

Real synthesis of the [RTL](../../rtl/) to the Lattice **ECP5** (the ULX3S 85F
FPGA), via **yosys `synth_ecp5`** (v0.69). These are measured cell counts from
synthesis — not hand-waving — reproducible with [`rtl/synth.sh`](../../rtl/synth.sh).

## Results

| Design | MULT18×18 (DSP) | LUT4 | FF | Carry (CCU2C) |
|--------|:---------------:|:----:|:--:|:-------------:|
| `gemm_accel` 4×4 (verified block: array + SRAM + FSM + host port) | 16 | 1,083 | 1,308 | 316 |
| `systolic` 12×12 (compute array only) | **144** | ~0 | 6,720 | 2,304 |

**ULX3S 85F budget:** ~84k LUT4, **156 MULT18×18 (DSP)**, ~208 × 18 kb BRAM.

## What this proves

1. **The RTL is synthesis-clean** — it maps to real ECP5 primitives with no
   fixups. Not just "simulates," but "synthesizes."
2. **Every MAC becomes a hardware multiplier** — 1 MAC → 1 MULT18×18D. The
   architecture uses the silicon it should.
3. **The verified 4×4 block is ~1% of the FPGA** — trivially fits, leaving room
   to scale.
4. **The 85F fits a 12×12 = 144-MAC cluster** (144 of 156 DSP, 92%). That is a
   genuine FPGA prototype of a clic-A1 compute cluster on the €150 ULX3S — the
   exact perf/watt-measurement vehicle in the [hardware roadmap](HARDWARE-ROADMAP.md).

## Reproduce

```bash
brew install yosys
./rtl/synth.sh
```

## Caveat & next step

These are **synthesis resource estimates** (cell counts), not place-&-route
timing. **Fmax** and final utilization need `nextpnr-ecp5` (P&R) — the next RTL
milestone, after which we map to the physical ULX3S and measure real
throughput and performance-per-watt.
