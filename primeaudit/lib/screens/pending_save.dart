// ---------------------------------------------------------------------------
// Dados de save pendente para retry da tela de execução de auditoria.
//
// Extraído de `audit_execution_screen.dart` para permitir teste unitário
// direto (ver test/pending_save_test.dart). Mantém construtor `const` e
// campos `final` — imutável por design.
// ---------------------------------------------------------------------------
class PendingSave {
  final String itemId;
  final String response;
  final String? observation;
  final int attemptCount;

  const PendingSave({
    required this.itemId,
    required this.response,
    this.observation,
    this.attemptCount = 0,
  });

  PendingSave copyWithAttempt() => PendingSave(
        itemId: itemId,
        response: response,
        observation: observation,
        attemptCount: attemptCount + 1,
      );
}
