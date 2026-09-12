#!/usr/bin/env python3
"""
OSHI-A1 first-order silicon spec calculator.

Turns the architectural knobs into consistent, derived numbers (TOPS, die area,
power, bandwidth). All constants are first-order estimates for a ~12 nm FinFET
node and MUST be refined with a foundry PDK + synthesis. Tune the knobs at the
top to explore the design space.

    python3 tools/spec_calc.py
"""

# ---- architectural knobs ---------------------------------------------------
CORES         = 16           # tensor cores (each a systolic MAC tile)
MAC_PER_CORE  = 4096         # 64 x 64 INT8 MACs per core
FREQ_GHZ      = 1.0          # target clock
SRAM_MB       = 32           # on-chip SRAM (L2 + per-core buffers)
SIMD_LANES    = 64           # FP16 lanes per core (vector/activation unit)
LPDDR_MT_S    = 8533         # LPDDR5X data rate
LPDDR_BUS_BIT = 256          # total external memory bus width
PCIE_GEN      = 4
PCIE_LANES    = 8

# ---- datapath rates (relative to INT8) -------------------------------------
INT4_FACTOR   = 2.0
FP16_FACTOR   = 0.5          # FP16/BF16 at half INT8 rate

# ---- first-order physical constants (12 nm, estimates) ---------------------
MAC_AREA_MM2      = 0.0008   # per INT8 MAC incl. local registers
SRAM_MM2_PER_MB   = 0.70
UNCORE_AREA_MM2   = 50.0     # NoC, PCIe, LPDDR PHYs, RISC-V, DMA, IO
EFF_TOPS_PER_W    = 4.0      # INT8 efficiency target (quantized)
BOARD_POWER_MULT  = 1.6      # card power vs core (DRAM, PHYs, regulators)

# ---- derived ---------------------------------------------------------------
freq = FREQ_GHZ * 1e9
macs = CORES * MAC_PER_CORE
int8_tops   = macs * 2 * freq / 1e12
int4_tops   = int8_tops * INT4_FACTOR
fp16_tflops = int8_tops * FP16_FACTOR

mac_area   = macs * MAC_AREA_MM2
sram_area  = SRAM_MB * SRAM_MM2_PER_MB
die_area   = mac_area + sram_area + UNCORE_AREA_MM2

core_power = int8_tops / EFF_TOPS_PER_W
card_power = core_power * BOARD_POWER_MULT

bw_gbps    = LPDDR_MT_S * 1e6 * LPDDR_BUS_BIT / 8 / 1e9
pcie_gbps  = {3: 0.985, 4: 1.969, 5: 3.938}[PCIE_GEN] * PCIE_LANES

sram_per_core_kb = SRAM_MB * 1024 / CORES

print("OSHI-A1 — first-order silicon spec")
print("=" * 46)
print(f"  tensor cores          : {CORES}  x {MAC_PER_CORE} INT8 MACs")
print(f"  total INT8 MACs        : {macs:,}")
print(f"  clock target           : {FREQ_GHZ:.2f} GHz")
print(f"  SIMD lanes / core (FP16): {SIMD_LANES}")
print("-" * 46)
print(f"  INT8 throughput        : {int8_tops:.0f} TOPS")
print(f"  INT4 throughput        : {int4_tops:.0f} TOPS")
print(f"  FP16/BF16 throughput   : {fp16_tflops:.0f} TFLOPS")
print("-" * 46)
print(f"  on-chip SRAM           : {SRAM_MB} MB  (~{sram_per_core_kb:.0f} KB/core)")
print(f"  memory (LPDDR5X {LPDDR_BUS_BIT}-bit): {bw_gbps:.0f} GB/s")
print(f"  host (PCIe Gen{PCIE_GEN} x{PCIE_LANES}) : {pcie_gbps:.1f} GB/s")
print("-" * 46)
print(f"  est. die area          : {die_area:.0f} mm^2")
print(f"     - MAC logic         : {mac_area:.0f} mm^2")
print(f"     - SRAM              : {sram_area:.0f} mm^2")
print(f"     - uncore/IO/PHY     : {UNCORE_AREA_MM2:.0f} mm^2")
print(f"  core power (target)    : {core_power:.0f} W")
print(f"  card TDP (target)      : {card_power:.0f} W")
print(f"  efficiency (INT8)      : {EFF_TOPS_PER_W:.1f} TOPS/W  ->  "
      f"{int4_tops/card_power:.1f} INT4-TOPS/W (card)")
