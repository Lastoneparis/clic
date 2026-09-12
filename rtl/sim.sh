#!/bin/bash
# Simulate + self-check the clic-A1 RTL (needs Icarus Verilog).
set -e
cd "$(dirname "$0")"

echo "==> systolic array"
iverilog -g2012 -o /tmp/clic_arr.vvp pe.v systolic.v tb_systolic.sv
vvp /tmp/clic_arr.vvp

echo "==> gemm accelerator block"
iverilog -g2012 -o /tmp/clic_acc.vvp pe.v systolic.v gemm_accel.v tb_gemm_accel.sv
vvp /tmp/clic_acc.vvp
