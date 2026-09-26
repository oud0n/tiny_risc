#!/usr/bin/env bash
set -euo pipefail

sim_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$sim_root"
mkdir -p build/sim

rtl=(
    src/tiny_risc_soc.sv src/tiny_risc.sv
    src/rv32_mem_arbiter.sv src/rv32_shared_memory.sv
    src/control.sv src/regfile.sv src/alu.sv src/imm_gen.sv
)

export PATH="/home/n4styb33/.local/bin:$PATH"

iverilog_cmd=("${TINY_RISC_IVERILOG_BIN:-iverilog}")
if [[ -n "${TINY_RISC_IVERILOG_BASE:-}" ]]; then
    iverilog_cmd+=(-B "$TINY_RISC_IVERILOG_BASE")
fi
vvp_bin="${TINY_RISC_VVP_BIN:-vvp}"

for bench in tb_tiny_risc tb_tiny_risc_soc tb_tiny_risc_fault tb_tiny_risc_4core; do
    "${iverilog_cmd[@]}" -g2012 -I src -s "$bench" -o "build/sim/$bench.vvp" "test/tiny_risc/$bench.sv" "${rtl[@]}"
    "$vvp_bin" "build/sim/$bench.vvp"
done
