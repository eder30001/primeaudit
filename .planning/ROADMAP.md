# Roadmap: PrimeAudit

## Milestones

- ✅ **v1.0 Foundation** — Phases 1–5 (shipped 2026-04-17)
- ✅ **v1.1 Features & UX** — Phases 6–12 (shipped 2026-05-02)

---

## Phases

<details>
<summary>✅ v1.0 Foundation (Phases 1–5) — SHIPPED 2026-04-17</summary>

- [x] Phase 1: Data Integrity — completed 2026-04-17
- [x] Phase 2: Security — completed
- [x] Phase 3: Test Coverage — completed
- [x] Phase 4: Performance — completed
- [~] Phase 5: Server Config — Deferred to v2

</details>

<details>
<summary>✅ v1.1 Features & UX (Phases 6–12) — SHIPPED 2026-05-02</summary>

- [~] Phase 6: Templates — Cancelled 2026-05-02
- [x] Phase 7: Dashboard — completed 2026-04-25
- [x] Phase 8: Corrective Actions — completed 2026-04-27
- [x] Phase 9: Images — completed 2026-04-29
- [x] Phase 10: Reports (Calendar Dashboard) — completed 2026-05-02
- [ ] Phase 11: Notifications — Deferred to future milestone
- [~] Phase 12: Navigation Refactor — Cancelled 2026-05-02

Archive: [.planning/milestones/v1.1-ROADMAP.md](milestones/v1.1-ROADMAP.md)

</details>

---

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Data Integrity | v1.0 | 3/3 | Complete | 2026-04-17 |
| 2. Security | v1.0 | 4/4 | Complete | — |
| 3. Test Coverage | v1.0 | 4/4 | Complete | — |
| 4. Performance | v1.0 | 1/1 | Complete | — |
| 5. Server Config | v1.0 | 0/? | Deferred to v2 | — |
| 6. Templates | v1.1 | 0/2 | Cancelled | 2026-05-02 |
| 7. Dashboard | v1.1 | 2/2 | Complete | 2026-04-25 |
| 8. Corrective Actions | v1.1 | 4/4 | Complete | 2026-04-27 |
| 9. Images | v1.1 | 3/3 | Complete | 2026-04-29 |
| 10. Reports (Calendar) | v1.1 | 3/3 | Complete | 2026-05-02 |
| 11. Notifications | v1.1 | 0/? | Deferred | — |
| 12. Navigation Refactor | v1.1 | 0/? | Cancelled | 2026-05-02 |

---

## Backlog

### Phase 999.1: Responsável externo por email nas ações corretivas (BACKLOG)

**Goal:** No campo de responsável das ações corretivas, adicionar opção "Convidar por email" para casos em que o responsável ainda não está cadastrado no sistema. A ação fica vinculada ao e-mail até o cadastro ser concluído.
**Requirements:** TBD
**Context:** Hoje o dropdown só lista usuários cadastrados em `profiles`. Em cenários onde o responsável é externo ou ainda não tem conta, o auditor fica bloqueado sem poder atribuir a ação. Fluxo sugerido: dropdown normal + opção de digitar e-mail manualmente; o sistema envia convite e vincula a ação ao perfil quando criado.
**Plans:** 0 plans

Plans:
- [ ] TBD (promover com /gsd-review-backlog quando pronto)
