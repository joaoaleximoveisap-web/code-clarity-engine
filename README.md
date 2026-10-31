# Confirmação de Presença · DAJ

Uma página só, no visual da DAJ:

- **Sem `?e=` no link → Área do gestor.** Entra com o código de acesso, cria eventos (nome, data, horário,
  endereço, texto, visual), copia o link de cada um ou envia no WhatsApp, e vê quem confirmou em cada evento.
- **Com `?e=<codigo-do-evento>` → página do convidado.** A pessoa preenche empresa, função, nome e telefone.

Os dados ficam no banco do CRM DAJ (`presence_events`, `presence_rsvps`). O SQL está em `supabase/presenca.sql`
(o hash do código de acesso não fica no repositório).

Endereço: https://joaoaleximoveisap-web.github.io/code-clarity-engine/ (também publica pelo Lovable).
