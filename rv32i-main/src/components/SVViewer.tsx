/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState } from 'react';
import { SV_MODULES, SvModule } from '../utils/sv_modules';
import { FileCode, Copy, Check, Download, Info, Sparkles } from 'lucide-react';

export const SVViewer: React.FC = () => {
  const [activeTab, setActiveTab] = useState<string>('cpu_top');
  const [copied, setCopied] = useState<boolean>(false);

  const activeModule = SV_MODULES[activeTab];

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(activeModule.code);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch (err) {
      console.error('Failed to copy text: ', err);
    }
  };

  const handleDownload = () => {
    const blob = new Blob([activeModule.code], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = activeModule.filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  };

  const handleDownloadAll = () => {
    // Download every module file one by one
    Object.keys(SV_MODULES).forEach((key) => {
      const module = SV_MODULES[key];
      const blob = new Blob([module.code], { type: 'text/plain;charset=utf-8' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = module.filename;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(url);
    });
  };

  return (
    <div className="bg-slate-900 border border-slate-800 rounded-2xl shadow-xl p-6 text-slate-100 flex flex-col justify-between">
      <div>
        <div className="flex flex-wrap md:flex-nowrap justify-between items-start gap-4 mb-6 border-b border-slate-800 pb-4">
          <div>
            <div className="flex items-center gap-2 mb-1.5">
              <span className="bg-indigo-500/10 text-indigo-400 font-bold text-[10px] tracking-wider uppercase px-2 py-0.5 rounded border border-indigo-500/20">
                Synthesizable RTL
              </span>
              <span className="flex items-center gap-1.5 text-xs text-amber-400 font-semibold px-2 py-0.5 bg-amber-500/10 rounded border border-amber-500/20">
                <Sparkles size={11} />
                Strict SystemVerilog Guidelines
              </span>
            </div>
            <h3 className="text-sm font-semibold text-slate-100 flex items-center gap-2">
              <FileCode className="text-indigo-400" size={18} />
              SystemVerilog Source Code Portal
            </h3>
            <p className="text-xs text-slate-400 mt-1">
              Browse and export clean modules crafted exactly to the requested specifications.
            </p>
          </div>
          <button
            onClick={handleDownloadAll}
            className="text-xs bg-indigo-600 hover:bg-indigo-700 text-white font-semibold py-2 px-3.5 rounded-xl flex items-center gap-1.5 shadow-lg active:scale-95 transition-all self-end shrink-0"
          >
            <Download size={14} />
            Download SV Package
          </button>
        </div>

        {/* GUIDELINE SUMMARY BADGE PANEL */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 mb-6 bg-slate-950/40 p-3.5 rounded-xl border border-slate-800/60 text-xs">
          <div className="flex items-start gap-2 text-slate-300">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 mt-1.5 shrink-0" />
            <div>
              <span className="font-semibold block text-[11px] text-slate-400">Strict snake_case Only</span>
              All modules, internal wires, ports, and registers mapped in lowercase/snake_case. No camelCase allowed.
            </div>
          </div>
          <div className="flex items-start gap-2 text-slate-300">
            <span className="w-1.5 h-1.5 rounded-full bg-indigo-500 mt-1.5 shrink-0" />
            <div>
              <span className="font-semibold block text-[11px] text-slate-400">Conforming SV Grammar</span>
              No old-school reg or wire types. Built with logic, always_comb, and always_ff pipelines.
            </div>
          </div>
          <div className="flex items-start gap-2 text-slate-300">
            <span className="w-1.5 h-1.5 rounded-full bg-amber-500 mt-1.5 shrink-0" />
            <div>
              <span className="font-semibold block text-[11px] text-slate-400">Restricted Capitals</span>
              Uppercase characters are EXCLUSIVELY limited to define, parameter, and localparam words/identifiers.
            </div>
          </div>
        </div>

        {/* MODULE SELECTION TABS */}
        <div className="flex gap-1.5 overflow-x-auto border-b border-slate-800 pb-2 mb-4">
          {Object.keys(SV_MODULES).map((key) => {
            const module = SV_MODULES[key];
            const isActive = activeTab === key;
            return (
              <button
                key={key}
                onClick={() => {
                  setActiveTab(key);
                  setCopied(false);
                }}
                className={`text-xs px-3.5 py-1.5 rounded-xl font-mono shrink-0 border transition-all ${
                  isActive
                    ? "bg-slate-800 border-slate-700 text-[#38bdf8] font-semibold"
                    : "bg-transparent border-transparent text-slate-400 hover:text-slate-200"
                }`}
              >
                {module.filename}
              </button>
            );
          })}
        </div>

        {/* FILE DESCRIPTION HEADER CARD */}
        <div className="bg-slate-950/50 p-3 rounded-xl border border-slate-800/40 text-left text-xs text-slate-400 mb-3 flex items-start gap-2">
          <Info size={14} className="text-[#38bdf8] shrink-0 mt-0.5" />
          <div>
            <span className="font-semibold text-slate-200">Module Description:</span> {activeModule.description}
          </div>
        </div>

        {/* CODE CONTAINER */}
        <div className="relative">
          {/* Action Float Bar */}
          <div className="absolute top-3 right-3 flex gap-2 z-10">
            <button
              onClick={handleCopy}
              className="p-2 bg-slate-800 hover:bg-slate-700 border border-slate-700 rounded-lg text-slate-300 transition-all hover:scale-105 active:scale-95 cursor-pointer"
              title="Copy register content"
            >
              {copied ? <Check size={14} className="text-emerald-400" /> : <Copy size={14} />}
            </button>
            <button
              onClick={handleDownload}
              className="p-2 bg-indigo-600 hover:bg-indigo-500 border border-indigo-500/20 rounded-lg text-white transition-all hover:scale-105 active:scale-95 cursor-pointer"
              title="Download individual module file"
            >
              <Download size={14} />
            </button>
          </div>

          {/* Real SystemVerilog Display Area */}
          <pre className="text-left font-mono text-xs overflow-x-auto bg-black p-5 pr-14 rounded-xl border border-slate-800/80 max-h-[440px] text-indigo-100 select-all leading-relaxed">
            <code>{activeModule.code}</code>
          </pre>
        </div>
      </div>
    </div>
  );
};
