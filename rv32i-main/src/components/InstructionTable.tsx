/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React from 'react';
import { AssemblyLine } from '../types';
import { Play, CornerDownRight } from 'lucide-react';

interface InstructionTableProps {
  lines: AssemblyLine[];
  currentPC: number;
  onSetPC?: (pc: number) => void;
}

export const InstructionTable: React.FC<InstructionTableProps> = ({ lines, currentPC, onSetPC }) => {

  // Helper to color bits based on RISC-V type
  const renderBitSegments = (bin: string, type: string) => {
    if (bin.length !== 32) return <span className="text-slate-400 font-mono text-[9px]">{bin}</span>;

    const op = bin.substring(25, 32);   // [6:0]
    const rd = bin.substring(20, 25);   // [11:7]
    const f3 = bin.substring(17, 20);   // [14:12]
    const rs1 = bin.substring(12, 17);  // [19:15]
    const rs2 = bin.substring(7, 12);   // [24:20]
    const f7 = bin.substring(0, 7);     // [31:25]
    const immI = bin.substring(0, 12);  // [31:20] immediate for I

    if (type === 'R') {
      return (
        <span className="font-mono text-[10px] tracking-tight whitespace-nowrap">
          <span className="text-slate-600" title="funct7">{f7}</span>
          <span className="text-amber-500" title="rs2">{rs2}</span>
          <span className="text-sky-500" title="rs1">{rs1}</span>
          <span className="text-emerald-500" title="funct3">{f3}</span>
          <span className="text-rose-500" title="rd">{rd}</span>
          <span className="text-indigo-500" title="opcode">{op}</span>
        </span>
      );
    }

    if (type === 'I') {
      return (
        <span className="font-mono text-[10px] tracking-tight whitespace-nowrap">
          <span className="text-amber-500" title="immediate">{immI}</span>
          <span className="text-sky-500" title="rs1">{rs1}</span>
          <span className="text-emerald-500" title="funct3">{f3}</span>
          <span className="text-rose-500" title="rd">{rd}</span>
          <span className="text-indigo-500" title="opcode">{op}</span>
        </span>
      );
    }

    // Default or simplified view for S/B/U/J
    return (
      <span className="font-mono text-[10px] tracking-tight whitespace-nowrap text-slate-500">
        <span className="text-amber-500" title="immediate-split">{bin.substring(0, 12)}</span>
        <span className="text-sky-500" title="registers-split">{bin.substring(12, 25)}</span>
        <span className="text-indigo-500" title="opcode">{bin.substring(25)}</span>
      </span>
    );
  };

  return (
    <div className="bg-white border border-slate-100 rounded-2xl p-6 shadow-sm flex flex-col justify-between h-full">
      <div>
        <div className="flex justify-between items-center mb-4 pb-3 border-b border-slate-100">
          <div>
            <h3 className="text-sm font-semibold text-slate-900">Program Instruction ROM</h3>
            <p className="text-xs text-slate-500">Trace instructions step-by-step through machine memory space</p>
          </div>
          <span className="text-[10px] font-bold bg-indigo-50 text-indigo-700 px-2.5 py-1 rounded-lg">
            PC Mapped: 0x{currentPC.toString(16).toUpperCase()}
          </span>
        </div>

        <div className="border border-slate-100 rounded-xl overflow-hidden">
          <div className="grid grid-cols-12 bg-slate-50/50 px-4 py-2 text-[10px] font-bold text-slate-500 border-b border-slate-100 text-left">
            <span className="col-span-1">State</span>
            <span className="col-span-2">Address</span>
            <span className="col-span-4">Assembly Code</span>
            <span className="col-span-2">Hex Bin</span>
            <span className="col-span-3">RISC-V Op Field Bits</span>
          </div>

          <div className="max-h-[360px] overflow-y-auto divide-y divide-slate-50">
            {lines.length > 0 ? (
              lines.map((line) => {
                const isActive = line.address === currentPC;
                return (
                  <div
                    key={line.address}
                    onClick={() => onSetPC && onSetPC(line.address)}
                    className={`grid grid-cols-12 px-4 py-2.5 items-center cursor-pointer transition-all text-xs font-mono text-left group ${
                      isActive 
                        ? "bg-indigo-50/70 border-l-4 border-indigo-600 text-slate-900 font-semibold" 
                        : "hover:bg-slate-50/35 border-l-4 border-transparent text-slate-600"
                    }`}
                  >
                    <span className="col-span-1 flex items-center justify-start">
                      {isActive ? (
                        <Play size={10} className="text-indigo-600 fill-indigo-600 animate-pulse" />
                      ) : (
                        <span className="w-1.5 h-1.5 rounded-full bg-slate-200 group-hover:bg-slate-400" />
                      )}
                    </span>
                    <span className="col-span-2 text-slate-400">
                      0x{line.address.toString(16).padStart(3, '0').toUpperCase()}
                    </span>
                    <span className={`col-span-4 select-all text-[12px] truncate ${isActive ? "text-indigo-950 font-bold" : "text-slate-800"}`}>
                      {line.assembly}
                    </span>
                    <span className="col-span-2 text-slate-500 text-[11px]">
                      0x{line.hex}
                    </span>
                    <span className="col-span-3 flex justify-end">
                      {line.decoded ? renderBitSegments(line.decoded.binary, line.decoded.type) : 'RAW_BIN'}
                    </span>
                  </div>
                );
              })
            ) : (
              <div className="p-12 text-center text-xs text-slate-400 italic font-sans">
                Compile assembly code in the editor above to load instructions into CPU Instruction ROM!
              </div>
            )}
          </div>
        </div>
      </div>

      <div className="mt-4 flex flex-wrap gap-2 text-[10px] text-slate-400 pt-3 border-t border-slate-100">
        <span className="font-semibold block w-full text-slate-500 mb-0.5">Segment Legend:</span>
        <span className="flex items-center gap-1">
          <span className="w-1.5 h-1.5 rounded-full bg-indigo-500" /> Opcode
        </span>
        <span className="flex items-center gap-1">
          <span className="w-1.5 h-1.5 rounded-full bg-rose-500" /> rd
        </span>
        <span className="flex items-center gap-1">
          <span className="w-1.5 h-1.5 rounded-full bg-emerald-500" /> funct3
        </span>
        <span className="flex items-center gap-1">
          <span className="w-1.5 h-1.5 rounded-full bg-sky-500" /> rs1
        </span>
        <span className="flex items-center gap-1">
          <span className="w-1.5 h-1.5 rounded-full bg-amber-500" /> rs2 / Immediate
        </span>
        <span className="flex items-center gap-1">
          <span className="w-1.5 h-1.5 rounded-full bg-slate-600" /> funct7
        </span>
      </div>
    </div>
  );
};
