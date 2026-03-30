import { useState } from "react";
import { analyzeCode, AnalysisResult } from "@/lib/analyzer";
import CodeInput from "@/components/CodeInput";
import ScoreGauge from "@/components/ScoreGauge";
import AnalysisReport from "@/components/AnalysisReport";
import { Scan, Eye, AlertCircle, Cpu, MessageSquare } from "lucide-react";

const tabs = [
  { id: "overview", label: "Visão Geral", icon: Eye },
  { id: "problems", label: "Problemas", icon: AlertCircle },
  { id: "automation", label: "Automação", icon: Cpu },
  { id: "prompts", label: "Prompts", icon: MessageSquare },
];

const Index = () => {
  const [result, setResult] = useState<AnalysisResult | null>(null);
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [activeTab, setActiveTab] = useState("overview");

  const handleAnalyze = (code: string) => {
    setIsAnalyzing(true);
    // Simulate processing delay
    setTimeout(() => {
      const analysis = analyzeCode(code);
      setResult(analysis);
      setIsAnalyzing(false);
    }, 1200);
  };

  return (
    <div className="min-h-screen bg-background">
      <div className="max-w-5xl mx-auto px-4 py-12">
        {/* Header */}
        <div className="text-center mb-12">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full border border-border bg-secondary text-xs text-muted-foreground mb-4">
            <Scan className="w-3 h-3 text-primary" />
            Raio-X do seu sistema
          </div>
          <h1 className="text-4xl md:text-5xl font-bold text-metallic mb-3">
            Analisador de Automação
          </h1>
          <p className="text-muted-foreground max-w-xl mx-auto">
            Cole seu código e descubra o que está automatizado, manual ou quebrado — com prompts prontos para corrigir.
          </p>
        </div>

        {/* Input */}
        <CodeInput onAnalyze={handleAnalyze} isAnalyzing={isAnalyzing} />

        {/* Results */}
        {result && (
          <div className="mt-10 space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500">
            <ScoreGauge score={result.score} />

            {/* Tabs */}
            <div className="flex gap-1 p-1 bg-secondary rounded-lg">
              {tabs.map((tab) => {
                const Icon = tab.icon;
                return (
                  <button
                    key={tab.id}
                    onClick={() => setActiveTab(tab.id)}
                    className={`flex-1 flex items-center justify-center gap-2 py-2.5 px-3 rounded-md text-sm font-medium transition-all ${
                      activeTab === tab.id
                        ? "bg-card text-foreground shadow-sm"
                        : "text-muted-foreground hover:text-foreground"
                    }`}
                  >
                    <Icon className="w-4 h-4" />
                    <span className="hidden sm:inline">{tab.label}</span>
                  </button>
                );
              })}
            </div>

            <AnalysisReport result={result} activeTab={activeTab} />
          </div>
        )}
      </div>
    </div>
  );
};

export default Index;
