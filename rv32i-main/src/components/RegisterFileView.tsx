/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React from 'react';
import { CpuState } from '../types';

interface RegisterFileViewProps {
  state: CpuState;
}

// Map indices to architectural symbolic names
export const SYMBOLIC_REG_NAMES = [
  "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
  "s0/fp", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
  "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
  "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"
];

export const RegisterFileView: React.FC<RegisterFileViewProps> = ({ state }) => {
  const sig = state.active_signals;
  const rd = state.active_signals.active_signals?.rd || 0;
  const rs1 = state.active_signals.active_signals?.rs1 || 0;
  const rs2 = state.active_signals.active_signals?.rs2 || 0;
  const regWrite = sig.control.reg_write;

  return (
    <div className="bg-white border border-slate-100 rounded-2xl p-6 shadow-sm">
      <div className="mb-4">
        <h3 className="text-sm font-semibold text-slate-900">Register File (x0 - x31)</h3>
        <p className="text-xs text-slate-500">Live 32-bit register states with clock-cycle write highlights</p>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-2">
        {Array.from({ length: 32 }).map((_, index) => {
          const regKey = `x${index}`;
          const value = state.registers[regKey] || 0;
          const name = SYMBOLIC_REG_NAMES[index];

          // Check if this register is active in current datapath simulation step
          const isRd = regWrite && index === rd && index !== 0;
          const isRs1 = index === rs1 && index !== 0;
          const isRs2 = index === rs2 && index !== 0;

          let ringStyle = "border-slate-100 bg-slate-50/50";
          let labelBadge = <span className="text-[9px] text-slate-400 font-normal">x{index}</span>;

          if (isRd) {
            ringStyle = "border-emerald-300 bg-emerald-50 text-emerald-950 animate-pulse ring-2 ring-emerald-100";
            labelBadge = <span className="text-[9px] text-emerald-700 font-semibold px-1 py-0.2 bg-emerald-100 rounded">x{index} (Write RD)</span>;
          } else if (isRs1 && isRs2) {
            ringStyle = "border-amber-300 bg-amber-50 text-amber-950 ring-2 ring-amber-100";
            labelBadge = <span className="text-[9px] text-amber-700 font-medium px-1 py-0.2 bg-amber-100 rounded">x{index} (Read RS1/2)</span>;
          } else if (isRs1) {
            ringStyle = "border-indigo-300 bg-indigo-50/80 text-indigo-950 ring-2 ring-indigo-100";
            labelBadge = <span className="text-[9px] text-indigo-700 font-medium px-1 py-0.2 bg-indigo-100 rounded">x{index} (Read RS1)</span>;
          } else if (isRs2) {
            ringStyle = "border-violet-300 bg-violet-50/80 text-violet-950 ring-2 ring-violet-100";
            labelBadge = <span className="text-[9px] text-purple-700 font-medium px-1 py-0.2 bg-purple-100 rounded">x{index} (Read RS2)</span>;
          }

          const hexValue = `0x${value.toString(16).toUpperCase()}`;

          return (
            <div key={regKey} className={`flex flex-col p-2 rounded-xl border text-left transition-all duration-200 ${ringStyle}`}>
              <div className="flex justify-between items-center mb-1">
                {labelBadge}
                <span className="text-[10px] text-slate-500 font-semibold font-mono">{name}</span>
              </div>
              <div className="font-mono text-xs font-semibold text-slate-900 truncate" title={`${value} (decimal)`}>
                {value}
              </div>
              <div className="text-[9px] text-slate-400 font-mono">
                {hexValue}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};
