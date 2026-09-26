#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
source_root="$(cd "$script_dir/../.." && pwd)"
cd "$source_root"

export PATH="/home/n4styb33/.local/bin:$PATH"

mkdir -p build/riscv-tests/bin
mkdir -p build/riscv-tests/hex
mkdir -p build/riscv-tests/sim

echo "=========================================================="
echo " [1/2] Compiling RV32I Arch Testbench"
echo "=========================================================="
iverilog -g2012 -I src \
    -s tb_riscv_isa \
    -o build/riscv-tests/sim/tb_riscv_isa.vvp \
    test/riscv-tests/tb_riscv_isa.sv \
    src/tiny_risc.sv src/rv32_mem_arbiter.sv src/rv32_shared_memory.sv \
    src/control.sv src/regfile.sv src/alu.sv src/imm_gen.sv 2>&1 | grep -v "sorry: constant selects" || true

tests=(
    add addi and andi auipc
    beq bge bgeu blt bltu bne
    jal jalr lui
    lw lh lhu lb lbu
    sw sh sb
    sll slli sra srai srl srli
    slt slti sltu sltiu
    sub xor xori or ori
    simple
)

passed=0
failed=0
total=${#tests[@]}

echo ""
echo "=========================================================="
echo " [2/2] Running Official RISC-V Arch Tests (RV32UI)"
echo " Total test suites: $total"
echo "=========================================================="

printf "%-12s %-10s %-12s\n" "TEST" "STATUS" "CYCLES"
printf "%-12s %-10s %-12s\n" "------------" "----------" "------------"

for t in "${tests[@]}"; do
    src="test/riscv-tests/src/rv32ui/${t}.S"
    elf="build/riscv-tests/bin/${t}.elf"
    raw_bin="build/riscv-tests/bin/${t}.bin"
    hex="build/riscv-tests/hex/${t}.hex"

    # Compile with riscv GCC
    riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -static -mcmodel=medany \
        -fvisibility=hidden -nostdlib -nostartfiles \
        -I test/riscv-tests/env \
        -T test/riscv-tests/env/link.ld \
        -o "$elf" "$src" 2>/dev/null

    # Objcopy to binary
    riscv64-unknown-elf-objcopy -O binary "$elf" "$raw_bin"

    # Convert to 32-bit hex
    python3 test/riscv-tests/bin2hex.py "$raw_bin" "$hex"

    # Simulate
    set +e
    sim_out=$(vvp build/riscv-tests/sim/tb_riscv_isa.vvp +HEX_FILE="$hex" 2>&1)
    exit_code=$?
    set -e

    if [[ $exit_code -eq 0 ]] && echo "$sim_out" | grep -q "PASS:"; then
        cycles=$(echo "$sim_out" | grep "PASS:" | sed -E 's/.*in ([0-9]+) cycles.*/\1/')
        printf "%-12s \033[32m%-10s\033[0m %-12s\n" "$t" "PASSED" "${cycles}c"
        passed=$((passed + 1))
    else
        printf "%-12s \033[31m%-10s\033[0m %-12s\n" "$t" "FAILED" "-"
        echo "$sim_out" | grep -E "FAIL:|ERROR:|TIMEOUT:|FATAL:" || echo "$sim_out" | tail -n 5
        failed=$((failed + 1))
    fi
done

echo "=========================================================="
echo " Results: $passed / $total passed, $failed failed."
echo "=========================================================="

if [[ $failed -eq 0 ]]; then
    exit 0
else
    exit 1
fi
