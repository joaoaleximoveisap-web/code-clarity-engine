# Code Clarity Engine

Criar uma aplicação chamada “Analisador de Automação Lovable” com foco em análise de código e sugestões inteligentes.

OBJETIVO:
Permitir que o usuário cole qualquer código do seu sistema (React, páginas, dashboards, hooks) e a aplicação analise automaticamente:
- O que está automatizado
- O que está manual
- O que está quebrado/inconsistente
- O que poderia ser automatizado

FUNCIONALIDADES PRINCIPAIS:

1) INPUT DE CÓDIGO
- Área grande tipo editor (textarea ou code editor)
- Suporte para colar código React/TS/JS
- Botão: “Analisar automação”

2) MOTOR DE ANÁLISE (SIMULADO + IA READY)
- Detectar padrões:
  - Formulários sem validação
  - Estados manuais (useState excessivo sem lógica)
  - Falta de automações (ex: ausência de useEffect, triggers, regras)
  - Listas fixas que deveriam ser dinâmicas
  - Dashboards estáticos (sem cálculo real)
  - Inputs sem conexão com banco
- Classificar em:
  - Automatizado
  - Parcial
  - Manual

3) SCORE DE AUTOMAÇÃO
- Mostrar um score de 0 a 100
- Barra visual premium

4) RELATÓRIO INTELIGENTE
Seções:
- O que já está automatizado
- O que está manual
- Gaps críticos
- Riscos operacionais

5) SUGESTÕES DE AUTOMAÇÃO
- Lista de melhorias priorizadas
- Cada item com:
  - Problema
  - Impacto
  - Solução

6) GERADOR DE PROMPT PARA LOVABLE
- Para cada melhoria, gerar automaticamente:
“Prompt pronto para colar no Lovable”

Exemplo:
“Adicionar validação automática de formulário com regras mínimas de entrada...”

7) VISUAL (SEGUIR PADRÃO DO USUÁRIO)
- Fundo escuro (preto)
- Tipografia branca/cinza metálico
- Estilo premium imobiliário
- Cards minimalistas
- Layout limpo e centralizado

8) ABAS NO DASHBOARD
Criar abas internas:
- Visão Geral
- Problemas
- Automação
- Prompts

IMPORTANTE:
- NÃO precisa integração real com backend
- Simular análise com heurísticas inteligentes
- Preparado para futura integração com IA real

RESULTADO FINAL:
Uma ferramenta que funciona como “raio-x do sistema”, mostrando exatamente:
- onde está quebrado
- onde está manual
- onde dá pra escalar

E já entrega a solução pronta em formato de prompt.

This project was built with [Lovable](https://lovable.dev).

## Build with Lovable

Continue developing this project in the [Lovable editor](https://lovable.dev/projects/2d45dcf9-ba49-4ac0-a12e-4779f5f294da).

- **Ship faster**: describe what you want to build and Lovable handles the code.
- **Stay in sync**: every change made in Lovable is committed straight to this repository.
- **Full ownership**: this code is yours. Push to `main` on GitHub and your changes sync back into Lovable, ready for your next prompt.

## Development

Prefer working locally? You need Node.js and npm — [install with nvm](https://github.com/nvm-sh/nvm#installing-and-updating).

```sh
git clone <this-repository-url>
cd <repository-name>
npm i
npm run dev
```
