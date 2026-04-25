---
phase: 07-dashboard
verified: 2026-04-25T00:00:00Z
status: human_needed
score: 10/10
overrides_applied: 0
human_verification:
  - test: "Logar como auditor e verificar se os cards de KPI mostram apenas as próprias auditorias (total, pendentes, atrasadas)"
    expected: "Cards exibem valores numéricos scoped pelo auditor logado, não pelo total da empresa"
    why_human: "Filtro Dart-side de auditorId está implementado, mas só pode ser confirmado visualmente com dados reais em ambiente conectado ao Supabase"
  - test: "Logar como superuser/dev e verificar se o card 'Empresas' aparece no lugar de 'Ações abertas'"
    expected: "Quarto card exibe 'Empresas' com contagem real de empresas cadastradas"
    why_human: "Condicional AppRole.isSuperOrDev está correta no código, mas a renderização correta do card depende de perfil real com role superuser/dev"
  - test: "Puxar a tela para baixo (pull-to-refresh) no dashboard e verificar se os cards atualizam"
    expected: "Spinner aparece, cards mostram '...' durante recarga, e valores atualizados aparecem sem navegar para outra tela"
    why_human: "RefreshIndicator e AlwaysScrollableScrollPhysics estão implementados corretamente, mas o comportamento visual de refresh exige teste em dispositivo/emulador"
  - test: "Verificar se o gráfico de conformidade renderiza barras horizontais corretas quando existem auditorias concluídas"
    expected: "Barras horizontais com labels de templateName à esquerda, porcentagem embaixo, ordenadas do melhor para o pior"
    why_human: "fl_chart BarChart com rotationQuarterTurns:1 está configurado no código, mas a renderização visual e o posicionamento dos labels só podem ser confirmados em execução"
  - test: "Verificar o estado vazio do gráfico quando não há auditorias concluídas"
    expected: "Container com mensagem 'Nenhuma auditoria concluída para exibir' renderizado sem crash"
    why_human: "Guard isEmpty está implementado, mas confirmar ausência de crash exige execução com base de dados sem auditorias concluídas"
---

# Phase 7: Dashboard Verification Report

**Phase Goal:** Usuário vê indicadores reais de auditorias e ações abertas scoped por empresa, atualizáveis via pull-to-refresh
**Verified:** 2026-04-25
**Status:** human_needed
**Re-verification:** No — verificacao inicial

---

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria + PLAN must_haves)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Dashboard exibe cards com total, pendentes, atrasadas e ações em aberto com valores reais scoped pela empresa ativa | VERIFIED | `_loadDashboard()` busca via `_auditService.getAudits(companyId: companyId)` e popula `_totalAudits`, `_pendingAudits`, `_overdueAudits`, `_openActions`. Cards renderizam `'$_totalAudits'` etc. — linha 377, 387, 402, 419 de home_screen.dart |
| 2 | Pull-to-refresh atualiza todos os cards sem navegar para outra tela | VERIFIED | `RefreshIndicator(onRefresh: _loadDashboard, ...)` envolve `SingleChildScrollView` com `AlwaysScrollableScrollPhysics()` — linhas 342-346 de home_screen.dart |
| 3 | Gráfico mostra conformidade media por template (DASH-03) | VERIFIED | `_buildConformityChart(_chartData)` renderiza `BarChart` com `rotationQuarterTurns: 1` agrupando auditorias `concluida` por `templateName` — linhas 463-543 de home_screen.dart |
| 4 | fl_chart ^1.2.0 declarado em pubspec.yaml e resolvido | VERIFIED | `fl_chart: ^1.2.0` em linha 37 de pubspec.yaml; entrada confirmada em pubspec.lock |
| 5 | DashboardService expoe getOpenActionsCount(String?) com fallback 0 quando tabela ausente | VERIFIED | `dashboard_service.dart`: try/catch completo retorna 0 em caso de excecao — linhas 13-27 |
| 6 | DashboardService expoe getCompaniesCount() | VERIFIED | `dashboard_service.dart` linha 31-34; chamado apenas quando `AppRole.isSuperOrDev(_role)` — linha 103 de home_screen.dart |
| 7 | Testes unitarios para KPI counts (total exclui cancelada, pending = emAndamento, overdue = atrasada) passam | VERIFIED | 23/23 testes passam: `flutter test test/services/dashboard_service_test.dart` — 5 grupos confirmados |
| 8 | Testes unitarios para role scope (auditor ve apenas proprias auditorias) passam | VERIFIED | Grupo "Role scope — auditor filter" com 3 testes — todos passam |
| 9 | Testes unitarios para chart data (agrupamento por templateName, avg, ordenado desc) passam | VERIFIED | Grupo "Chart data — grouping and averaging" com 7 testes — todos passam |
| 10 | Auditor ve apenas suas proprias auditorias em todos os cards KPI (D-05) | VERIFIED (codigo) | `all.where((a) => a.auditorId == currentUserId).toList()` aplicado quando role nao e admin/superuser — linha 91 de home_screen.dart. Confirmacao visual requer teste humano |

**Score:** 10/10 truths verificadas

---

### Deferred Items

Nenhum item diferido. Todos os requisitos DASH-01, DASH-02 e DASH-03 foram endereçados nesta fase. O card "Ações abertas" retorna 0 intencionalmente como fallback documentado para Phase 8 (D-04 em CONTEXT.md) — isso nao e um gap.

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `primeaudit/pubspec.yaml` | fl_chart: ^1.2.0 | VERIFIED | Linha 37 confirmada |
| `primeaudit/pubspec.lock` | fl_chart resolvido | VERIFIED | 2 entradas encontradas (nome + versao) |
| `primeaudit/lib/services/dashboard_service.dart` | DashboardService com getOpenActionsCount + getCompaniesCount | VERIFIED | 36 linhas, classe completa com metodos substantivos |
| `primeaudit/test/services/dashboard_service_test.dart` | 23+ testes unitarios para DASH-01 e DASH-03 | VERIFIED | 242 linhas, 23 testes, 5 grupos, todos passam |
| `primeaudit/lib/screens/home_screen.dart` | Dashboard funcional com KPIs reais + pull-to-refresh + grafico | VERIFIED | 621 linhas; `_loadDashboard()`, `_buildConformityChart()`, `_TemplateConformity` todos presentes e substanciais |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `_loadProfile()` | `_loadDashboard()` | `await _loadDashboard()` no bloco try apos setState | WIRED | Linha 70 de home_screen.dart; garante que `_role` esta definido antes do carregamento do dashboard |
| `_buildDashboard()` | `RefreshIndicator` | Widget raiz de `_buildDashboard()` | WIRED | Linha 342; `onRefresh: _loadDashboard` na linha 343 |
| `_loadDashboard()` | `_dashboardService.getOpenActionsCount` | chamada direta na linha 99 | WIRED | `final openActions = await _dashboardService.getOpenActionsCount(companyId)` |
| `home_screen.dart` | `fl_chart BarChart` | `import 'package:fl_chart/fl_chart.dart'` | WIRED | Linha 2; `BarChart(` usada na linha 483 |
| `dashboard_service_test.dart` | `primeaudit/models/audit.dart` | `import 'package:primeaudit/models/audit.dart'` | WIRED | Linha 8 do arquivo de testes; `Audit`, `AuditStatus` usados no factory e helpers |
| `dashboard_service.dart` | `Supabase.instance.client` | `final _client = Supabase.instance.client` | WIRED | Linha 8 de dashboard_service.dart; `_client` usado nas queries |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produz Dados Reais | Status |
|----------|---------------|--------|--------------------|--------|
| `home_screen.dart` KPI cards | `_totalAudits`, `_pendingAudits`, `_overdueAudits` | `_auditService.getAudits(companyId: companyId)` -> filtro Dart -> `.where(...).length` | Sim — query real ao Supabase, count calculado em Dart | FLOWING |
| `home_screen.dart` card "Ações abertas" | `_openActions` | `_dashboardService.getOpenActionsCount(companyId)` -> tabela `corrective_actions` (Phase 8 fallback = 0) | Sim (retorna 0 intencionalmente ate Phase 8 existir) | FLOWING (fallback documentado) |
| `home_screen.dart` card "Empresas" | `_companiesCount` | `_dashboardService.getCompaniesCount()` -> tabela `companies` | Sim — query real ao Supabase | FLOWING |
| `home_screen.dart` grafico conformidade | `_chartData` (List<_TemplateConformity>) | `_buildChartData(audits)` agrupa audits `concluida` por `templateName`, calcula media | Sim — derivado da mesma lista real de auditorias | FLOWING |

---

### Behavioral Spot-Checks

| Comportamento | Comando | Resultado | Status |
|---------------|---------|-----------|--------|
| 23 testes de KPI e grafico passam | `flutter test test/services/dashboard_service_test.dart` | 23/23 testes passados em <1s | PASS |
| Suite completa sem regressoes | `flutter test` | 172 testes passados (inclui todos os anteriores) | PASS |
| dart analyze em dashboard_service.dart | `dart analyze lib/services/dashboard_service.dart` | No issues found | PASS |
| dart analyze em home_screen.dart | `dart analyze lib/screens/home_screen.dart` | 1 warning: unused import `supabase_flutter` linha 3 | WARNING |

---

### Requirements Coverage

| Requirement | Plano | Descricao | Status | Evidencia |
|-------------|-------|-----------|--------|-----------|
| DASH-01 | 07-01, 07-02 | Cards com total, pendentes, atrasadas e acoes em aberto scoped por empresa | SATISFIED | `_loadDashboard()` implementado; cards `_totalAudits`, `_pendingAudits`, `_overdueAudits`, `_openActions` renderizados em home_screen.dart |
| DASH-02 | 07-02 | Pull-to-refresh atualiza dashboard | SATISFIED | `RefreshIndicator(onRefresh: _loadDashboard)` + `AlwaysScrollableScrollPhysics()` em home_screen.dart linha 342-346 |
| DASH-03 | 07-01, 07-02 | Grafico de conformidade media por template | SATISFIED | `_buildConformityChart()` com `fl_chart BarChart` + `_buildChartData()` agregando auditorias `concluida` por `templateName` |

Todos os 3 requisitos declarados nos PLAN frontmatter estao cobertos. Nenhum requisito mapeado para Phase 7 em REQUIREMENTS.md esta orfao.

---

### Anti-Patterns Found

| Arquivo | Linha | Padrao | Severidade | Impacto |
|---------|-------|--------|------------|---------|
| `primeaudit/lib/screens/home_screen.dart` | 3 | `import 'package:supabase_flutter/supabase_flutter.dart'` — import nao utilizado | Warning | Nao bloqueia compilacao nem funcionalidade; `dart analyze` reporta warning mas nao erro. O import foi adicionado como dependencia prevista do DashboardService mas a logica foi isolada no proprio service. Remover na proxima passagem para manter o arquivo sem warnings. |

Nenhum stub bloqueante, placeholder, TODO, ou implementacao vazia encontrado. O fallback de `_openActions = 0` e intencional e documentado (D-04).

---

### Human Verification Required

#### 1. Scope de auditorias para auditor

**Test:** Logar com um usuario de role `auditor` que possui algumas auditorias proprias e verificar os cards Total, Pendentes e Atrasadas
**Expected:** Cards exibem apenas os numeros das proprias auditorias do auditor logado, nao o total da empresa
**Why human:** O filtro `all.where((a) => a.auditorId == currentUserId)` esta implementado corretamente (linha 91), mas a validacao requer dados reais no Supabase com usuarios distintos

#### 2. Card Empresas para superuser/dev

**Test:** Logar com role `superuser` ou `dev` e verificar o quarto card
**Expected:** Quarto card exibe "Empresas" com contagem real de empresas cadastradas (em vez de "Acoes abertas")
**Why human:** Condicional `AppRole.isSuperOrDev(_role)` esta correta no codigo (linha 408), mas a renderizacao correta so pode ser confirmada com perfil real de superuser

#### 3. Pull-to-refresh funcional

**Test:** Com o app aberto no dashboard, puxar a tela para baixo
**Expected:** Spinner de refresh aparece, cards mostram "..." durante recarga, e valores atualizados aparecem sem navegar para outra tela
**Why human:** `RefreshIndicator` + `AlwaysScrollableScrollPhysics` estao corretamente implementados, mas o comportamento interativo exige teste em dispositivo ou emulador

#### 4. Grafico de conformidade com dados reais

**Test:** Garantir que existem auditorias com status `concluida` e `conformityPercent` nao nulo no banco, depois abrir o dashboard
**Expected:** Barras horizontais aparecem com labels dos templates a esquerda, porcentagem embaixo, ordenadas do maior para o menor
**Why human:** `fl_chart` com `rotationQuarterTurns: 1` esta configurado corretamente mas o posicionamento dos axis labels com barras horizontais so pode ser confirmado visualmente

#### 5. Estado vazio do grafico

**Test:** Testar com usuario/empresa sem nenhuma auditoria concluida
**Expected:** Container com mensagem "Nenhuma auditoria concluida para exibir" (sem crash)
**Why human:** Guard `if (data.isEmpty)` implementado na linha 464, mas confirmar ausencia de crash RangeError requer execucao com base de dados sem auditorias concluidas

---

### Gaps Summary

Nenhum gap identificado. Todos os 10 must-haves foram verificados no codigo.

O unico item de atencao e o **warning de import nao utilizado** (`supabase_flutter` em home_screen.dart linha 3) — nao bloqueia funcionalidade, mas deve ser removido para manter o codigo sem warnings de lint.

Os 5 itens de verificacao humana sao todos sobre comportamento visual e interativo em execucao — nao indicam gap de implementacao, mas sao necessarios para confirmar que o objetivo da fase foi atingido do ponto de vista do usuario.

---

_Verified: 2026-04-25_
_Verifier: Claude (gsd-verifier)_
