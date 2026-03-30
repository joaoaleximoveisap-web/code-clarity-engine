import { useEffect, useState } from "react";

interface ScoreGaugeProps {
  score: number;
}

const ScoreGauge = ({ score }: ScoreGaugeProps) => {
  const [animatedScore, setAnimatedScore] = useState(0);

  useEffect(() => {
    const duration = 1500;
    const start = performance.now();
    const animate = (now: number) => {
      const elapsed = now - start;
      const progress = Math.min(elapsed / duration, 1);
      const eased = 1 - Math.pow(1 - progress, 3);
      setAnimatedScore(Math.round(score * eased));
      if (progress < 1) requestAnimationFrame(animate);
    };
    requestAnimationFrame(animate);
  }, [score]);

  const label = score >= 75 ? 'Excelente' : score >= 50 ? 'Parcial' : score >= 25 ? 'Fraco' : 'Crítico';
  const labelColor = score >= 75 ? 'text-success' : score >= 50 ? 'text-warning' : 'text-destructive';

  return (
    <div className="card-premium rounded-xl p-8 text-center">
      <p className="text-sm uppercase tracking-widest text-muted-foreground mb-4">Score de Automação</p>
      <div className="text-7xl font-bold text-metallic mb-2 tabular-nums">
        {animatedScore}
      </div>
      <p className={`text-lg font-medium ${labelColor} mb-6`}>{label}</p>
      <div className="score-bar-bg h-3 rounded-full overflow-hidden">
        <div
          className="score-bar-fill h-full rounded-full transition-all duration-1000 ease-out"
          style={{ width: `${animatedScore}%` }}
        />
      </div>
      <div className="flex justify-between text-xs text-muted-foreground mt-2">
        <span>0</span>
        <span>100</span>
      </div>
    </div>
  );
};

export default ScoreGauge;
