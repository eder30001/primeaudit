# Roadmap: QAudit

## Milestones

- ✅ **v1.0 Foundation** — Phases 1–5 (shipped 2026-04-17)
- ✅ **v1.1 Features & UX** — Phases 6–12 (shipped 2026-05-02)
- ✅ **v1.2 Checklist** — Phases 13–15 (shipped 2026-05-13)
- 🔄 **v1.3** — Phases 18+ (planning)

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

<details>
<summary>✅ v1.2 Checklist (Phases 13–15) — SHIPPED 2026-05-13</summary>

- [x] Phase 13: DB Foundation + Template Management — completed 2026-05-04
- [x] Phase 14: Checklist Execution Engine — completed 2026-05-06
- [x] Phase 15: Photos per Item — completed 2026-05-07
- [~] Phase 16: Digital Signature — Cancelled 2026-05-09 → deferred to v1.3
- [~] Phase 17: History + Conformity Indicators — Cancelled 2026-05-09 → deferred to v1.3

Archive: [.planning/milestones/v1.2-ROADMAP.md](milestones/v1.2-ROADMAP.md)

</details>

### v1.3 (Planning)

- [ ] Phase 18: TBD

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
| 13. DB Foundation + Template Management | v1.2 | 4/4 | Complete | 2026-05-04 |
| 14. Checklist Execution Engine | v1.2 | 5/5 | Complete | 2026-05-06 |
| 15. Photos per Item | v1.2 | 3/3 | Complete | 2026-05-07 |
| 16. Digital Signature | v1.2 | 0/? | Cancelled → v1.3 | 2026-05-09 |
| 17. History + Conformity | v1.2 | 0/? | Cancelled → v1.3 | 2026-05-09 |
| 18. TBD | v1.3 | 0/? | Planning | — |

---

## Backlog

### Phase 999.1: Responsável externo por email nas ações corretivas (BACKLOG)

**Goal:** No campo de responsável das ações corretivas, adicionar opção "Convidar por email" para casos em que o responsável ainda não está cadastrado no sistema.
**Plans:** 0 plans

Plans:
- [ ] TBD (promover com /gsd-review-backlog quando pronto)

### Phase 999.2: Modo offline para auditorias e checklists (BACKLOG)

**Goal:** Auditores conseguem executar auditorias e checklists sem sinal de rede com sync automático ao reconectar.
**Context:** Explorado em v1.2 com SharedPreferences — revertido. Requer sqflite/Hive + refactor de estado (Riverpod).
**Plans:** 0 plans

Plans:
- [ ] TBD (promover com /gsd-review-backlog quando pronto)
