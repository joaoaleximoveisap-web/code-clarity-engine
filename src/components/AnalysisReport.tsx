import { AnalysisResult } from "@/lib/analyzer";
import { CheckCircle, AlertTriangle, XCircle, Copy, Check } from "lucide-react";
import { useState } from "react";

interface AnalysisReportProps {
  result: AnalysisResult;
  activeTab: string;
}

const categoryConfig = {
  automated: { icon: CheckCircle, label: "Automatizado", color: "text-success", bg: "bg-success/10", border: "border-success/20" },
  partial: { icon: AlertTriangle, label: "Parcial", color: "text-warning", bg: "bg-warning/10", border: "border-warning/20" },
  manual: { icon: XCircle, label: "Manual", color: "text-destructive", bg: "bg-destructive/10", border: "border-destructive/20" },
};

const impactLabel = { high: "Alto", medium: "Médio", low: "Baixo" };
const impactColor = { high: "text-destructive", medium: "text-warning", low: "text-muted-foreground" };

const CopyButton = ({ text }: { text: string }) => {
  const [copied, setCopied] = useState(false);
  const handleCopy = () => {
    navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };
  return (
    <button onClick={handleCopy} className="flex items-center gap-1 text-xs text-primary hover:brightness-110 transition-all">
      {copied ? <Check className="w-3 h-3" /> : <Copy className="w-3 h-3" />}
      {copied ? "Copiado!" : "Copiar prompt"}
    </button>
  );
};

const AnalysisReport = ({ result, activeTab }: AnalysisReportProps) => {
  const { items, summary } = result;

  if (activeTab === "overview") {
    return (
      <div className="space-y-4">
        <h3 className="text-lg font-semibold text-metallic">Visão Geral</h3>
        <div className="grid grid-cols-3 gap-4">
          {(["automated", "partial", "manual"] as const).map((cat) => {
            const cfg = categoryConfig[cat];
            const Icon = cfg.icon;
            return (
              <div key={cat} className={`card-premium rounded-xl p-5 border ${cfg.border}`}>
                <Icon className={`w-5 h-5 ${cfg.color} mb-2`} />
                <p className="text-2xl font-bold text-foreground">{summary[cat]}</p>
                <p className="text-xs text-muted-foreground">{cfg.label}</p>
              </div>
            );
          })}
        </div>
        <div className="card-premium rounded-xl p-5 space-y-3">
          <h4 className="text-sm font-semibold text-foreground">Resumo da Análise</h4>
          {items.length === 0 ? (
            <p className="text-sm text-muted-foreground">Nenhum padrão detectado. Cole um código mais completo.</p>
          ) : (
            <ul className="space-y-2">
              {items.map((item) => {
                const cfg = categoryConfig[item.category];
                const Icon = cfg.icon;
                return (
                  <li key={item.id} className="flex items-start gap-3 text-sm">
                    <Icon className={`w-4 h-4 mt-0.5 shrink-0 ${cfg.color}`} />
                    <span className="text-secondary-foreground">{item.title}</span>
                  </li>
                );
              })}
            </ul>
          )}
        </div>
      </div>
    );
  }

  if (activeTab === "problems") {
    const problems = items.filter((i) => i.category !== "automated");
    return (
      <div className="space-y-4">
        <h3 className="text-lg font-semibold text-metallic">Problemas Detectados</h3>
        {problems.length === 0 ? (
          <div className="card-premium rounded-xl p-8 text-center">
            <CheckCircle className="w-10 h-10 text-success mx-auto mb-3" />
            <p className="text-foreground font-medium">Nenhum problema encontrado!</p>
          </div>
        ) : (
          problems.map((item) => {
            const cfg = categoryConfig[item.category];
            const Icon = cfg.icon;
            return (
              <div key={item.id} className={`card-premium rounded-xl p-5 border ${cfg.border} space-y-3`}>
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <Icon className={`w-4 h-4 ${cfg.color}`} />
                    <span className="font-semibold text-foreground">{item.title}</span>
                  </div>
                  <span className={`text-xs font-medium ${impactColor[item.impact]}`}>Impacto {impactLabel[item.impact]}</span>
                </div>
                <p className="text-sm text-muted-foreground">{item.description}</p>
                <p className="text-sm text-secondary-foreground"><strong>Solução:</strong> {item.suggestion}</p>
              </div>
            );
          })
        )}
      </div>
    );
  }

  if (activeTab === "automation") {
    const automated = items.filter((i) => i.category === "automated");
    return (
      <div className="space-y-4">
        <h3 className="text-lg font-semibold text-metallic">Automações Detectadas</h3>
        {automated.length === 0 ? (
          <div className="card-premium rounded-xl p-8 text-center">
            <AlertTriangle className="w-10 h-10 text-warning mx-auto mb-3" />
            <p className="text-foreground font-medium">Nenhuma automação detectada</p>
            <p className="text-sm text-muted-foreground mt-1">Seu código pode se beneficiar de automações.</p>
          </div>
        ) : (
          automated.map((item) => (
            <div key={item.id} className="card-premium rounded-xl p-5 border border-success/20 space-y-2">
              <div className="flex items-center gap-2">
                <CheckCircle className="w-4 h-4 text-success" />
                <span className="font-semibold text-foreground">{item.title}</span>
              </div>
              <p className="text-sm text-muted-foreground">{item.description}</p>
            </div>
          ))
        )}
      </div>
    );
  }

  if (activeTab === "prompts") {
    const withPrompts = items.filter((i) => i.prompt);
    return (
      <div className="space-y-4">
        <h3 className="text-lg font-semibold text-metallic">Prompts para o Lovable</h3>
        <p className="text-sm text-muted-foreground">Copie e cole estes prompts diretamente no Lovable para aplicar as melhorias.</p>
        {withPrompts.length === 0 ? (
          <div className="card-premium rounded-xl p-8 text-center">
            <CheckCircle className="w-10 h-10 text-success mx-auto mb-3" />
            <p className="text-foreground font-medium">Nenhum prompt necessário</p>
          </div>
        ) : (
          withPrompts.map((item) => (
            <div key={item.id} className="card-premium rounded-xl p-5 space-y-3">
              <div className="flex items-center justify-between">
                <span className="font-semibold text-foreground text-sm">{item.title}</span>
                <CopyButton text={item.prompt} />
              </div>
              <div className="bg-muted rounded-lg p-4 text-sm text-secondary-foreground font-mono leading-relaxed">
                {item.prompt}
              </div>
            </div>
          ))
        )}
      </div>
    );
  }

  return null;
};

export default AnalysisReport;
