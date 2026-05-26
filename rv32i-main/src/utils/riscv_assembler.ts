/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { DecodedInstruction, AssemblyLine } from '../types';

// Map register names to their numeric representation (0-31)
const REGISTER_MAP: { [key: string]: number } = {
  x0: 0, zero: 0,
  x1: 1, ra: 1,
  x2: 2, sp: 2,
  x3: 3, gp: 3,
  x4: 4, tp: 4,
  x5: 5, t0: 5,
  x6: 6, t1: 6,
  x7: 7, t2: 7,
  x8: 8, s0: 8, fp: 8,
  x9: 9, s1: 9,
  x10: 10, a0: 10,
  x11: 11, a1: 11,
  x12: 12, a2: 12,
  x13: 13, a3: 13,
  x14: 14, a4: 14,
  x15: 15, a5: 15,
  x16: 16, a6: 16,
  x17: 17, a7: 17,
  x18: 18, s2: 18,
  x19: 19, s3: 19,
  x20: 20, s4: 20,
  x21: 21, s5: 21,
  x22: 22, s6: 22,
  x23: 23, s7: 23,
  x24: 24, s8: 24,
  x25: 25, s9: 25,
  x26: 26, s10: 26,
  x27: 27, s11: 27,
  x28: 28, t3: 28,
  x29: 29, t4: 29,
  x30: 30, t5: 30,
  x31: 31, t6: 31,
};

// Helper to check if a token is a register
function parseRegister(token: string): number {
  const clean = token.replace(/,/g, '').trim().toLowerCase();
  if (REGISTER_MAP[clean] !== undefined) {
    return REGISTER_MAP[clean];
  }
  const regNumber = parseInt(clean.replace(/^x/, ''), 10);
  if (!isNaN(regNumber) && regNumber >= 0 && regNumber <= 31) {
    return regNumber;
  }
  throw new Error(`Invalid register specifier: "${token}"`);
}

// Helper to format 32-bit binary string to Hex
export function binToHex32(bin: string): string {
  if (bin.length !== 32) return '00000000';
  const val = parseInt(bin, 2);
  return val.toString(16).padStart(8, '0').toUpperCase();
}

// Convert a number to signed binary with specified length
function toSignedBinary(val: number, bits: number): string {
  // Ensure value stays within bits limits
  const max = (1 << (bits - 1)) - 1;
  const min = -(1 << (bits - 1));
  let bounded = val;
  if (val > max || val < min) {
    // Wrap around or cap
    bounded = val & ((1 << bits) - 1);
  }
  if (bounded < 0) {
    bounded = (1 << bits) + bounded;
  }
  return bounded.toString(2).padStart(bits, '0');
}

export function assembleLine(
  lineText: string,
  currentAddress: number,
  labels: { [key: string]: number }
): DecodedInstruction {
  let cleanLine = lineText.trim();
  
  // Create blank decoded output
  const defaultInstruction = (errorMsg: string): DecodedInstruction => ({
    binary: '00000000000000000000000000000000',
    hex: '00000000',
    opcode: '0000000',
    rd: 0,
    rs1: 0,
    rs2: 0,
    funct3: 0,
    funct7: 0,
    imm: 0,
    type: 'UNKNOWN',
    assembly: lineText,
    error: errorMsg,
  });

  if (!cleanLine) {
    return defaultInstruction('Empty line');
  }

  // Tokenize
  // Split on whitespace but respect parenthetical loads/stores like lw x5, 4(x2)
  const tokens = cleanLine.split(/[\s,]+/);
  if (tokens.length === 0 || tokens[0] === '') {
    return defaultInstruction('Empty line');
  }

  const instName = tokens[0].toLowerCase();

  try {
    // 1. PSEUDO INSTRUCTIONS TRANSFORMATION
    if (instName === 'li') {
      // li rd, imm -> addi rd, x0, imm
      if (tokens.length < 3) throw new Error('Usage: li rd, immediate');
      const rdStr = tokens[1];
      const immStr = tokens[2];
      return assembleLine(`addi ${rdStr}, x0, ${immStr}`, currentAddress, labels);
    }
    
    if (instName === 'mv') {
      // mv rd, rs -> addi rd, rs, 0
      if (tokens.length < 3) throw new Error('Usage: mv rd, rs');
      const rdStr = tokens[1];
      const rsStr = tokens[2];
      return assembleLine(`addi ${rdStr}, ${rsStr}, 0`, currentAddress, labels);
    }

    if (instName === 'j') {
      // j label -> jal x0, label
      if (tokens.length < 2) throw new Error('Usage: j label_or_branch');
      const target = tokens[1];
      return assembleLine(`jal x0, ${target}`, currentAddress, labels);
    }

    if (instName === 'nop') {
      // nop -> addi x0, x0, 0
      return assembleLine('addi x0, x0, 0', currentAddress, labels);
    }

    if (instName === 'beqz') {
      // beqz rs, label -> beq rs, x0, label
      if (tokens.length < 3) throw new Error('Usage: beqz rs, label');
      return assembleLine(`beq ${tokens[1]}, x0, ${tokens[2]}`, currentAddress, labels);
    }

    if (instName === 'bnez') {
      // bnez rs, label -> bne rs, x0, label
      if (tokens.length < 3) throw new Error('Usage: bnez rs, label');
      return assembleLine(`bne ${tokens[1]}, x0, ${tokens[2]}`, currentAddress, labels);
    }

    // 2. MAIN RV32I MAPS
    // R-TYPE: OP_CODE = "0110011"
    const isRType = ['add', 'sub', 'sll', 'slt', 'sltu', 'xor', 'srl', 'sra', 'or', 'and'].includes(instName);
    if (isRType) {
      if (tokens.length < 4) throw new Error(`Usage: ${instName} rd, rs1, rs2`);
      const rd = parseRegister(tokens[1]);
      const rs1 = parseRegister(tokens[2]);
      const rs2 = parseRegister(tokens[3]);
      
      const opcode_bin = '0110011';
      let funct3_bin = '000';
      let funct7_bin = '0000000';

      switch (instName) {
        case 'add':  funct3_bin = '000'; funct7_bin = '0000000'; break;
        case 'sub':  funct3_bin = '000'; funct7_bin = '0100000'; break;
        case 'sll':  funct3_bin = '001'; funct7_bin = '0000000'; break;
        case 'slt':  funct3_bin = '010'; funct7_bin = '0000000'; break;
        case 'sltu': funct3_bin = '011'; funct7_bin = '0000000'; break;
        case 'xor':  funct3_bin = '100'; funct7_bin = '0000000'; break;
        case 'srl':  funct3_bin = '101'; funct7_bin = '0000000'; break;
        case 'sra':  funct3_bin = '101'; funct7_bin = '0100000'; break;
        case 'or':   funct3_bin = '110'; funct7_bin = '0000000'; break;
        case 'and':  funct3_bin = '111'; funct7_bin = '0000000'; break;
      }

      const bin = funct7_bin + 
                  toSignedBinary(rs2, 5) + 
                  toSignedBinary(rs1, 5) + 
                  funct3_bin + 
                  toSignedBinary(rd, 5) + 
                  opcode_bin;

      return {
        binary: bin,
        hex: binToHex32(bin),
        opcode: opcode_bin,
        rd, rs1, rs2,
        funct3: parseInt(funct3_bin, 2),
        funct7: parseInt(funct7_bin, 2),
        imm: 0,
        type: 'R',
        assembly: `${instName} x${rd}, x${rs1}, x${rs2}`,
      };
    }

    // I-TYPE ARITHMETIC: OP_CODE = "0010011"
    const isITypeArith = ['addi', 'slli', 'srli', 'srai', 'slti', 'sltiu', 'xori', 'ori', 'andi'].includes(instName);
    if (isITypeArith) {
      if (tokens.length < 4) throw new Error(`Usage: ${instName} rd, rs1, immediate`);
      const rd = parseRegister(tokens[1]);
      const rs1 = parseRegister(tokens[2]);
      
      // Immediate parsing supporting base 10, base 16 (0x), base 2 (0b)
      let rawImmVal = 0;
      const rawToken = tokens[3];
      if (rawToken.startsWith('0x') || rawToken.startsWith('0X')) {
        rawImmVal = parseInt(rawToken, 16);
      } else if (rawToken.startsWith('0b') || rawToken.startsWith('0B')) {
        rawImmVal = parseInt(rawToken.substring(2), 2);
      } else {
        rawImmVal = parseInt(rawToken, 10);
      }

      const opcode_bin = '0010011';
      let funct3_bin = '000';
      let imm_bits = 12;

      // Special shifts
      let imm_bin = '';
      if (instName === 'slli' || instName === 'srli' || instName === 'srai') {
        const shamt = rawImmVal & 0x1F; // 5-bit shift amount
        const funct7_prefix = instName === 'srai' ? '0100000' : '0000000';
        imm_bin = funct7_prefix + toSignedBinary(shamt, 5);
        funct3_bin = instName === 'slli' ? '001' : '101';
      } else {
        imm_bin = toSignedBinary(rawImmVal, 12);
        switch (instName) {
          case 'addi':  funct3_bin = '000'; break;
          case 'slti':  funct3_bin = '010'; break;
          case 'sltiu': funct3_bin = '011'; break;
          case 'xori':  funct3_bin = '100'; break;
          case 'ori':   funct3_bin = '110'; break;
          case 'andi':  funct3_bin = '111'; break;
        }
      }

      const bin = imm_bin + 
                  toSignedBinary(rs1, 5) + 
                  funct3_bin + 
                  toSignedBinary(rd, 5) + 
                  opcode_bin;

      return {
        binary: bin,
        hex: binToHex32(bin),
        opcode: opcode_bin,
        rd, rs1, rs2: 0,
        funct3: parseInt(funct3_bin, 2),
        funct7: 0,
        imm: rawImmVal,
        type: 'I',
        assembly: `${instName} x${rd}, x${rs1}, ${rawImmVal}`,
      };
    }

    // I-TYPE LOAD: OP_CODE = "0000011"
    // Format: lw rd, offset(rs1)
    const isLoad = ['lw', 'lb', 'lh', 'lbu', 'lhu'].includes(instName);
    if (isLoad) {
      if (tokens.length < 3) throw new Error(`Usage: ${instName} rd, offset(rs1)`);
      const rd = parseRegister(tokens[1]);
      
      // Parse offset(rs1) -> e.g. "4(sp)" or "0(x2)" or "offset"
      const rest = tokens[2].trim();
      const match = rest.match(/^(-?\d+|0x[a-fA-F0-9]+)\s*\(([^)]+)\)$/);
      
      let immVal = 0;
      let rs1 = 0;

      if (match) {
        const immStr = match[1];
        const rs1Str = match[2];
        immVal = immStr.startsWith('0x') ? parseInt(immStr, 16) : parseInt(immStr, 10);
        rs1 = parseRegister(rs1Str);
      } else {
        // Assume direct register without offset, or immediate offsets
        throw new Error(`Invalid address syntax: "${rest}". Correct formatting: 8(sp) or 0(x5)`);
      }

      const opcode_bin = '0000011';
      let funct3_bin = '010'; // lw
      switch (instName) {
        case 'lb':  funct3_bin = '000'; break;
        case 'lh':  funct3_bin = '001'; break;
        case 'lw':  funct3_bin = '010'; break;
        case 'lbu': funct3_bin = '100'; break;
        case 'lhu': funct3_bin = '101'; break;
      }

      const bin = toSignedBinary(immVal, 12) + 
                  toSignedBinary(rs1, 5) + 
                  funct3_bin + 
                  toSignedBinary(rd, 5) + 
                  opcode_bin;

      return {
        binary: bin,
        hex: binToHex32(bin),
        opcode: opcode_bin,
        rd, rs1, rs2: 0,
        funct3: parseInt(funct3_bin, 2),
        funct7: 0,
        imm: immVal,
        type: 'I',
        assembly: `${instName} x${rd}, ${immVal}(x${rs1})`,
      };
    }

    // S-TYPE STORE: OP_CODE = "0100011"
    // Format: sw rs2, offset(rs1)
    const isStore = ['sw', 'sb', 'sh'].includes(instName);
    if (isStore) {
      if (tokens.length < 3) throw new Error(`Usage: ${instName} rs2, offset(rs1)`);
      const rs2 = parseRegister(tokens[1]);
      
      const rest = tokens[2].trim();
      const match = rest.match(/^(-?\d+|0x[a-fA-F0-9]+)\s*\(([^)]+)\)$/);
      
      let immVal = 0;
      let rs1 = 0;

      if (match) {
        const immStr = match[1];
        const rs1Str = match[2];
        immVal = immStr.startsWith('0x') ? parseInt(immStr, 16) : parseInt(immStr, 10);
        rs1 = parseRegister(rs1Str);
      } else {
        throw new Error(`Invalid address syntax: "${rest}". Correct formatting: 4(x8)`);
      }

      const opcode_bin = '0100011';
      let funct3_bin = '010'; // sw
      switch (instName) {
        case 'sb': funct3_bin = '000'; break;
        case 'sh': funct3_bin = '001'; break;
        case 'sw': funct3_bin = '010'; break;
      }

      const imm_bin = toSignedBinary(immVal, 12);
      const imm_11_5 = imm_bin.substring(0, 7);
      const imm_4_0 = imm_bin.substring(7, 12);

      const bin = imm_11_5 + 
                  toSignedBinary(rs2, 5) + 
                  toSignedBinary(rs1, 5) + 
                  funct3_bin + 
                  imm_4_0 + 
                  opcode_bin;

      return {
        binary: bin,
        hex: binToHex32(bin),
        opcode: opcode_bin,
        rd: 0, rs1, rs2,
        funct3: parseInt(funct3_bin, 2),
        funct7: 0,
        imm: immVal,
        type: 'S',
        assembly: `${instName} x${rs2}, ${immVal}(x${rs1})`,
      };
    }

    // B-TYPE BRANCH: OP_CODE = "1100011"
    // Format: beq rs1, rs2, label
    const isBranch = ['beq', 'bne', 'blt', 'bge', 'bltu', 'bgeu'].includes(instName);
    if (isBranch) {
      if (tokens.length < 4) throw new Error(`Usage: ${instName} rs1, rs2, label_or_imm`);
      const rs1 = parseRegister(tokens[1]);
      const rs2 = parseRegister(tokens[2]);
      
      const labelToken = tokens[3];
      let offset = 0;

      if (labels[labelToken] !== undefined) {
        // Byte-level offset from current program counter
        offset = labels[labelToken] - currentAddress;
      } else {
        // Try parsed integer offset directly
        offset = parseInt(labelToken, 10);
        if (isNaN(offset)) {
          throw new Error(`Undefined label or invalid branch offset: "${labelToken}"`);
        }
      }

      const opcode_bin = '1100011';
      let funct3_bin = '000';
      switch (instName) {
        case 'beq':  funct3_bin = '000'; break;
        case 'bne':  funct3_bin = '001'; break;
        case 'blt':  funct3_bin = '100'; break;
        case 'bge':  funct3_bin = '101'; break;
        case 'bltu': funct3_bin = '110'; break;
        case 'bgeu': funct3_bin = '111'; break;
      }

      const imm_bin = toSignedBinary(offset, 13); // Branches contain 13-bit signed offset (bit 0 is always 0)
      
      // imm_bin layout: imm[12] | imm[10:5] | rs2 | rs1 | funct3 | imm[4:1] | imm[11] | opcode
      // index positions inside imm_bin (which is length 13):
      // imm_bin = [12] [11] [10] [9] [8] [7] [6] [5] [4] [3] [2] [1] [0]
      // index:     0    1    2   3   4   5   6   7   8   9   10  11  12
      const imm_12 = imm_bin[0];
      const imm_11 = imm_bin[1];
      const imm_10_5 = imm_bin.substring(2, 8);
      const imm_4_1 = imm_bin.substring(8, 12);

      const bin = imm_12 + 
                  imm_10_5 + 
                  toSignedBinary(rs2, 5) + 
                  toSignedBinary(rs1, 5) + 
                  funct3_bin + 
                  imm_4_1 + 
                  imm_11 + 
                  opcode_bin;

      return {
        binary: bin,
        hex: binToHex32(bin),
        opcode: opcode_bin,
        rd: 0, rs1, rs2,
        funct3: parseInt(funct3_bin, 2),
        funct7: 0,
        imm: offset,
        type: 'B',
        assembly: `${instName} x${rs1}, x${rs2}, ${offset} (label "${labelToken}")`,
      };
    }

    // J-TYPE JAL: OP_CODE = "1101111"
    // Format: jal rd, label
    if (instName === 'jal') {
      if (tokens.length < 3) throw new Error('Usage: jal rd, label_or_imm');
      const rd = parseRegister(tokens[1]);
      const labelToken = tokens[2];
      let offset = 0;

      if (labels[labelToken] !== undefined) {
        offset = labels[labelToken] - currentAddress;
      } else {
        offset = parseInt(labelToken, 10);
        if (isNaN(offset)) {
          throw new Error(`Undefined label or invalid jump target: "${labelToken}"`);
        }
      }

      const opcode_bin = '1101111';
      const imm_bin = toSignedBinary(offset, 21); // 21-bit signed immediate (bit 0 is always 0)
      
      // imm_bin layout (21 bits: 20 down to 0):
      // indices: imm[20] | imm[10:1] | imm[11] | imm[19:12]
      // String char positions of imm_bin (length 21):
      // pos 0: imm[20]
      // pos 1: imm[19] ... pos 8: imm[12] -> offset imm_19_12
      // pos 9: imm[11]
      // pos 10 to 19: imm[10] to imm[1]
      // pos 20: imm[0] (0)
      const imm_20 = imm_bin[0];
      const imm_19_12 = imm_bin.substring(1, 9);
      const imm_11 = imm_bin[9];
      const imm_10_1 = imm_bin.substring(10, 20);

      const bin = imm_20 + 
                  imm_10_1 + 
                  imm_11 + 
                  imm_19_12 + 
                  toSignedBinary(rd, 5) + 
                  opcode_bin;

      return {
        binary: bin,
        hex: binToHex32(bin),
        opcode: opcode_bin,
        rd, rs1: 0, rs2: 0,
        funct3: 0,
        funct7: 0,
        imm: offset,
        type: 'J',
        assembly: `jal x${rd}, ${offset} (label "${labelToken}")`,
      };
    }

    // I-TYPE JALR: OP_CODE = "1100117" -> wait opcode is standard 1100111
    // Format: jalr rd, offset(rs1)
    if (instName === 'jalr') {
      if (tokens.length < 4) throw new Error('Usage: jalr rd, rs1, offset');
      const rd = parseRegister(tokens[1]);
      const rs1 = parseRegister(tokens[2]);
      const immVal = parseInt(tokens[3], 10);

      const opcode_bin = '1100111';
      const funct3_bin = '000';
      const bin = toSignedBinary(immVal, 12) + 
                  toSignedBinary(rs1, 5) + 
                  funct3_bin + 
                  toSignedBinary(rd, 5) + 
                  opcode_bin;

      return {
        binary: bin,
        hex: binToHex32(bin),
        opcode: opcode_bin,
        rd, rs1, rs2: 0,
        funct3: 0,
        funct7: 0,
        imm: immVal,
        type: 'I',
        assembly: `jalr x${rd}, x${rs1}, ${immVal}`,
      };
    }

    // U-TYPE LUI: OP_CODE = "0110117"
    // Format: lui rd, immediate
    if (instName === 'lui' || instName === 'auipc') {
      if (tokens.length < 3) throw new Error(`Usage: ${instName} rd, immediate`);
      const rd = parseRegister(tokens[1]);
      
      let rawImmVal = 0;
      const rawToken = tokens[2];
      if (rawToken.startsWith('0x') || rawToken.startsWith('0X')) {
        rawImmVal = parseInt(rawToken, 16);
      } else {
        rawImmVal = parseInt(rawToken, 10);
      }

      const opcode_bin = instName === 'lui' ? '0110117' : '0010117'; // mapped matching control_unit RTL
      
      // Upper 20 bits of the parsed value
      // Standard LUI splits immediate by shifting 12 down or directly loading
      const upper20 = (rawImmVal & 0xFFFFF);
      const bin = toSignedBinary(upper20, 20) + 
                  toSignedBinary(rd, 5) + 
                  opcode_bin;

      return {
        binary: bin,
        hex: binToHex32(bin),
        opcode: opcode_bin,
        rd, rs1: 0, rs2: 0,
        funct3: 0,
        funct7: 0,
        imm: rawImmVal << 12,
        type: 'U',
        assembly: `${instName} x${rd}, ${rawImmVal}`,
      };
    }

    throw new Error(`Unsupported or unknown RISC-V instruction mnemonic: "${instName}"`);
  } catch (err: any) {
    return defaultInstruction(err.message || 'Assembly syntax error');
  }
}

export function compileAssembly(programText: string): { 
  lines: AssemblyLine[];
  errors: string[];
  labels: { [key: string]: number };
} {
  const rawLines = programText.split('\n');
  const cleanLines: { rawIndex: number; text: string; label?: string }[] = [];
  const labels: { [key: string]: number } = {};
  const errors: string[] = [];

  let currentAddress = 0;

  // First pass: strip comments and map all label offset points
  for (let i = 0; i < rawLines.length; i++) {
    let raw = rawLines[i].trim();
    
    // Strip comments (starts with # or ;)
    const commentIdx = raw.indexOf('#');
    const semiIdx = raw.indexOf(';');
    let splitIdx = -1;
    if (commentIdx !== -1 && semiIdx !== -1) {
      splitIdx = Math.min(commentIdx, semiIdx);
    } else {
      splitIdx = commentIdx !== -1 ? commentIdx : semiIdx;
    }
    if (splitIdx !== -1) {
      raw = raw.substring(0, splitIdx).trim();
    }

    if (!raw) continue;

    // Check if line contains a label (ends with :)
    const labelMatch = raw.match(/^([a-zA-Z_][a-zA-Z0-9_]*)\s*:/);
    if (labelMatch) {
      const labelName = labelMatch[1];
      labels[labelName] = currentAddress;
      
      const remainingCode = raw.substring(labelMatch[0].length).trim();
      if (remainingCode) {
        cleanLines.push({
          rawIndex: i,
          text: remainingCode,
        });
        currentAddress += 4;
      }
    } else {
      cleanLines.push({
        rawIndex: i,
        text: raw,
      });
      currentAddress += 4;
    }
  }

  // Second pass: compile and decode every clean assembly instruction block
  const lines: AssemblyLine[] = [];
  let addr = 0;

  for (const line of cleanLines) {
    const decoded = assembleLine(line.text, addr, labels);
    
    if (decoded.error) {
      errors.push(`Line ${line.rawIndex + 1}: ${decoded.error} | "${line.text}"`);
    }

    lines.push({
      address: addr,
      assembly: line.text,
      hex: decoded.hex,
      decoded,
    });
    addr += 4;
  }

  return { lines, errors, labels };
}
