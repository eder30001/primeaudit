---
status: partial
phase: 07-dashboard
source: [07-VERIFICATION.md]
started: 2026-04-25T00:00:00.000Z
updated: 2026-04-25T00:00:00.000Z
---

## Current Test

[aguardando teste humano]

## Tests

### 1. Escopo de auditor — cards mostram apenas auditorias próprias
expected: Ao logar como auditor, os KPI cards (Total, Pendentes, Atrasadas, Ações abertas) exibem apenas contagens das auditorias cujo auditorId corresponde ao usuário logado

result: [pending]

### 2. Card Empresas para superuser/dev
expected: Ao logar como superuser ou dev, o quarto card exibe "Empresas" (com contagem real) em vez de "Ações abertas"

result: [pending]

### 3. Pull-to-refresh funcional
expected: Arrastar a tela para baixo exibe o spinner do RefreshIndicator e recarrega todos os KPI cards e gráfico com dados atualizados

result: [pending]

### 4. Gráfico de conformidade com dados reais
expected: Quando há auditorias concluídas, o gráfico exibe barras horizontais com labels dos templates no eixo esquerdo e valores percentuais no eixo inferior, ordenadas do maior para o menor

result: [pending]

### 5. Estado vazio do gráfico sem crash
expected: Quando não há auditorias concluídas, o gráfico exibe o container com a mensagem "Nenhuma auditoria concluída para exibir" sem erros ou crash

result: [pending]

## Summary

total: 5
passed: 0
issues: 0
pending: 5
skipped: 0
blocked: 0

## Gaps
