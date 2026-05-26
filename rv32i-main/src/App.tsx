/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { useState, useEffect, useRef } from 'react';
import { 
  compileAssembly, 
  binToHex32 
} from './utils/riscv_assembler';
import { 
  createInitialState, 
  simulateCycle, 
  PREDEFINED_PROGRAMS 
} from './utils/riscv_simulator';
import { AssemblyLine, CpuState } from './types';
import { CPUBlockDiagram } from './components/CPUBlockDiagram';
import { RegisterFileView } from './components/RegisterFileView';
import { MemoryView } from './components/MemoryView';
import { InstructionTable } from './components/InstructionTable';
import { SVViewer } from './components/SVViewer';
import { 
  Play, 
  Pause, 
  RotateCcw, 
  ArrowRight, 
  ArrowLeft, 
  CheckCircle2, 
  AlertCircle,
  Code2, 
  FileCode2, 
  Wrench, 
  GraduationCap
} from 'lucide-react';

export default function App() {
  // Pre-load Fibonacci sample
  const [assemblyText, setAssemblyText] = useState(PREDEFINED_PROGRAMS.fibonacci.code);
  const [compiledLines, setCompiledLines] = useState<AssemblyLine[]>([]);
  const [compileErrors, setCompileErrors] = useState<string[]>([]);
  const [selectedTemplate, setSelectedTemplate] = useState('fibonacci');

  // CPU Simulator State
  const [cpuState, setCpuState] = useState<CpuState>(createInitialState());
  const [stateHistory, setStateHistory] = useState<CpuState[]>([]);
  const [isPlaying, setIsPlaying] = useState(false);
  const [playSpeed, setPlaySpeed] = useState(300); // clock speed ms interval

  const intervalRef = useRef<NodeJS.Timeout | null>(null);

  // Compile assembly on loaded template or user edit triggers
  const compileCurrentCode = () => {
    const { lines, errors } = compileAssembly(assemblyText);
    setCompiledLines(lines);
    setCompileErrors(errors);

    // Automatically load reset state
    const freshState = createInitialState();
    if (lines.length > 0) {
      // Decode first instruction for ready-to-execute signals highlight
      const firstLine = lines[0];
      if (firstLine.decoded && !firstLine.decoded.error) {
        freshState.active_signals.instruction = parseInt(firstLine.decoded.binary, 2);
        freshState.active_signals.active_signals = firstLine.decoded;
      }
    }
    setCpuState(freshState);
    setStateHistory([]);
    setIsPlaying(false);
  };

  // Compile on mount or template select
  useEffect(() => {
    compileCurrentCode();
  }, [selectedTemplate]);

  // Handle template selection
  const handleSelectTemplate = (key: string) => {
    setSelectedTemplate(key);
    if (PREDEFINED_PROGRAMS[key]) {
      setAssemblyText(PREDEFINED_PROGRAMS[key].code);
    }
  };

  // Run cycle logic
  const handleStepForward = () => {
    if (cpuState.halted || compiledLines.length === 0) {
      setIsPlaying(false);
      return;
    }

    // Save history state to allow backtracking (Stepping backward)
    setStateHistory((prev) => [...prev, cpuState]);

    const decodedInstructions = compiledLines.map((line) => line.decoded!).filter(Boolean);
    const nextState = simulateCycle(cpuState, decodedInstructions);
    
    // Inject decoded reference
    const activePcIndex = nextState.pc / 4;
    if (activePcIndex >= 0 && activePcIndex < compiledLines.length) {
      const currentDecoded = compiledLines[activePcIndex].decoded;
      if (currentDecoded) {
        nextState.active_signals.active_signals = currentDecoded;
      }
    }
    
    setCpuState(nextState);
  };

  // Reverse step logic (backtrack)
  const handleStepBackward = () => {
    if (stateHistory.length === 0) return;
    const previousState = stateHistory[stateHistory.length - 1];
    setCpuState(previousState);
    setStateHistory((prev) => prev.slice(0, -1));
  };

  // Reset core simulator
  const handleReset = () => {
    const freshState = createInitialState();
    if (compiledLines.length > 0 && compiledLines[0].decoded) {
      freshState.active_signals.instruction = parseInt(compiledLines[0].decoded.binary, 2);
      freshState.active_signals.active_signals = compiledLines[0].decoded;
    }
    setCpuState(freshState);
    setStateHistory([]);
    setIsPlaying(false);
  };

  // Play loop handler
  useEffect(() => {
    if (isPlaying) {
      intervalRef.current = setInterval(() => {
        setCpuState((current) => {
          if (current.halted || compiledLines.length === 0) {
            setIsPlaying(false);
            if (intervalRef.current) clearInterval(intervalRef.current);
            return current;
          }
          
          // Capture current prior to step
          setStateHistory((prev) => [...prev, current]);

          const decodedInstructions = compiledLines.map((line) => line.decoded!).filter(Boolean);
          const nextState = simulateCycle(current, decodedInstructions);
          
          const activePcIndex = nextState.pc / 4;
          if (activePcIndex >= 0 && activePcIndex < compiledLines.length) {
            const currentDecoded = compiledLines[activePcIndex].decoded;
            if (currentDecoded) {
              nextState.active_signals.active_signals = currentDecoded;
            }
          }

          return nextState;
        });
      }, playSpeed);
    } else {
      if (intervalRef.current) clearInterval(intervalRef.current);
    }

    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, [isPlaying, compiledLines, playSpeed]);

  // Handle direct memory injection
  const handleSetMemoryValue = (addr: number, val: number) => {
    setCpuState((prev) => {
      const nextMem = { ...prev.memory, [addr]: val };
      return { ...prev, memory: nextMem };
    });
  };

  // Calculate active line helper
  const currentLineIndex = cpuState.pc / 4;

  return (
    <div className="bg-slate-50 min-h-screen text-slate-800 font-sans pb-16">
      {/* HEADER SECTION */}
      <header className="bg-white border-b border-slate-100 py-5 px-6 sticky top-0 z-40 shadow-sm backdrop-blur-md bg-white/90">
        <div className="max-w-7xl mx-auto flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-indigo-600 to-indigo-400 flex items-center justify-center text-white shadow-md shadow-indigo-100">
              <Code2 size={20} className="animate-spin-slow" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className="text-xl font-bold tracking-tight text-slate-900">
                  RV32I / RV31I CPU Studio
                </span>
                <span className="text-[10px] font-semibold bg-emerald-50 text-emerald-700 px-2 py-0.5 rounded-full border border-emerald-200">
                  v1.2 Live Sim
                </span>
              </div>
              <p className="text-xs text-slate-500">
                Interactive RISC-V SystemVerilog assembly IDE, logic emulator, and synthesizable RTL viewer
              </p>
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <span className="text-xs font-semibold text-slate-500 mr-2 flex items-center gap-1">
              <GraduationCap size={14} /> Assembly Pre-sets:
            </span>
            {Object.keys(PREDEFINED_PROGRAMS).map((key) => (
              <button
                key={key}
                onClick={() => handleSelectTemplate(key)}
                className={`text-xs font-medium px-3 py-1.5 rounded-lg border transition-all cursor-pointer ${
                  selectedTemplate === key
                    ? "bg-indigo-50 border-indigo-200 text-indigo-700 font-semibold"
                    : "bg-white border-slate-200 text-slate-600 hover:bg-slate-50"
                }`}
              >
                {PREDEFINED_PROGRAMS[key].name}
              </button>
            ))}
          </div>
        </div>
      </header>

      {/* WORKSPACE AREA */}
      <main className="max-w-7xl mx-auto px-6 mt-8 space-y-8">
        
        {/* UPPER DIVISION: ASSEMBLER & CPU DIAGRAMS */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-stretch">
          
          {/* ASSEMBLY CONTROLLER (Left Column grid spanning 5/12) */}
          <div className="col-span-1 lg:col-span-5 bg-white border border-slate-100 rounded-2xl p-6 shadow-sm flex flex-col justify-between">
            <div>
              <div className="flex justify-between items-center mb-4">
                <h3 className="text-sm font-semibold text-slate-900 flex items-center gap-1.5">
                  <Wrench size={16} className="text-indigo-600" />
                  RISC-V Assembler & Code Studio
                </h3>
                <span className="text-[10px] text-slate-400 font-mono">32 Registers Base</span>
              </div>

              {/* Assembly text editor */}
              <div className="relative border border-slate-200 rounded-xl overflow-hidden focus-within:ring-2 focus-within:ring-indigo-100 focus-within:border-indigo-500 bg-slate-950">
                <div className="flex justify-between items-center bg-slate-900/60 px-3 py-1.5 border-b border-slate-800">
                  <span className="text-[10px] font-semibold text-slate-400 font-mono">main.asm</span>
                  <button
                    onClick={compileCurrentCode}
                    className="text-[10px] bg-indigo-600 text-white font-bold hover:bg-indigo-500 px-3 py-1 rounded-md transition-all active:scale-95 cursor-pointer"
                  >
                    Assemble & Load ROM
                  </button>
                </div>
                
                <textarea
                  value={assemblyText}
                  onChange={(e) => setAssemblyText(e.target.value)}
                  className="w-full min-h-[260px] max-h-[440px] font-mono text-xs bg-slate-950 text-indigo-200 border-0 p-4 focus:ring-0 leading-relaxed outline-none resize-y selection:bg-indigo-500/30"
                  spellCheck={false}
                  placeholder="# Write assembly code here..."
                />
              </div>

              {/* Compilation feedback panel */}
              {compileErrors.length > 0 ? (
                <div className="mt-3 p-3 bg-rose-50 border border-rose-100 rounded-xl text-xs text-rose-800 text-left flex items-start gap-2.5">
                  <AlertCircle size={15} className="mt-0.5 text-rose-600 shrink-0" />
                  <div>
                    <span className="font-bold">Assembly Errors Detected:</span>
                    <ul className="list-disc list-inside mt-1 font-mono text-[11px] space-y-0.5">
                      {compileErrors.slice(0, 3).map((err, i) => (
                        <li key={i}>{err}</li>
                      ))}
                      {compileErrors.length > 3 && <li>and {compileErrors.length - 3} more errors...</li>}
                    </ul>
                  </div>
                </div>
              ) : (
                <div className="mt-3 p-2.5 bg-emerald-50 border border-emerald-100 text-emerald-800 text-[11px] rounded-xl text-left flex items-center gap-2">
                  <CheckCircle2 size={14} className="text-emerald-600" />
                  <span>Assembly compiled successfully. Direct hex representation synchronized to ROM.</span>
                </div>
              )}
            </div>

            {/* SIMULATOR STEP CONTROLLERS */}
            <div className="mt-6 pt-5 border-t border-slate-100">
              <div className="bg-slate-50 p-4 rounded-xl border border-slate-100 flex flex-col gap-4">
                
                {/* Simulation diagnostics info line */}
                <div className="flex justify-between items-center text-xs font-mono">
                  <div className="flex flex-col text-left">
                    <span className="text-slate-400 text-[10px]">CPU Status</span>
                    <span className={`font-semibold ${cpuState.halted ? "text-rose-600" : "text-emerald-600"}`}>
                      {cpuState.halted ? "● CPU HALTED / ROM TERMINATE" : isPlaying ? "● SIM RUNNING" : "● STEADY STATE"}
                    </span>
                  </div>
                  <div className="flex flex-col text-right">
                    <span className="text-slate-400 text-[10px]">Total Clock Cycles</span>
                    <span className="font-bold text-slate-800">{cpuState.cycle}</span>
                  </div>
                </div>

                {/* Simulated hardware controls buttons strip */}
                <div className="flex flex-wrap items-center gap-1.5 justify-center">
                  
                  {/* Step backward (backtrack) */}
                  <button
                    onClick={handleStepBackward}
                    disabled={stateHistory.length === 0}
                    className="p-2 rounded-xl border border-slate-200 bg-white text-slate-700 hover:bg-slate-50 disabled:opacity-40 hover:text-slate-900 shadow-sm active:scale-95 transition-all cursor-pointer"
                    title="Undo step (Backtrack Clock)"
                  >
                    <ArrowLeft size={16} />
                  </button>

                  {/* Play / Pause Toggle */}
                  <button
                    onClick={() => setIsPlaying(!isPlaying)}
                    disabled={cpuState.halted || compiledLines.length === 0}
                    className={`flex items-center gap-1 px-4 py-2 rounded-xl font-bold text-xs shadow-sm transition-all active:scale-95 cursor-pointer ${
                      isPlaying 
                        ? "bg-slate-800 text-white hover:bg-slate-700" 
                        : "bg-indigo-600 text-white hover:bg-indigo-500 disabled:opacity-40"
                    }`}
                  >
                    {isPlaying ? (
                      <>
                        <Pause size={14} /> Pause Clock
                      </>
                    ) : (
                      <>
                        <Play size={14} /> Auto Clock Play
                      </>
                    )}
                  </button>

                  {/* Step Forward (single clock step) */}
                  <button
                    onClick={handleStepForward}
                    disabled={cpuState.halted || compiledLines.length === 0}
                    className="flex items-center gap-1 px-3 py-2 rounded-xl bg-slate-900 text-white hover:bg-slate-800 disabled:opacity-40 text-xs font-semibold shadow-sm active:scale-95 transition-all cursor-pointer"
                    title="Clock single cycle"
                  >
                    Next Cycle <ArrowRight size={14} />
                  </button>

                  {/* Reset Core parameters */}
                  <button
                    onClick={handleReset}
                    className="p-2 rounded-xl border border-slate-200 bg-white text-slate-600 hover:bg-slate-50 hover:text-rose-600 active:scale-95 shadow-sm transition-all cursor-pointer"
                    title="Reset Simulator CPU"
                  >
                    <RotateCcw size={16} />
                  </button>
                </div>

                {/* Clock Speed Setting sliders */}
                <div className="flex items-center justify-between text-xs mt-1 border-t border-slate-200/50 pt-2.5">
                  <span className="text-slate-500 font-medium">Auto Play Speed Interval:</span>
                  <div className="flex items-center gap-1.5">
                    {[500, 300, 100].map((speedValue) => (
                      <button
                        key={speedValue}
                        onClick={() => setPlaySpeed(speedValue)}
                        className={`px-2 py-0.5 rounded text-[10px] font-semibold border transition-all ${
                          playSpeed === speedValue
                            ? "bg-indigo-600 border-indigo-600 text-white"
                            : "bg-white border-slate-200 text-slate-500 hover:bg-slate-50"
                        }`}
                      >
                        {speedValue === 500 ? "Slow" : speedValue === 300 ? "Med" : "Fast (0.1s)"}
                      </button>
                    ))}
                  </div>
                </div>

              </div>
            </div>

          </div>

          {/* DYNAMIC FLOW CHART AND BLOCK DIAGRAM (Spanning 7/12) */}
          <div className="col-span-1 lg:col-span-7">
            <CPUBlockDiagram state={cpuState} />
          </div>

        </div>

        {/* MIDDLE SECTION: REGISTERS BOARD (x0-x31) */}
        <RegisterFileView state={cpuState} />

        {/* DATA MEMORY WORKSPACE AND HARDWARE MAPPED IO PERIPHERALS */}
        <MemoryView state={cpuState} onSetMemory={handleSetMemoryValue} />

        {/* ROM DISASSEMBLER WORKSPACE */}
        <InstructionTable lines={compiledLines} currentPC={cpuState.pc} onSetPC={(address) => setCpuState(prev => ({...prev, pc: address}))} />

        {/* SYSTEMVERILOG REAL LOGIC SOURCE PORTAL */}
        <SVViewer />

      </main>
    </div>
  );
}
