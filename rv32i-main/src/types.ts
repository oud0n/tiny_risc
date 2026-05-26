/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

export interface CpuRegisters {
  [key: string]: number; // x0 - x31
}

export interface DecodedInstruction {
  binary: string;
  hex: string;
  opcode: string;
  rd: number;
  rs1: number;
  rs2: number;
  funct3: number;
  funct7: number;
  imm: number;
  type: 'R' | 'I' | 'S' | 'B' | 'U' | 'J' | 'UNKNOWN';
  assembly: string;
  error?: string;
}

export interface ControlSignals {
  reg_write: boolean;
  alu_src: boolean;
  mem_to_reg: '00' | '01' | '10'; // 00: ALU, 01: Mem, 10: PC+4
  mem_write: boolean;
  mem_read: boolean;
  branch: boolean;
  jump: boolean;
  alu_op: string; // "ADD", "SUB", "AND", etc.
  branch_taken: boolean;
}

export interface DatapathSignals {
  pc: number;
  next_pc: number;
  instruction: number;
  rs1_val: number;
  rs2_val: number;
  imm_val: number;
  alu_operand_a: number;
  alu_operand_b: number;
  alu_result: number;
  mem_read_data: number;
  reg_write_data: number;
  control: ControlSignals;
  active_signals?: DecodedInstruction;
}

export interface CpuState {
  pc: number;
  registers: CpuRegisters;
  memory: { [address: number]: number };
  memory_io: {
    leds: number; // 8-bit output mapped to address 0x4000
    seven_seg: number; // 32-bit output mapped to address 0x4004
    lcd_text: string; // ASCII visual text mapped directly to 0x4008
  };
  cycle: number;
  halted: boolean;
  active_signals: DatapathSignals;
}

export interface AssemblyLine {
  address: number;
  assembly: string;
  hex: string;
  decoded?: DecodedInstruction;
}

export interface PredefinedProgram {
  name: string;
  description: string;
  code: string;
}
