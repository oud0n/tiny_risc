import cocotb
from cocotb.triggers import Timer

# Instruction Constants (Matching riscv32.svh)
OPCODE_R_TYPE = 0b0110011
OPCODE_I_TYPE = 0b0010011
OPCODE_LOAD   = 0b0000011
OPCODE_STORE  = 0b0100011
OPCODE_BRANCH = 0b1100011
OPCODE_JAL    = 0b1101111
OPCODE_JALR   = 0b1100111
OPCODE_LUI    = 0b0110111
OPCODE_AUIPC  = 0b0010111

async def check_results(dut, name):
    """Helper function to log current signal states."""
    await Timer(1, units='ns')
    dut._log.info(f"Testing {name}:")
    dut._log.info(f"  Inputs:  op={hex(dut.opcode.value)}, f3={hex(dut.funct3.value)}, f7={hex(dut.funct7.value)}")
    dut._log.info(f"  Outputs: reg_w={dut.reg_write.value}, src_a={dut.alu_src_a.value}, src_b={dut.alu_src_b.value}, "
                  f"mem_w={dut.mem_write.value}, res={dut.result_src.value}, br={dut.branch.value}, "
                  f"jp={dut.jump.value}, alu_ctrl={hex(dut.alu_control.value)}")
    dut._log.info("-" * 40)

@cocotb.test()
async def control_unit_basic_test(dut):
    """Test all major instruction decodings."""
    
    dut._log.info("Starting Control Unit Python Testbench...")

    # Initialize inputs
    dut.opcode.value = 0
    dut.funct3.value = 0
    dut.funct7.value = 0
    await Timer(10, units='ns')

    # Test R-TYPE (ADD)
    dut.opcode.value = OPCODE_R_TYPE
    dut.funct3.value = 0b000
    dut.funct7.value = 0b0000000
    await check_results(dut, "R-TYPE ADD")
    assert dut.reg_write.value == 1
    assert dut.alu_control.value == 0x0

    # Test R-TYPE (SUB)
    dut.funct7.value = 0b0100000
    await check_results(dut, "R-TYPE SUB")
    assert dut.alu_control.value == 0x8

    # Test I-TYPE (ADDI)
    dut.opcode.value = OPCODE_I_TYPE
    dut.funct3.value = 0b000
    dut.funct7.value = 0
    await check_results(dut, "I-TYPE ADDI")
    assert dut.alu_src_b.value == 1

    # Test Load (LW)
    dut.opcode.value = OPCODE_LOAD
    dut.funct3.value = 0b010
    await check_results(dut, "LOAD LW")
    assert dut.result_src.value == 1 # RESULT_SRC_MEM

    # Test JAL
    dut.opcode.value = OPCODE_JAL
    await check_results(dut, "JAL")
    assert dut.jump.value == 1
    assert dut.result_src.value == 2 # RESULT_SRC_PC4

    # Test JALR
    dut.opcode.value = OPCODE_JALR
    await check_results(dut, "JALR")
    assert dut.jump.value == 1
    assert dut.alu_src_b.value == 1

    dut._log.info("All Python-based tests passed! GG!")