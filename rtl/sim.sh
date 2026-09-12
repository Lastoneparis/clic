#!/bin/bash
# Simulate + self-check the clic-A1 systolic array (needs Icarus Verilog).
set -e
cd "$(dirname "$0")"
iverilog -g2012 -o /tmp/clic_sys.vvp pe.v systolic.v tb_systolic.sv
vvp /tmp/clic_sys.vvp
