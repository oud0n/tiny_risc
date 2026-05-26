/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { CpuState, CpuRegisters, DecodedInstruction, ControlSignals, DatapathSignals } from '../types';

// Enforce 32-bit signed integer limits in JavaScript
export function toInt32(val: number): number {
  return val | 0;
}

export function toUint32(val: number): number {
  return val >>> 0;
}

// Convert instruction name to actual SV control signals
export function computeSignals(decoded: DecodedInstruction): ControlSignals {
  const op = decoded.opcode;
  const f3 = decoded.funct3;
  const f7 = decoded.funct7;

  let signals: ControlSignals = {
    reg_write: false,
    alu_src: false,
    mem_to_reg: '00',
    mem_write: false,
    mem_read: false,
    branch: false,
    jump: false,
    alu_op: 'ADD',
    branch_taken: false,
  };

  switch (op) {
    case '0110011': // R-type
      signals.reg_write = true;
      signals.alu_src = false;
      signals.mem_to_reg = '00';
      switch (f3) {
        case 0: signals.alu_op = f7 === 32 ? 'SUB' : 'ADD'; break;
        case 1: signals.alu_op = 'SLL'; break;
        case 2: signals.alu_op = 'SLT'; break;
        case 3: signals.alu_op = 'SLTU'; break;
        case 4: signals.alu_op = 'XOR'; break;
        case 5: signals.alu_op = f7 === 32 ? 'SRA' : 'SRL'; break;
        case 6: signals.alu_op = 'OR'; break;
        case 7: signals.alu_op = 'AND'; break;
      }
      break;

    case '0010011': // I-type ALU
      signals.reg_write = true;
      signals.alu_src = true;
      signals.mem_to_reg = '00';
      switch (f3) {
        case 0: signals.alu_op = 'ADD'; break;
        case 1: signals.alu_op = 'SLL'; break;
        case 2: signals.alu_op = 'SLT'; break;
        case 3: signals.alu_op = 'SLTU'; break;
        case 4: signals.alu_op = 'XOR'; break;
        case 5: signals.alu_op = f7 === 32 ? 'SRA' : 'SRL'; break;
        case 6: signals.alu_op = 'OR'; break;
        case 7: signals.alu_op = 'AND'; break;
      }
      break;

    case '0000011': // LW Loads
      signals.reg_write = true;
      signals.alu_src = true;
      signals.mem_to_reg = '01'; // write-back loaded mem data
      signals.mem_read = true;
      signals.alu_op = 'ADD'; // computing target address
      break;

    case '0100011': // SW Stores
      signals.reg_write = false;
      signals.alu_src = true;
      signals.mem_write = true;
      signals.alu_op = 'ADD'; // address calculation
      break;

    case '1100011': // Branches
      signals.reg_write = false;
      signals.alu_src = false;
      signals.branch = true;
      switch (f3) {
        case 0: signals.alu_op = 'SUB'; break; // BEQ
        case 1: signals.alu_op = 'SUB'; break; // BNE
        default: signals.alu_op = 'SLT'; break; // BLT/BGE
      }
      break;

    case '1101111': // JAL Jump
      signals.reg_write = true;
      signals.mem_to_reg = '10'; // PC + 4 Link
      signals.jump = true;
      signals.alu_op = 'ADD';
      break;

    case '1100111': // JALR Jump standard opcode
    case '1100117': // custom decoder opcode matching SV module
      signals.reg_write = true;
      signals.alu_src = true;
      signals.mem_to_reg = '10'; // PC + 4 Link
      signals.jump = true;
      signals.alu_op = 'ADD';
      break;

    case '0110117': // LUI load
      signals.reg_write = true;
      signals.alu_src = true;
      signals.mem_to_reg = '00';
      signals.alu_op = 'LUI'; // passthrough of imm operand B
      break;

    default:
      signals.alu_op = 'ADD';
      break;
  }

  return signals;
}

export function createInitialState(): CpuState {
  const regs: CpuRegisters = {};
  for (let i = 0; i < 32; i++) {
    regs[`x${i}`] = 0;
  }
  
  // Set global setup defaults: Stack pointer linked toward high RAM region
  regs['x2'] = 1000; // stack pointer standard

  return {
    pc: 0,
    registers: regs,
    memory: {},
    memory_io: {
      leds: 0,
      seven_seg: 0,
      lcd_text: '',
    },
    cycle: 0,
    halted: false,
    active_signals: {
      pc: 0,
      next_pc: 0,
      instruction: 0,
      rs1_val: 0,
      rs2_val: 0,
      imm_val: 0,
      alu_operand_a: 0,
      alu_operand_b: 0,
      alu_result: 0,
      mem_read_data: 0,
      reg_write_data: 0,
      control: {
        reg_write: false,
        alu_src: false,
        mem_to_reg: '00',
        mem_write: false,
        mem_read: false,
        branch: false,
        jump: false,
        alu_op: 'ADD',
        branch_taken: false,
      },
    },
  };
}

export function simulateCycle(
  state: CpuState,
  compiledInstructions: DecodedInstruction[]
): CpuState {
  if (state.halted) return state;

  const currentPC = state.pc;
  const instIndex = currentPC / 4;

  // Gracefully halt if we execution runs off instruction boundaries
  if (instIndex < 0 || instIndex >= compiledInstructions.length) {
    return {
      ...state,
      halted: true,
    };
  }

  const decoded = compiledInstructions[instIndex];
  if (decoded.error) {
    // If the instruction itself was compiled with error, halt core
    return {
      ...state,
      halted: true,
    };
  }

  // Clone current registers and memory for mutation
  const registers = { ...state.registers };
  const memory = { ...state.memory };
  const memory_io = { ...state.memory_io };

  // Fetch registers values
  const rs1_num = decoded.rs1;
  const rs2_num = decoded.rs2;
  const rd_num = decoded.rd;

  const rs1_val = toInt32(registers[`x${rs1_num}`] || 0);
  const rs2_val = toInt32(registers[`x${rs2_num}`] || 0);
  const imm_val = toInt32(decoded.imm);

  const control = computeSignals(decoded);

  // Compute ALU operands
  const alu_operand_a = rs1_val;
  const alu_operand_b = control.alu_src ? imm_val : rs2_val;
  
  // Compute ALU Result
  let alu_result = 0;
  const signed_a = alu_operand_a;
  const signed_b = alu_operand_b;

  switch (control.alu_op) {
    case 'ADD':
      alu_result = toInt32(signed_a + signed_b);
      break;
    case 'SUB':
      alu_result = toInt32(signed_a - signed_b);
      break;
    case 'SLL':
      alu_result = toInt32(signed_a << (signed_b & 0x1F));
      break;
    case 'SLT':
      alu_result = signed_a < signed_b ? 1 : 0;
      break;
    case 'SLTU':
      alu_result = toUint32(signed_a) < toUint32(signed_b) ? 1 : 0;
      break;
    case 'XOR':
      alu_result = toInt32(signed_a ^ signed_b);
      break;
    case 'SRL':
      alu_result = toInt32(toUint32(signed_a) >>> (signed_b & 0x1F));
      break;
    case 'SRA':
      alu_result = toInt32(signed_a >> (signed_b & 0x1F));
      break;
    case 'OR':
      alu_result = toInt32(signed_a | signed_b);
      break;
    case 'AND':
      alu_result = toInt32(signed_a & signed_b);
      break;
    case 'LUI':
      alu_result = imm_val;
      break;
    default:
      alu_result = 0;
  }

  let mem_read_data = 0;

  // Intercept Load/Stores for data memory mapped I/O:
  // 0x4000 = LEDs (W), 0x4004 = 7Segment (W), 0x4008 = ASCII character LCD screen append (W)
  if (control.mem_write) {
    const dmem_address = toUint32(alu_result);
    if (dmem_address === 0x4000) {
      memory_io.leds = rs2_val & 0xFF; // Write lower 8-bit LEDs
    } else if (dmem_address === 0x4004) {
      memory_io.seven_seg = rs2_val; // Write hex values
    } else if (dmem_address === 0x4008) {
      // Decode character or treat as plain output
      const char = String.fromCharCode(rs2_val & 0xFF);
      memory_io.lcd_text += char;
    } else {
      memory[dmem_address] = rs2_val;
    }
  }

  if (control.mem_read) {
    const dmem_address = toUint32(alu_result);
    if (dmem_address === 0x4000) {
      mem_read_data = memory_io.leds;
    } else if (dmem_address === 0x4004) {
      mem_read_data = memory_io.seven_seg;
    } else {
      mem_read_data = toInt32(memory[dmem_address] || 0);
    }
  }

  // Compute writeback value for destination register rd
  let reg_write_data = alu_result;
  if (control.mem_to_reg === '01') {
    reg_write_data = mem_read_data;
  } else if (control.mem_to_reg === '10') {
    reg_write_data = currentPC + 4;
  }

  // Update register values (Register x0 remains hardwired to 0)
  if (control.reg_write && rd_num !== 0) {
    registers[`x${rd_num}`] = reg_write_data;
  }

  // Evaluate Branch Taken Condition
  let branch_taken = false;
  if (control.branch) {
    const equals = (signed_a === signed_b);
    const rs1_val_uint = toUint32(signed_a);
    const rs2_val_uint = toUint32(signed_b);

    switch (decoded.funct3) {
      case 0: // BEQ
        branch_taken = equals;
        break;
      case 1: // BNE
        branch_taken = !equals;
        break;
      case 4: // BLT
        branch_taken = (signed_a < signed_b);
        break;
      case 5: // BGE
        branch_taken = (signed_a >= signed_b);
        break;
      case 6: // BLTU
        branch_taken = (rs1_val_uint < rs2_val_uint);
        break;
      case 7: // BGEU
        branch_taken = (rs1_val_uint >= rs2_val_uint);
        break;
    }
  }

  // Set branch taken output inside signals metadata
  control.branch_taken = branch_taken;

  // Compute next PC state
  let next_pc = currentPC + 4;
  if (control.jump) {
    if (decoded.opcode === '1100111' || decoded.opcode === '1100117') {
      // JALR: Target standard = rs1 + immediate, cleared lower bits to 0
      next_pc = toInt32((rs1_val + imm_val) & ~1);
    } else {
      // JAL standard: Target = PC + immediate offset
      next_pc = toInt32(currentPC + imm_val);
    }
  } else if (branch_taken) {
    next_pc = toInt32(currentPC + imm_val);
  }

  const active_signals: DatapathSignals = {
    pc: currentPC,
    next_pc,
    instruction: parseInt(decoded.binary, 2),
    rs1_val,
    rs2_val,
    imm_val,
    alu_operand_a,
    alu_operand_b,
    alu_result,
    mem_read_data,
    reg_write_data,
    control,
  };

  return {
    pc: next_pc,
    registers,
    memory,
    memory_io,
    cycle: state.cycle + 1,
    halted: next_pc < 0 || (next_pc / 4) >= compiledInstructions.length,
    active_signals,
  };
}

export const PREDEFINED_PROGRAMS: { [key: string]: { name: string; description: string; code: string } } = {
  fibonacci: {
    name: "Fibonacci Sequence",
    description: "Calculates the Fibonacci numbers and writes them step-by-step into the LED Matrix and Seven-Segment outputs.",
    code: `# Fibonacci Core Calculator
# SystemVerilog CPU Demo
start:
    li t0, 0          # prev2 = 0
    li t1, 1          # prev1 = 1
    li t2, 10         # loops = 10
    li t3, 0          # counter = 0
    
    # Store LED address x4 = 0x4000
    li s0, 16384      # 16384 dec is 0x4000 (LEDs)
    # Store 7Seg address x5 = 0x4004
    li s1, 16388      # 16388 dec is 0x4004 (7-Seg)
    # Store Console print address s2 = 0x4008
    li s2, 16392      # 16392 dec is 0x4008 (LCD)

loop:
    # Print a character indicator 'F' to LCD Console
    li t4, 70         # ASCII for 'F'
    sw t4, 0(s2)
    li t4, 58         # ASCII for ':'
    sw t4, 0(s2)
    li t4, 32         # ASCII space
    sw t4, 0(s2)

    # Calculate next value
    add t4, t0, t1    # current = prev2 + prev1
    
    # Display on LEDs and 7-segment display
    sw t4, 0(s0)      # LEDs show current
    sw t4, 0(s1)      # 7Seg shows current
    
    # Shift registers
    mv t0, t1         # prev2 = prev1
    mv t1, t4         # prev1 = current
    
    # Check bounds
    addi t3, t3, 1    # counter++
    blt t3, t2, loop  # if counter < loops, jump to loop

done:
    li t4, 10         # ASCII newline
    sw t4, 0(s2)
    li t4, 75         # ASCII 'K' for OK/Done
    sw t4, 0(s2)
    j done            # halt by loop
`
  },
  multiplication: {
    name: "Iterative Multiplication",
    description: "Computes 12 * 7 by adding 12 repeatedly 7 times, visually storing progress inside registers.",
    code: `# Multiplication: 12 * 7
start:
    li t0, 12         # Multiplicand = 12
    li t1, 7          # Multiplier = 7
    li t2, 0          # Result = 0
    
    li s0, 16388      # IO: 7segment display (0x4004)
    li s2, 16392      # IO: LCD printed text (0x4008)

loop_mult:
    # Check if multiplier is 0
    beqz t1, done_mult
    
    # Add multiplicand to result
    add t2, t2, t0
    
    # Decrement multiplier
    addi t1, t1, -1
    
    # Display partial result
    sw t2, 0(s0)
    
    # Print partial dot indicator '.' to show progress
    li t4, 46         # ASCII for '.'
    sw t4, 0(s2)
    
    j loop_mult

done_mult:
    # Print newline and final summary character 'R'
    li t4, 10         # Newline
    sw t4, 0(s2)
    li t4, 82         # ASCII for 'R'
    sw t4, 0(s2)
    j done_mult
`
  },
  led_chaser: {
    name: "LED Bit Shift Chaser",
    description: "Performs bit shifts of a single active bit to bounce across the mapped LEDs at address 0x4000.",
    code: `# LED Shifter Bounce Demo
start:
    li s0, 16384      # LED Port (0x4000)
    li t0, 1          # Active bit pattern (0000 0001)
    li t1, 8          # Count loops to slide left
    li t2, 0          # Step pointer

shift_left:
    sw t0, 0(s0)      # Output current pattern to LEDs
    slli t0, t0, 1    # Shift left by 1 bit
    
    addi t2, t2, 1    # increment
    blt t2, t1, shift_left

done_chase:
    # Output visual 0xFF to signify wrap
    li t0, 255
    sw t0, 0(s0)
    j start
`
  }
};
