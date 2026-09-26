# RV32I Implementation & Verification Guide

For the 4-hart shared-memory design, see [multicore architecture](multicore-architecture.md).
For the complete technical specifications and block designs, see [specifications](specifications.md).

The reference is *The RISC-V Instruction Set Manual, Volume I: Unprivileged Architecture*, Chapter 2 (RV32I Base Integer Instruction Set, version 2.1), kept locally at `../pdf/riscv-unprivileged.pdf`.

## Source files

| File | Contract and responsibility | Current state |
| --- | --- | --- |
| `src/tiny_risc.sv` | One hart: PC, datapath, and FSM state machine. Decoupled request/response memory ports; misaligned accesses and illegal instructions trigger safe `fault` state. | Fully implemented. Verified with unit, multicore, and official `riscv-tests`. |
| `src/tiny_risc.svh` | Shared opcode, funct3, funct7, ALU-operation, and write-back definitions. | Fully defined with RV32I opcodes including `OPCODE_MISC_MEM` (FENCE) and `OPCODE_SYSTEM`. |
| `src/control.sv` | Combinational opcode/funct decoder producing register write, ALU source, memory access, branch/jump, write-back selection, and `illegal_op` detection. | Fully implemented. Handles all RV32I base instructions, FENCE as NOP, and SYSTEM/unknown opcodes as illegal. |
| `src/regfile.sv` | Two asynchronous read ports, one rising-edge write port, 32 registers; x0 hardwired to zero. | Implemented and verified (passes 72 checks). |
| `src/alu.sv` | 32-bit add/subtract, Boolean, shifts, signed/unsigned set-less-than, and LUI pass-through. | Implemented and verified across all operations. |
| `src/imm_gen.sv` | Extracts and sign-extends I/S/B/U/J immediates from a 32-bit instruction. | Implemented and verified across all immediate formats. |
| `src/rv32_mem_arbiter.sv` | Round-robin fair arbiter for $N$ harts; holds owner until shared response and routes response back. | Implemented and stress-tested with 4-hart contention. |
| `src/rv32_shared_memory.sv` | Shared aligned 32-bit word ROM/SRAM model implemented as register array (`logic [31:0] words`). | Configurable word count, byte write strobes, latency, and hex initialization. |
| `src/tiny_risc_soc.sv` | 4-core SoC top level instantiating 4 independent harts, arbiters, and shared register-array memories. | Implemented with `N_HARTS=4` default, configurable stride vectors. |

## Verification Testbenches

| Testbench | Description | Result |
| --- | --- | :---: |
| `test/control/tb_control.sv` | Decoder checks (all opcodes, FENCE NOP, SYSTEM, illegal op). | **PASS (34/34)** |
| `test/regfile/tb_regfile.sv` | Register file checks (clear, write, x0 protection, concurrent R/W). | **PASS (72/72)** |
| `test/tiny_risc/tb_tiny_risc.sv` | Single-hart integration test with multicycle memory wait. | **PASS** |
| `test/tiny_risc/tb_tiny_risc_fault.sv` | Misaligned access and control flow fault detection. | **PASS** |
| `test/tiny_risc/tb_tiny_risc_soc.sv` | 2-hart shared-memory byte-lane writes and arbitration routing. | **PASS** |
| `test/tiny_risc/tb_tiny_risc_4core.sv` | **4-hart concurrent execution**, shared memory synthesis, polling synchronization, and arbitration contention. | **PASS** |
| `test/riscv-tests/run_all_isa_tests.sh` | **Official RISC-V Architectural Test Suite (RV32UI)**: 38 test suites covering all base integer instructions. | **PASS (38/38)** |

## Test Execution

- **Core & SoC simulation**: `test/tiny_risc/run_sim.sh`
- **Official RV32UI architectural tests**: `test/riscv-tests/run_all_isa_tests.sh`
- **Control unit tests**: `iverilog -g2012 -I src -s tb_control -o build/sim/tb_control.vvp test/control/tb_control.sv src/control.sv && vvp build/sim/tb_control.vvp`
