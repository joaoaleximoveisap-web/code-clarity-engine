export interface AnalysisItem {
  id: string;
  category: 'automated' | 'partial' | 'manual';
  title: string;
  description: string;
  impact: 'high' | 'medium' | 'low';
  suggestion: string;
  prompt: string;
}

export interface AnalysisResult {
  score: number;
  items: AnalysisItem[];
  summary: {
    automated: number;
    partial: number;
    manual: number;
  };
}

type Rule = {
  id: string;
  test: (code: string) => boolean;
  category: 'automated' | 'partial' | 'manual';
  title: string;
  description: string;
  impact: 'high' | 'medium' | 'low';
  suggestion: string;
  prompt: string;
  scoreWeight: number;
};

const rules: Rule[] = [
  {
    id: 'no-form-validation',
    test: (c) => /<form/i.test(c) && !(/zod|yup|react-hook-form|useForm|validation|validate/i.test(c)),
    category: 'manual',
    title: 'Formulário sem validação',
    description: 'Formulários encontrados sem biblioteca de validação (Zod, Yup ou React Hook Form).',
    impact: 'high',
    suggestion: 'Adicionar validação automática com Zod + React Hook Form para eliminar validação manual.',
    prompt: 'Adicionar validação automática em todos os formulários usando Zod para schemas e React Hook Form para controle. Incluir mensagens de erro inline, validação em tempo real e feedback visual de sucesso/erro.',
    scoreWeight: -15,
  },
  {
    id: 'excessive-usestate',
    test: (c) => (c.match(/useState/g) || []).length > 6,
    category: 'manual',
    title: 'useState excessivo',
    description: 'Muitos estados locais (useState) sem lógica centralizada. Indica gestão manual de estado.',
    impact: 'medium',
    suggestion: 'Consolidar estados relacionados em um useReducer ou extrair para custom hooks.',
    prompt: 'Refatorar os múltiplos useState deste componente em um useReducer com actions tipadas, ou criar um custom hook que encapsule toda a lógica de estado relacionada. Manter a interface do componente limpa.',
    scoreWeight: -10,
  },
  {
    id: 'no-useeffect',
    test: (c) => /useState/i.test(c) && !/useEffect/i.test(c) && c.length > 200,
    category: 'manual',
    title: 'Sem efeitos colaterais automatizados',
    description: 'Componente com estado mas sem useEffect — possível falta de automação de sincronização.',
    impact: 'medium',
    suggestion: 'Adicionar useEffect para sincronizar estado automaticamente com dados externos ou derivados.',
    prompt: 'Adicionar useEffect para sincronização automática de dados neste componente. Implementar loading states, error handling e cleanup de efeitos para evitar memory leaks.',
    scoreWeight: -8,
  },
  {
    id: 'hardcoded-lists',
    test: (c) => {
      const arrayLiterals = c.match(/\[\s*\{[^}]+\}\s*(,\s*\{[^}]+\}\s*){2,}\]/g);
      return !!arrayLiterals && arrayLiterals.some(a => a.length > 200);
    },
    category: 'manual',
    title: 'Listas fixas hardcoded',
    description: 'Arrays estáticos grandes encontrados. Deveriam vir de um banco de dados ou API.',
    impact: 'high',
    suggestion: 'Mover dados estáticos para banco de dados e carregar dinamicamente com React Query.',
    prompt: 'Migrar todas as listas hardcoded para uma tabela no banco de dados. Usar React Query (useQuery) para buscar os dados com cache automático, loading states e tratamento de erro. Adicionar paginação se a lista for grande.',
    scoreWeight: -15,
  },
  {
    id: 'static-dashboard',
    test: (c) => /dashboard/i.test(c) && /(const\s+\w+\s*=\s*\d|hardcoded|fixo)/i.test(c),
    category: 'manual',
    title: 'Dashboard com dados estáticos',
    description: 'Dashboard exibindo valores fixos em vez de cálculos dinâmicos.',
    impact: 'high',
    suggestion: 'Conectar dashboard a fontes de dados reais com cálculos automáticos.',
    prompt: 'Transformar este dashboard estático em dinâmico. Conectar todos os KPIs e gráficos a queries reais do banco de dados. Adicionar atualização automática (refetch interval), filtros de período e cálculos derivados em tempo real.',
    scoreWeight: -15,
  },
  {
    id: 'no-error-handling',
    test: (c) => /fetch|axios|supabase/i.test(c) && !/try|catch|\.catch|onError/i.test(c),
    category: 'partial',
    title: 'Sem tratamento de erros',
    description: 'Chamadas assíncronas sem tratamento de erro adequado.',
    impact: 'high',
    suggestion: 'Adicionar try/catch e feedback visual de erro para todas as operações assíncronas.',
    prompt: 'Implementar tratamento de erros completo em todas as chamadas assíncronas. Usar try/catch com toast notifications para feedback ao usuário, retry automático para erros de rede e estados de erro específicos na UI.',
    scoreWeight: -12,
  },
  {
    id: 'no-loading-state',
    test: (c) => /fetch|useQuery|supabase/i.test(c) && !/loading|isLoading|skeleton|spinner/i.test(c),
    category: 'partial',
    title: 'Sem estado de carregamento',
    description: 'Operações assíncronas sem indicadores visuais de loading.',
    impact: 'medium',
    suggestion: 'Adicionar skeleton loaders ou spinners durante carregamento de dados.',
    prompt: 'Adicionar estados de carregamento em todas as operações assíncronas. Usar Skeleton components para loading inicial e indicadores sutis para refetch. Implementar suspense boundaries onde apropriado.',
    scoreWeight: -8,
  },
  {
    id: 'inline-styles',
    test: (c) => (c.match(/style=\{\{/g) || []).length > 3,
    category: 'partial',
    title: 'Estilos inline excessivos',
    description: 'Muitos estilos inline encontrados. Devem ser movidos para o sistema de design.',
    impact: 'low',
    suggestion: 'Migrar estilos inline para classes Tailwind ou variantes do design system.',
    prompt: 'Refatorar todos os estilos inline para classes Tailwind CSS. Criar variantes customizadas de componentes quando necessário e garantir que todas as cores usem tokens semânticos do design system.',
    scoreWeight: -5,
  },
  {
    id: 'no-typescript',
    test: (c) => c.length > 300 && !/:\s*(string|number|boolean|interface|type\s)/i.test(c) && !/React\.FC|: FC/i.test(c),
    category: 'partial',
    title: 'Tipagem fraca',
    description: 'Código sem tipagem TypeScript adequada, aumentando risco de bugs.',
    impact: 'medium',
    suggestion: 'Adicionar interfaces e tipos TypeScript para todas as props, estados e funções.',
    prompt: 'Adicionar tipagem TypeScript completa a este código. Criar interfaces para todas as props de componentes, tipos para estados, e type guards onde necessário. Eliminar uso de "any".',
    scoreWeight: -8,
  },
  {
    id: 'no-memo',
    test: (c) => (c.match(/\.map\(/g) || []).length > 2 && !/useMemo|useCallback|React\.memo/i.test(c),
    category: 'partial',
    title: 'Sem otimização de performance',
    description: 'Renderizações de listas sem memoização — possível re-render desnecessário.',
    impact: 'low',
    suggestion: 'Adicionar useMemo/useCallback para evitar re-renders desnecessários.',
    prompt: 'Otimizar a performance deste componente. Usar useMemo para cálculos derivados, useCallback para handlers passados como props, e React.memo para componentes filhos que recebem as mesmas props frequentemente.',
    scoreWeight: -5,
  },
  // Positive detections
  {
    id: 'has-react-query',
    test: (c) => /useQuery|useMutation|QueryClient/i.test(c),
    category: 'automated',
    title: 'React Query integrado',
    description: 'Gerenciamento de dados assíncronos automatizado com React Query.',
    impact: 'low',
    suggestion: 'Já implementado. Considere adicionar optimistic updates.',
    prompt: '',
    scoreWeight: 10,
  },
  {
    id: 'has-form-lib',
    test: (c) => /useForm|react-hook-form|formik/i.test(c),
    category: 'automated',
    title: 'Formulários com validação',
    description: 'Validação de formulários automatizada com biblioteca especializada.',
    impact: 'low',
    suggestion: 'Já implementado.',
    prompt: '',
    scoreWeight: 10,
  },
  {
    id: 'has-rls',
    test: (c) => /RLS|row.level|policy/i.test(c),
    category: 'automated',
    title: 'Segurança RLS detectada',
    description: 'Row Level Security configurada para proteção de dados.',
    impact: 'low',
    suggestion: 'Já implementado.',
    prompt: '',
    scoreWeight: 8,
  },
  {
    id: 'has-auth',
    test: (c) => /useAuth|signIn|signOut|session|supabase\.auth/i.test(c),
    category: 'automated',
    title: 'Autenticação implementada',
    description: 'Sistema de autenticação detectado.',
    impact: 'low',
    suggestion: 'Já implementado.',
    prompt: '',
    scoreWeight: 10,
  },
];

export function analyzeCode(code: string): AnalysisResult {
  const matchedItems: AnalysisItem[] = [];
  let scoreAdjust = 0;

  for (const rule of rules) {
    if (rule.test(code)) {
      matchedItems.push({
        id: rule.id,
        category: rule.category,
        title: rule.title,
        description: rule.description,
        impact: rule.impact,
        suggestion: rule.suggestion,
        prompt: rule.prompt,
      });
      scoreAdjust += rule.scoreWeight;
    }
  }

  // Base score starts at 50, adjusted by findings
  const rawScore = Math.max(0, Math.min(100, 50 + scoreAdjust));

  const summary = {
    automated: matchedItems.filter(i => i.category === 'automated').length,
    partial: matchedItems.filter(i => i.category === 'partial').length,
    manual: matchedItems.filter(i => i.category === 'manual').length,
  };

  return { score: rawScore, items: matchedItems, summary };
}
