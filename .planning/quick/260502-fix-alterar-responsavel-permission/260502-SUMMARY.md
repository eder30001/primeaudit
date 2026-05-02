---
status: complete
quick_id: 260502
slug: fix-alterar-responsavel-permission
completed: 2026-05-02
commit: 07aa3ab
---

# Quick Task 260502: Fix Alterar Responsável Permission

## What was done

Added `_isAuditor` getter to `_CorrectiveActionDetailScreenState` and expanded the "Alterar responsável" button condition.

**Before:** `(_isCreator || _isAdmin) && !a.status.isFinal`
**After:** `(_isAdmin || _isAuditor || _isResponsible || _isCreator) && !a.status.isFinal`

Three profiles can now change the responsible:
- ADM (via `_isAdmin`) — unchanged
- Auditor (via `_isAuditor`) — `widget.currentUserRole == AppRole.auditor`
- Current responsible (via `_isResponsible`) — `_action.responsibleUserId == widget.currentUserId`

File: `primeaudit/lib/screens/corrective_action_detail_screen.dart`
