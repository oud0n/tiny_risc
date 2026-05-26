/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React from 'react';
import { CpuState } from '../types';

interface CPUBlockDiagramProps {
  state: CpuState;
}

export const CPUBlockDiagram: React.FC<CPUBlockDiagramProps> = ({ state }) => {
  const sig = state.active_signals;
  const ctrl = sig.control;

  // Helpers to check states
  const isLui = ctrl.alu_op === 'LUI';
  const isBranchIdx = ctrl.branch;
  const isJumpIdx = ctrl.jump;
  const isWriteBackReg = ctrl.reg_write;

  // Format binary/hex views for display tooltips
  const pcHex = `0x${sig.pc.toString(16).toUpperCase()}`;
  const instHex = `0x${sig.instruction.toString(16).padStart(8, '0').toUpperCase()}`;
  const aluResHex = `0x${sig.alu_result.toString(16).toUpperCase()}`;
  const writeDataHex = `0x${sig.reg_write_data.toString(16).toUpperCase()}`;

  // Get bus highlight colors
  const activeColor = "stroke-[#6366f1] stroke-[3.5] drop-shadow-[0_0_8px_rgba(99,102,241,0.6)]";
  const inactiveColor = "stroke-[#cbd5e1] stroke-1.5 opacity-60";
  const controlActiveColor = "stroke-[#a855f7] stroke-[2] stroke-dasharray-[4,2] drop-shadow-[0_0_4px_rgba(168,85,247,0.5)]";
  const controlInactiveColor = "stroke-[#94a3b8] stroke-1 stroke-dasharray-[2,2] opacity-40";

  return (
    <div className="bg-white border border-slate-100 rounded-2xl p-6 shadow-sm flex flex-col items-center">
      <div className="w-full flex justify-between items-center mb-4">
        <div>
          <h3 className="text-sm font-semibold text-slate-900">Dynamic Datapath Logic Analyzer</h3>
          <p className="text-xs text-slate-500">Trace active signals flowing through the RV32I / RV31I single-cycle core</p>
        </div>
        <div className="flex gap-4 text-xs text-slate-600 bg-slate-50 p-2 rounded-lg border border-slate-100">
          <div className="flex items-center gap-1.5">
            <span className="w-2.5 h-2.5 rounded-full bg-indigo-500 shadow-sm shadow-indigo-200"></span>
            <span>Active Datapath</span>
          </div>
          <div className="flex items-center gap-1.5">
            <span className="w-2.5 h-2.5 rounded-full bg-purple-500 shadow-sm shadow-purple-200"></span>
            <span>Active Control</span>
          </div>
        </div>
      </div>

      <div className="relative w-full aspect-[850/460] min-h-[300px] border border-slate-100 rounded-xl overflow-hidden bg-slate-950/2">
        {/* SVG Drawing Canvas */}
        <svg viewBox="0 0 850 440" className="w-full h-full select-none" xmlns="http://www.w3.org/2000/svg">
          {/* DEFINES FOR MARKERS */}
          <defs>
            <marker id="arrow" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
              <path d="M 0 1 L 10 5 L 0 9 z" fill="#475569" />
            </marker>
            <marker id="arrow-active" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
              <path d="M 0 1 L 10 5 L 0 9 z" fill="#6366f1" />
            </marker>
            <marker id="arrow-control" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
              <path d="M 0 1 L 10 5 L 0 9 z" fill="#a855f7" />
            </marker>
          </defs>

          {/* BACKGROUND WIRES / BUSES */}
          {/* 1. PC to Instruction Memory Bus */}
          <path d="M 90 180 L 140 180" markerEnd="url(#arrow)" className={activeColor} />
          
          {/* 2. Instruction memory output split */}
          <path d="M 220 180 L 280 150" markerEnd="url(#arrow)" className={activeColor} />
          {/* Instr to Reg (rs2) */}
          <path d="M 220 180 L 240 180 L 240 190 L 280 190" markerEnd="url(#arrow)" className={activeColor} />
          {/* Instr to Imm Gen */}
          <path d="M 220 180 L 220 290 L 280 290" markerEnd="url(#arrow)" className={activeColor} />
          {/* Instr to Control Unit */}
          <path d="M 220 180 L 220 70 L 250 70" markerEnd="url(#arrow)" className={activeColor} />

          {/* 3. Control Unit active lines */}
          {/* RegWrite */}
          <path d="M 290 100 L 290 115 L 325 115 L 325 130" markerEnd="url(#arrow)" 
                className={ctrl.reg_write ? controlActiveColor : controlInactiveColor} />
          {/* ALUSrc */}
          <path d="M 320 80 L 420 80 L 420 200" markerEnd="url(#arrow)" 
                className={ctrl.alu_src ? controlActiveColor : controlInactiveColor} />
          {/* ALUControl */}
          <path d="M 330 60 L 500 60 L 500 130" markerEnd="url(#arrow)" 
                className={controlActiveColor} />
          {/* MemRead / MemWrite */}
          <path d="M 310 30 L 310 20 L 620 20 L 620 140" markerEnd="url(#arrow)" 
                className={(ctrl.mem_read || ctrl.mem_write) ? controlActiveColor : controlInactiveColor} />

          {/* 4. RegFile outputs to ALU / Mux */}
          {/* Read Data 1 to ALU Src A */}
          <path d="M 370 150 L 460 150" markerEnd="url(#arrow)" className={activeColor} />
          {/* Read Data 2 to Mux Input 0 */}
          <path d="M 370 190 L 410 190" markerEnd="url(#arrow)" className={!ctrl.alu_src ? activeColor : inactiveColor} />
          {/* Read Data 2 split below to Data Memory Write Data */}
          <path d="M 370 190 L 390 190 L 390 350 L 560 350 L 560 200 L 580 200" markerEnd="url(#arrow)" 
                className={ctrl.mem_write ? activeColor : inactiveColor} />

          {/* 5. Imm Gen output to Mux Input 1 */}
          <path d="M 370 290 L 420 290 L 420 220" markerEnd="url(#arrow)" className={ctrl.alu_src ? activeColor : inactiveColor} />

          {/* 6. Mux output to ALU Src B */}
          <path d="M 430 200 L 460 200" markerEnd="url(#arrow)" className={activeColor} />

          {/* 7. ALU result output branches */}
          {/* To DMEM Address */}
          <path d="M 540 170 L 580 170" markerEnd="url(#arrow)" className={activeColor} />
          {/* To WB Mux Input 0 (Bypasses DMEM) */}
          <path d="M 540 170 L 560 170 L 560 250 L 700 250" markerEnd="url(#arrow)" className={ctrl.mem_to_reg === '00' ? activeColor : inactiveColor} />

          {/* 8. Data memory output to WB Mux */}
          <path d="M 660 180 L 700 180" markerEnd="url(#arrow)" className={ctrl.mem_to_reg === '01' ? activeColor : inactiveColor} />

          {/* 9. PC+4 adder path to WB Mux */}
          <path d="M 65 220 L 65 390 L 680 390 L 680 280 L 700 280" markerEnd="url(#arrow)" className={ctrl.mem_to_reg === '10' ? activeColor : inactiveColor} />

          {/* 10. WB Mux output back loop to RegFile Write Data */}
          <path d="M 720 260 L 740 260 L 740 420 L 260 420 L 260 210 L 280 210" markerEnd="url(#arrow)" 
                className={isWriteBackReg ? activeColor : inactiveColor} />

          {/* 11. Branch Taken PC feedback loops */}
          <path d="M 325 320 L 325 380 L 15 380 L 15 180 L 40 180" markerEnd="url(#arrow)" 
                className={(isBranchIdx && state.active_signals.control.branch_taken) || isJumpIdx ? activeColor : inactiveColor} />


          {/* COMPONENT BOXES AND CARDS */}
          {/* PROGRAM COUNTER (PC) */}
          <g transform="translate(40, 140)">
            <rect width="50" height="80" rx="6" fill="#0f172a" stroke="#1e293b" strokeWidth="2" className="drop-shadow-sm" />
            <text x="25" y="30" fill="#f8fafc" fontSize="11" fontWeight="bold" textAnchor="middle">PC</text>
            <text x="25" y="55" fill="#38bdf8" fontSize="8" fontFamily="monospace" textAnchor="middle">{pcHex}</text>
          </g>

          {/* INSTRUCTION MEMORY (IMEM) */}
          <g transform="translate(140, 140)">
            <rect width="80" height="80" rx="8" fill="#1e293b" stroke="#334155" strokeWidth="2" />
            <text x="40" y="25" fill="#e2e8f0" fontSize="10" fontWeight="bold" textAnchor="middle">Instruction</text>
            <text x="40" y="38" fill="#e2e8f0" fontSize="10" fontWeight="bold" textAnchor="middle">ROM</text>
            <text x="40" y="60" fill="#a5b4fc" fontSize="8.5" fontFamily="monospace" textAnchor="middle">{instHex}</text>
          </g>

          {/* CONTROL UNIT */}
          <g transform="translate(250, 30)">
            <rect width="80" height="70" rx="8" fill="#581c87" stroke="#7e22ce" strokeWidth="2" />
            <text x="40" y="26" fill="#faf5ff" fontSize="10" fontWeight="extrabold" textAnchor="middle">Control Unit</text>
            <text x="40" y="42" fill="#d8b4fe" fontSize="8" textAnchor="middle" fontWeight="bold">OP: {sig.control.alu_op}</text>
            <text x="40" y="54" fill="#e9d5ff" fontSize="7.5" fontFamily="monospace" textAnchor="middle">
              {ctrl.reg_write ? "WE " : ""}{ctrl.alu_src ? "SRC " : ""}{ctrl.branch ? "BR " : ""}
            </text>
          </g>

          {/* REGISTER FILE */}
          <g transform="translate(280, 130)">
            <rect width="90" height="100" rx="8" fill="#1e1b4b" stroke="#312e81" strokeWidth="2" />
            <text x="45" y="22" fill="#e0e7ff" fontSize="10" fontWeight="bold" textAnchor="middle">Registers (x0-x31)</text>
            
            <text x="12" y="42" fill="#818cf8" fontSize="8" textAnchor="start">rs1: x{sig.rs1_val !== undefined ? state.active_signals.active_signals?.rs1 : '?'}</text>
            <text x="80" y="42" fill="#c7d2fe" fontSize="8" textAnchor="end">{sig.rs1_val}</text>

            <text x="12" y="62" fill="#818cf8" fontSize="8" textAnchor="start">rs2: x{sig.rs2_val !== undefined ? state.active_signals.active_signals?.rs2 : '?'}</text>
            <text x="80" y="62" fill="#c7d2fe" fontSize="8" textAnchor="end">{sig.rs2_val}</text>

            <rect x="5" y="75" width="80" height="18" rx="4" fill="#312e81" />
            <text x="45" y="87" fill="#a5b4fc" fontSize="7.5" textAnchor="middle">
              Write: x{state.active_signals.active_signals?.rd || '0'} ↚ {sig.reg_write_data}
            </text>
          </g>

          {/* IMMEDIATE GENERATION */}
          <g transform="translate(280, 260)">
            <rect width="90" height="60" rx="8" fill="#1e293b" stroke="#475569" strokeWidth="2" />
            <text x="45" y="22" fill="#cbd5e1" fontSize="10" fontWeight="bold" textAnchor="middle">Imm Generator</text>
            <text x="45" y="42" fill="#f1f5f9" fontSize="9.5" fontFamily="monospace" textAnchor="middle">
              {sig.imm_val}
            </text>
            <text x="45" y="52" fill="#94a3b8" fontSize="7" textAnchor="middle">
              {ctrl.alu_src ? "Type active" : "Unused"}
            </text>
          </g>

          {/* ALUSRC MUX */}
          <g transform="translate(410, 180)">
            <polygon points="0,0 20,10 20,40 0,50" fill="#334155" stroke="#475569" strokeWidth="1.5" />
            <text x="10" y="28" fill="#f1f5f9" fontSize="7.5" fontWeight="bold" textAnchor="middle" transform="rotate(90 10 28)">MUX</text>
            <text x="5" y="11" fill="#94a3b8" fontSize="6">0</text>
            <text x="5" y="43" fill="#94a3b8" fontSize="6">1</text>
          </g>

          {/* ALU THERMOMETER TRAPEZOID */}
          <g transform="translate(460, 130)">
            <polygon points="0,0 30,15 30,65 0,80 0,50 15,40 0,30" fill="#064e3b" stroke="#059669" strokeWidth="2.5" />
            <text x="40" y="44" fill="#ecfdf5" fontSize="12" fontWeight="extrabold" textAnchor="middle">ALU</text>
            <text x="36" y="56" fill="#a7f3d0" fontSize="8" fontWeight="bold" textAnchor="middle" fontFamily="monospace">
              {sig.control.alu_op}
            </text>
            <text x="12" y="72" fill="#f0fdf4" fontSize="8" fontFamily="monospace">{aluResHex}</text>
          </g>

          {/* DATA MEMORY (RAM) */}
          <g transform="translate(580, 140)">
            <rect width="80" height="80" rx="8" fill="#1e293b" stroke="#334155" strokeWidth="2" />
            <text x="40" y="25" fill="#94a3b8" fontSize="10" fontWeight="bold" textAnchor="middle">Data Memory</text>
            <text x="40" y="38" fill="#cbd5e1" fontSize="9" textAnchor="middle">RAM</text>
            <text x="40" y="58" fill="#f1f5f9" fontSize="8.5" fontFamily="monospace" textAnchor="middle">
              {ctrl.mem_read ? `Read: ${sig.mem_read_data}` : ctrl.mem_write ? `Write: ${sig.rs2_val}` : "Idle"}
            </text>
            <text x="40" y="70" fill="#94a3b8" fontSize="7" fontStyle="italic" textAnchor="middle">
              ADDR: {aluResHex}
            </text>
          </g>

          {/* WRITEBACK REG MUX */}
          <g transform="translate(700, 220)">
            <polygon points="0,0 20,10 20,70 0,80" fill="#334155" stroke="#475569" strokeWidth="1.5" />
            <text x="10" y="44" fill="#f1f5f9" fontSize="7.5" fontWeight="bold" textAnchor="middle" transform="rotate(90 10 44)">MUX</text>
            <text x="5" y="12" fill="#cbd5e1" fontSize="6">alu</text>
            <text x="5" y="44" fill="#cbd5e1" fontSize="6">mem</text>
            <text x="5" y="74" fill="#cbd5e1" fontSize="6">pc+4</text>
          </g>
        </svg>

        {/* Floating live inspection specs */}
        <div className="absolute top-2 left-2 bg-slate-900/90 backdrop-blur-md px-3 py-1.5 rounded-lg border border-slate-800 text-[10px] font-mono text-slate-300 flex flex-col gap-0.5 shadow-xl">
          <div><span className="text-slate-500">OPCODE: </span><span className="text-indigo-400">{sig.control.alu_control || sig.control.alu_op || '0x00'}</span></div>
          <div><span className="text-slate-500">IMM:   </span><span className="text-cyan-400">{sig.imm_val}</span></div>
          <div><span className="text-slate-500">ALU_R: </span><span className="text-emerald-400">{sig.alu_result}</span></div>
          <div><span className="text-slate-500">REG_W: </span><span className="text-purple-400">{writeDataHex}</span></div>
        </div>
      </div>
    </div>
  );
};
