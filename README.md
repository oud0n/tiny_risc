# tiny RISC-V (4-Core RV32I Shared-Memory SoC)

An in-order 4-core RV32I shared-memory SoC implementation in SystemVerilog.
Instruction ROM and data RAM are implemented as register arrays (`words [0:WORDS-1]`).

## Documentation
- [System and Block Specifications](docs/specifications.md): Complete functional specification, SoC architecture, state machine, and block designs.
- [Multicore Architecture Guide](docs/multicore-architecture.md): 4-core structure, fair round-robin arbitration, and synchronization.
- [Implementation Guide](docs/implementation.md): Module contracts and verification suites.
- [Work Log](docs/work_log.md): Record of implementation and verification steps.
- [Tile-based Extension & DFT Roadmap (TODO)](docs/tile_dft_todo.md): Specification study, FF scale-up plan, and phased TODO list for DFT testbed.

## Simulations

### 1. Integration & 4-Core Multicore Suite
Runs the single-hart, two-hart, fault detection, and 4-core concurrent execution tests:

```bash
test/tiny_risc/run_sim.sh
```

### 2. Official RISC-V Architectural Test Suite (riscv-tests RV32UI)
Compiles and runs all 38 official RISC-V architectural tests on `tiny_risc`:

```bash
test/riscv-tests/run_all_isa_tests.sh
```
All 38 test suites pass (100% compliance).
