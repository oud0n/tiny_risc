/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState } from 'react';
import { CpuState } from '../types';
import { Terminal, Cpu, Database, Disc } from 'lucide-react';

interface MemoryViewProps {
  state: CpuState;
  onSetMemory?: (addr: number, val: number) => void;
}

export const MemoryView: React.FC<MemoryViewProps> = ({ state, onSetMemory }) => {
  const [addrInput, setAddrInput] = useState('');
  const [valInput, setValInput] = useState('');
  const [inspectAddr, setInspectAddr] = useState<number | null>(null);

  const ramKeys = Object.keys(state.memory).map(Number).sort((a, b) => a - b);
  const ledsByte = state.memory_io.leds;
  const sevenSegVal = state.memory_io.seven_seg;
  const lcdText = state.memory_io.lcd_text;

  const handleSub = (e: React.FormEvent) => {
    e.preventDefault();
    if (!onSetMemory) return;
    const a = parseInt(addrInput, 10);
    const v = parseInt(valInput, 10);
    if (!isNaN(a) && !isNaN(v)) {
      onSetMemory(a, v);
      setInspectAddr(a);
      setAddrInput('');
      setValInput('');
    }
  };

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
      {/* COLUMN 1: INTERACTIVE HARDWARE BOARD (LEDs, 7seg, LCD Mapped via IO) */}
      <div className="bg-slate-900 text-slate-100 rounded-2xl p-6 shadow-md border border-slate-800 flex flex-col justify-between">
        <div>
          <div className="flex justify-between items-center mb-4 border-b border-slate-800 pb-3">
            <h3 className="text-sm font-semibold tracking-wide text-indigo-300 flex items-center gap-2">
              <Cpu size={16} />
              Memory-Mapped IO Peripheral Board
            </h3>
            <span className="text-[10px] bg-slate-800 px-2 py-0.5 rounded-full text-slate-400 font-mono">
              BUS 0x4000-0x400C
            </span>
          </div>

          <div className="space-y-6">
            {/* 1. MAPPED LED BULBS PIN-OUT */}
            <div className="bg-slate-950/40 p-4 rounded-xl border border-slate-800/60">
              <span className="text-[10px] text-slate-400 font-bold block mb-2 uppercase.tracking-wider">
                LED Indicator Strip (mapped at 0x4000)
              </span>
              <div className="flex justify-between items-center px-2">
                {Array.from({ length: 8 }).map((_, idx) => {
                  const bitIdx = 7 - idx; // MSB layout
                  const bitOn = (ledsByte & (1 << bitIdx)) !== 0;

                  return (
                    <div key={bitIdx} className="flex flex-col items-center gap-1.5 step-bit">
                      <div className={`w-5 h-5 rounded-full border transform transition-all duration-300 ${
                        bitOn 
                          ? "bg-rose-500 border-rose-300 shadow-[0_0_12px_rgba(244,63,94,0.8)] scale-110" 
                          : "bg-slate-800 border-slate-700 shadow-inner"
                      }`} />
                      <span className="text-[8px] font-mono text-slate-500">D{bitIdx}</span>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* 2. MAPPED DIGITAL 7-SEGMENT SCREEN */}
            <div className="grid grid-cols-2 gap-4">
              <div className="bg-slate-950/40 p-4 rounded-xl border border-slate-800/60 flex flex-col justify-center">
                <span className="text-[10px] text-slate-400 font-bold block mb-1.5 uppercase tracking-wider">
                  7-SEG Mapped Display (0x4004)
                </span>
                <div className="bg-slate-950 border border-red-950/40 px-3 py-2.5 rounded-lg flex items-center justify-center font-mono">
                  <span className="text-red-500 text-2xl font-bold tracking-widest drop-shadow-[0_0_4px_rgba(239,68,68,0.5)]">
                    {sevenSegVal.toString().padStart(6, '0')}
                  </span>
                </div>
              </div>

              {/* 3. HARDWARE RAW STATS INFO */}
              <div className="bg-slate-950/40 p-4 rounded-xl border border-slate-800/60 text-left text-xs space-y-1 text-slate-400 font-mono">
                <span className="text-[10px] text-indigo-400 font-bold block mb-1 uppercase tracking-wider">
                  Signal Debug Status
                </span>
                <div>LED byte: {ledsByte} (0b{ledsByte.toString(2).padStart(8, '0')})</div>
                <div>7seg Dec: {sevenSegVal}</div>
                <div>7seg Hex: 0x{sevenSegVal.toString(16).toUpperCase()}</div>
              </div>
            </div>

            {/* 4. TEXT CONTINUOUS ASCII PRINT LCD TERMINAL */}
            <div>
              <span className="text-[10px] text-slate-400 font-bold block mb-1.5 uppercase tracking-wider">
                ASCII Liquid Crystal Monitor Mapped at (0x4008)
              </span>
              <div className="bg-black/80 font-mono border border-slate-800 p-3 rounded-xl min-h-[70px] max-h-[110px] overflow-y-auto text-left text-xs text-emerald-400 ring-1 ring-emerald-950 flex flex-col justify-end">
                {lcdText ? (
                  <pre className="whitespace-pre-wrap">{lcdText}</pre>
                ) : (
                  <span className="text-slate-600 block italic text-center text-[11px] my-auto">
                    LCD terminal waiting for written characters...
                  </span>
                )}
              </div>
            </div>
          </div>
        </div>

        <div className="text-[9px] text-slate-500 text-center mt-4 border-t border-slate-800/50 pt-3">
          Assembly code triggers writes using: <code className="text-indigo-400">sw t0, 0(s0)</code> (where s0 points to 16384 decimal / 0x4000)
        </div>
      </div>

      {/* COLUMN 2: DATA RAM MEMORY VIEWER */}
      <div className="bg-white border border-slate-100 rounded-2xl p-6 shadow-sm flex flex-col justify-between">
        <div>
          <div className="flex justify-between items-center mb-4 border-b border-slate-100 pb-3">
            <h3 className="text-sm font-semibold text-slate-900 flex items-center gap-2">
              <Database size={16} className="text-blue-500" />
              Dynamic Address RAM Workspace
            </h3>
            <span className="text-[10px] text-slate-400 font-mono">RAM Size: {ramKeys.length} cell(s)</span>
          </div>

          <div className="space-y-4">
            {/* Memory cells list */}
            <div className="border border-slate-100 rounded-xl overflow-hidden">
              <div className="grid grid-cols-3 bg-slate-50/50 px-4 py-1.5 text-[10px] font-bold text-slate-500 border-b border-slate-100">
                <span>Address (Decimal)</span>
                <span>Address (HEX)</span>
                <span>Stored Value (Int32)</span>
              </div>
              <div className="max-h-[160px] overflow-y-auto divide-y divide-slate-50 font-mono text-xs">
                {ramKeys.length > 0 ? (
                  ramKeys.map((addr) => {
                    const mappedVal = state.memory[addr];
                    const isStackPointer = addr === state.registers['x2'];
                    return (
                      <div key={addr} className={`grid grid-cols-3 px-4 py-2 hover:bg-slate-50/30 text-left ${
                        isStackPointer ? "bg-amber-50/40 text-amber-900" : "text-slate-700"
                      }`}>
                        <span className="flex items-center gap-1">
                          {addr}
                          {isStackPointer && <span className="text-[8px] bg-amber-100 px-1 py-0.2 rounded text-amber-700">SP (x2)</span>}
                        </span>
                        <span>0x{addr.toString(16).toUpperCase()}</span>
                        <span className="font-semibold text-slate-900">{mappedVal}</span>
                      </div>
                    );
                  })
                ) : (
                  <div className="p-8 text-center text-xs text-slate-400 italic">
                    All General Data RAM initialized to 0. Execute store instructions (e.g. sw) to write variables!
                  </div>
                )}
              </div>
            </div>

            {/* Quick Memory Setter */}
            {onSetMemory && (
              <form onSubmit={handleSub} className="bg-slate-50 p-3 rounded-xl border border-slate-100">
                <span className="text-[10px] block font-bold text-slate-500 mb-2 uppercase tracking-wide">
                  Inject/Override Memory Content manually
                </span>
                <div className="flex gap-2">
                  <input
                    type="number"
                    placeholder="Address (e.g. 1000)"
                    value={addrInput}
                    onChange={(e) => setAddrInput(e.target.value)}
                    className="w-1/2 text-xs border border-slate-200 bg-white rounded-lg px-2.5 py-1.5 focus:outline-indigo-500 font-mono text-slate-800"
                  />
                  <input
                    type="number"
                    placeholder="Value"
                    value={valInput}
                    onChange={(e) => setValInput(e.target.value)}
                    className="w-1/2 text-xs border border-slate-200 bg-white rounded-lg px-2.5 py-1.5 focus:outline-indigo-500 font-mono text-slate-800"
                  />
                  <button
                    type="submit"
                    className="text-xs bg-indigo-600 hover:bg-indigo-700 text-white font-medium px-4 py-1.5 rounded-lg active:scale-95 transition-all"
                  >
                    Write
                  </button>
                </div>
              </form>
            )}
          </div>
        </div>

        <div className="text-[10px] text-slate-400 mt-4">
          Data RAM holds local state and function parameters. Registers index x2 points to top stack boundary by default.
        </div>
      </div>
    </div>
  );
};
