#!/bin/bash
# ECP5 synthesis resource estimate for the clic-A1 RTL (needs yosys).
#   brew install yosys && ./rtl/synth.sh
set -e
cd "$(dirname "$0")"

echo "== gemm_accel (N=4) — the verified accelerator block =="
yosys -p "read_verilog pe.v systolic.v gemm_accel.v; synth_ecp5 -top gemm_accel; stat" 2>/dev/null \
  | grep -iE "^ +[0-9]+ +(MULT18X18D|LUT4|TRELLIS_FF|CCU2C)" | sort -u

echo
echo "== systolic (N=12) — largest array that fits the ULX3S 85F (156 DSP) =="
yosys -p "read_verilog pe.v systolic.v; chparam -set N 12 systolic; synth_ecp5 -top systolic; stat" 2>/dev/null \
  | grep -iE "^ +[0-9]+ +(MULT18X18D|LUT4|TRELLIS_FF|CCU2C)" | sort -u
