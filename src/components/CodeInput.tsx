import { useState } from "react";
import { Zap } from "lucide-react";

interface CodeInputProps {
  onAnalyze: (code: string) => void;
  isAnalyzing: boolean;
}

const CodeInput = ({ onAnalyze, isAnalyzing }: CodeInputProps) => {
  const [code, setCode] = useState("");

  return (
    <div className="card-premium rounded-xl p-6 space-y-4">
      <div className="flex items-center gap-3">
        <div className="w-2 h-2 rounded-full bg-primary animate-pulse" />
        <h2 className="text-lg font-semibold text-foreground">Cole seu código</h2>
      </div>
      <textarea
        value={code}
        onChange={(e) => setCode(e.target.value)}
        placeholder="// Cole aqui seu código React, TypeScript, hooks, páginas..."
        className="code-input w-full h-64 bg-muted border border-border rounded-lg p-4 text-sm text-foreground placeholder:text-muted-foreground resize-none focus:outline-none focus:ring-1 focus:ring-primary/50 transition-all"
        spellCheck={false}
      />
      <button
        onClick={() => code.trim() && onAnalyze(code)}
        disabled={!code.trim() || isAnalyzing}
        className="w-full flex items-center justify-center gap-2 py-3 px-6 rounded-lg font-semibold text-primary-foreground bg-primary hover:brightness-110 disabled:opacity-40 disabled:cursor-not-allowed transition-all glow-gold"
      >
        <Zap className="w-4 h-4" />
        {isAnalyzing ? "Analisando..." : "Analisar Automação"}
      </button>
    </div>
  );
};

export default CodeInput;
