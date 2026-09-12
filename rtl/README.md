# clic-A1 RTL — the accelerator compute core

Synthesizable Verilog for the clic-A1 systolic MAC array — the hardware the
[architecture docs](../docs/hardware/ARCHITECTURE.md) describe, and the first
real step from FPGA prototype toward an [ASIC tape-out](../docs/hardware/ASIC-FLOW.md).

| File | What |
|------|------|
| `pe.v` | one processing element: an INT8 multiply-accumulate cell (Verilog-2001, synthesizable) |
| `systolic.v` | an `N×N` output-stationary systolic array computing `C = A·B` |
| `gemm_accel.v` | **the accelerator block**: on-chip SRAM + control FSM (hardware skewing) + host load/read port wrapping the array (the gen-1 MVP cluster shape) |
| `tb_systolic.sv` | self-checking testbench for the array |
| `tb_gemm_accel.sv` | self-checking testbench for the block: host-loads A/B, runs, reads C, compares |
| `sim.sh` | build + run both simulations |

## Run it

```bash
brew install icarus-verilog      # once
./rtl/sim.sh
# -> PASS: 4x4 systolic GEMM matches CPU reference (16 elements)
# -> PASS: gemm_accel block (load->run->read) matches CPU reference (16 elems)
```

Parameterize with `N` (array size), `DW` (operand width, 8 = INT8), `ACCW`
(accumulator width). The design is portable: the `a_in*b_in` MAC maps to a DSP
slice on an FPGA and to a hardened MAC / standard-cell multiplier on an ASIC.

## Why this matters

This is the compute engine at the heart of clic-A1. It is:
- **Verified** — simulated against a CPU reference (signed INT8, incl. negatives).
- **Synthesizable** — ready for the FPGA (ULX3S) and, after the FPGA→ASIC
  conversion checklist in [ASIC-FLOW.md](../docs/hardware/ASIC-FLOW.md),
  for synthesis → place & route → GDSII.
- **The credibility artifact** a silicon partner (CEA-Leti) actually wants to
  see: real RTL, not slides.

## Next in the RTL track

- Wrap the array with the clic-ISA sequencer + SRAM buffers ([ISA.md](../docs/hardware/ISA.md))
- Map to the ULX3S FPGA and measure real performance-per-watt
- Add INT4 packed mode; DFT (scan + memory BIST) for tape-out
